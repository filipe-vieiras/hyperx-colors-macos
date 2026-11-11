import Foundation
import Darwin

/// Owns a single USB helper. All process state and retries live on one serial queue.
final class LightingController {
    private let queue = DispatchQueue(label: "local.hyperx.colors.lighting")
    private let executable: URL
    private let wakeDelay: TimeInterval
    private let retryDelay: TimeInterval
    private let report: (String) -> Void
    private var desired: [String]?
    private var suspended = false
    private var worker: Process?
    private var pending: DispatchWorkItem?
    private var generation = 0

    init(executable: URL, wakeDelay: TimeInterval = 1.5, retryDelay: TimeInterval = 3,
         report: @escaping (String) -> Void) {
        self.executable = executable
        self.wakeDelay = wakeDelay
        self.retryDelay = retryDelay
        self.report = report
    }

    func apply(_ arguments: [String]) {
        queue.async {
            // Snapshot the applied command: unfinished edits in the window must not affect recovery.
            self.desired = arguments
            self.invalidate()
            self.stopWorker()
            if !self.suspended { self.launch() }
        }
    }

    func sleep() {
        queue.async {
            self.suspended = true
            self.invalidate()
            self.stopWorker()
        }
    }

    func wake() {
        queue.async {
            self.suspended = false
            self.invalidate()
            // Even a helper that survived sleep may hold an obsolete USB handle.
            self.stopWorker()
            guard self.desired != nil else { return }
            self.message("Restaurando a iluminação após o repouso…")
            self.schedule(after: self.wakeDelay)
        }
    }

    func shutdown() {
        // Synchronous only at app termination, so the helper cannot be orphaned.
        queue.sync {
            self.desired = nil
            self.suspended = true
            self.invalidate()
            self.stopWorker()
        }
    }

    private func invalidate() {
        generation += 1
        pending?.cancel()
        pending = nil
    }

    private func stopWorker() {
        guard let old = worker else { return }
        worker = nil // Ignore its intentional termination callback.
        if old.isRunning {
            old.terminate()
            let deadline = Date().addingTimeInterval(1)
            while old.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.02) }
            if old.isRunning { kill(old.processIdentifier, SIGKILL) }
            old.waitUntilExit()
        }
    }

    private func schedule(after delay: TimeInterval) {
        guard desired != nil, !suspended else { return }
        pending?.cancel()
        let ticket = generation
        let item = DispatchWorkItem { [weak self] in
            guard let self = self, self.generation == ticket, !self.suspended else { return }
            self.pending = nil
            self.launch()
        }
        pending = item
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func launch() {
        guard let arguments = desired, !suspended, worker == nil else { return }
        let task = Process()
        task.executableURL = executable
        task.arguments = arguments
        // Controller errors can be repetitive. Do not let a full pipe block USB recovery.
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        task.terminationHandler = { [weak self] ended in
            guard let self = self else { return }
            self.queue.async {
                guard self.worker === ended else { return }
                self.worker = nil
                guard self.desired != nil, !self.suspended else { return }
                self.message("Aguardando o microfone. A iluminação será reaplicada automaticamente (código \(ended.terminationStatus)).")
                self.schedule(after: self.retryDelay)
            }
        }
        worker = task
        do {
            try task.run()
            message("Controle de iluminação ativo. Pode fechar esta janela; a recuperação após repouso é automática.")
        } catch {
            worker = nil
            message("Não foi possível iniciar o controle. Tentando novamente… \(error.localizedDescription)")
            schedule(after: retryDelay)
        }
    }

    private func message(_ text: String) {
        DispatchQueue.main.async { self.report(text) }
    }
}
