import Foundation
import Darwin

@main
struct ControllerTests {
    static func main() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("hyperx-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let log = folder.appendingPathComponent("calls")
        let available = folder.appendingPathComponent("available")
        let pidFile = folder.appendingPathComponent("pid")
        let helper = folder.appendingPathComponent("helper")
        let fixture = """
        #!/bin/sh
        printf '%s\\n' "$*" >> '\(log.path)'
        test -f '\(available.path)' || exit 2
        echo $$ > '\(pidFile.path)'
        exec /bin/sleep 120
        """
        try fixture.write(to: helper, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helper.path)
        func calls() -> [String] {
            ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
        }
        func spin(_ seconds: TimeInterval) {
            let end = Date().addingTimeInterval(seconds)
            while Date() < end { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
        }
        func waitFor(_ reason: String, _ test: () -> Bool) {
            let end = Date().addingTimeInterval(4)
            while !test() && Date() < end { spin(0.01) }
            precondition(test(), reason)
        }
        func runningPID() -> Int32 { Int32(((try? String(contentsOf: pidFile, encoding: .utf8)) ?? "0").trimmingCharacters(in: .whitespacesAndNewlines))! }
        let controller = LightingController(executable: helper, wakeDelay: 0.1, retryDelay: 0.15, report: { _ in })
        defer { controller.shutdown() }
        let solid = ["solid", "8844ff", "-b", "70"]
        let off = ["solid", "000000", "-b", "100"]
        let pulse = ["pulse", "00ff00", "-b", "50", "-s", "40"]
        FileManager.default.createFile(atPath: available.path, contents: Data())
        controller.apply(solid)
        waitFor("initial command", { calls().count == 1 && runningPID() != 0 })
        controller.sleep()
        spin(0.3)
        precondition(calls().count == 1, "must not retry while asleep")
        controller.wake()
        waitFor("restore exact command after wake", { calls().count == 2 })
        precondition(calls().last == solid.joined(separator: " "))
        controller.sleep()
        controller.apply(off)
        spin(0.25)
        precondition(calls().count == 2, "changing a command during sleep must not launch it")
        controller.wake()
        waitFor("preserve lights off", { calls().count == 3 })
        precondition(calls().last == off.joined(separator: " "))
        spin(0.1)
        try FileManager.default.removeItem(at: available)
        kill(runningPID(), SIGTERM)
        waitFor("retry when USB is unavailable", { calls().count >= 5 })
        let beforeReconnect = calls().count
        FileManager.default.createFile(atPath: available.path, contents: Data())
        waitFor("recover when USB returns", { calls().count > beforeReconnect })
        spin(0.25)
        let recoveredCount = calls().count
        spin(0.3)
        precondition(calls().count == recoveredCount, "a healthy helper must not be restarted")
        controller.wake()
        controller.apply(pulse)
        waitFor("new user selection overrides pending wake retry", { calls().count == recoveredCount + 1 })
        spin(0.3)
        precondition(calls().count == recoveredCount + 1)
        precondition(calls().last == pulse.joined(separator: " "))
        controller.sleep()
        controller.wake()
        controller.wake()
        waitFor("coalesce repeated wake notifications", { calls().count == recoveredCount + 2 })
        spin(0.25)
        precondition(calls().count == recoveredCount + 2)
        let lastPID = runningPID()
        controller.shutdown()
        let finalCount = calls().count
        spin(0.3)
        precondition(calls().count == finalCount, "quit must cancel retries")
        precondition(kill(lastPID, 0) == -1 && errno == ESRCH, "quit must stop the owned helper")
        print("OK: wake, sleep, lights off, delayed USB, retry cancellation, repeated wake, and helper cleanup.")
    }
}
