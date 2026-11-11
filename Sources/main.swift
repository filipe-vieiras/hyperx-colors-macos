import AppKit
import ServiceManagement

final class App: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var statusItem: NSStatusItem!
    let color = NSColorWell()
    let brightness = NSSlider(value: 70, minValue: 0, maxValue: 100, target: nil, action: nil)
    let launchAtLogin = NSButton(checkboxWithTitle: "Abrir ao iniciar sessão", target: nil, action: nil)
    let loginSettings = NSButton(title: "Ajustes de início de sessão…", target: nil, action: nil)
    let effect = NSPopUpButton(frame: .zero, pullsDown: false)
    let speed = NSSlider(value: 70, minValue: 1, maxValue: 100, target: nil, action: nil)
    let speedLabel = NSTextField(labelWithString: "Velocidade: 70%")
    let brightnessLabel = NSTextField(labelWithString: "Brilho: 70%")
    let modes = ["solid", "pulse", "blink", "cycle"]
    let status = NSTextField(wrappingLabelWithString: "Escolha uma cor e clique em Aplicar. Depois, pode fechar a janela; o controle continua na barra de menus.")
    lazy var lighting = LightingController(
        executable: Bundle.main.executableURL!.deletingLastPathComponent().appendingPathComponent("quadcastrgb")
    ) { [weak self] text in self?.status.stringValue = text }
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 730), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "HyperX Colors"
        window.center()
        window.isReleasedWhenClosed = false
        let stack = NSStackView()
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 28), stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -28), stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 28)])
        let title = NSTextField(labelWithString: "Seu microfone. Sua cor.")
        title.font = .systemFont(ofSize: 25, weight: .bold)
        stack.addArrangedSubview(title)
        let subtitle = NSTextField(labelWithString: "HyperX QuadCast S • Controle de iluminação")
        subtitle.textColor = .secondaryLabelColor; stack.addArrangedSubview(subtitle)
        color.color = NSColor(srgbRed: 0.53, green: 0.27, blue: 1, alpha: 1)
        if let hex = UserDefaults.standard.string(forKey: "color"), let rgb = UInt32(hex, radix: 16) {
            color.color = NSColor(srgbRed: Double((rgb >> 16) & 255)/255, green: Double((rgb >> 8) & 255)/255, blue: Double(rgb & 255)/255, alpha: 1)
        }
        if UserDefaults.standard.object(forKey: "brightness") != nil { brightness.doubleValue = UserDefaults.standard.double(forKey: "brightness") }
        effect.addItems(withTitles: ["Cor fixa", "Pulsar", "Piscar", "Arco-íris"])
        if let saved = UserDefaults.standard.string(forKey: "effect"), let index = modes.firstIndex(of: saved) { effect.selectItem(at: index) }
        if UserDefaults.standard.object(forKey: "speed") != nil { speed.doubleValue = min(100, max(1, UserDefaults.standard.double(forKey: "speed"))) }
        effect.target = self; effect.action = #selector(effectChanged)
        speed.target = self; speed.action = #selector(updateLabels); speed.isContinuous = true
        brightness.target = self; brightness.action = #selector(updateLabels); brightness.isContinuous = true
        stack.addArrangedSubview(NSTextField(labelWithString: "Efeito"))
        stack.addArrangedSubview(effect)
        let row = NSStackView(views: [NSTextField(labelWithString: "Cor da iluminação"), color]); row.spacing = 20
        stack.addArrangedSubview(row)
        stack.addArrangedSubview(brightnessLabel)
        brightness.widthAnchor.constraint(equalToConstant: 404).isActive = true
        stack.addArrangedSubview(brightness)
        stack.addArrangedSubview(speedLabel)
        speed.widthAnchor.constraint(equalToConstant: 404).isActive = true
        stack.addArrangedSubview(speed)
        effectChanged()
        let buttons = NSStackView(); buttons.spacing = 12
        for (label, action) in [("Aplicar", #selector(applyColor)), ("Apagar luz", #selector(turnOff)), ("Ocultar", #selector(hideWindow))] {
            let button = NSButton(title: label, target: self, action: action)
            button.bezelStyle = .rounded; buttons.addArrangedSubview(button)
        }
        stack.addArrangedSubview(buttons)
        let restore = NSButton(title: "Restaurar iluminação — arco-íris", target: self, action: #selector(restoreLighting))
        restore.bezelStyle = .rounded
        restore.toolTip = "Recria o efeito arco-íris. Não restaura o firmware nem altera o áudio."
        stack.addArrangedSubview(restore)
        launchAtLogin.target = self; launchAtLogin.action = #selector(toggleLogin)
        stack.addArrangedSubview(launchAtLogin)
        loginSettings.target = self; loginSettings.action = #selector(openLoginSettings)
        loginSettings.bezelStyle = .rounded
        stack.addArrangedSubview(loginSettings)
        updateLoginStatus()
        NotificationCenter.default.addObserver(self, selector: #selector(updateLoginStatus), name: NSApplication.didBecomeActiveNotification, object: nil)
        status.font = .systemFont(ofSize: 12); status.textColor = .secondaryLabelColor
        status.widthAnchor.constraint(equalToConstant: 404).isActive = true
        stack.addArrangedSubview(status)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "HyperX Colors")
        let menu = NSMenu()
        menu.addItem(withTitle: "Abrir HyperX Colors", action: #selector(show), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Sair", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        if UserDefaults.standard.bool(forKey: "restoreOnLaunch") {
            if UserDefaults.standard.bool(forKey: "lightsOff") { turnOff() } else { applyColor() }
        }
        show()
    }
    @objc func updateLoginStatus() {
        let serviceStatus = SMAppService.mainApp.status
        launchAtLogin.state = (serviceStatus == .enabled || serviceStatus == .requiresApproval) ? .on : .off
        loginSettings.isHidden = serviceStatus != .requiresApproval
    }
    @objc func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }
    @objc func toggleLogin() {
        do {
            if launchAtLogin.state == .on {
                try SMAppService.mainApp.register()
                UserDefaults.standard.set(true, forKey: "restoreOnLaunch")
                if SMAppService.mainApp.status == .requiresApproval {
                    status.stringValue = "Autorize o HyperX Colors nos Ajustes de início de sessão do macOS."
                } else {
                    status.stringValue = "O app abrirá ao iniciar sessão e reaplicará sua última iluminação. Pode fechar a janela."
                }
            } else {
                try SMAppService.mainApp.unregister()
                UserDefaults.standard.set(false, forKey: "restoreOnLaunch")
                status.stringValue = "Inicialização automática desativada."
            }
        } catch {
            status.stringValue = "Não foi possível alterar o início automático. Mova o app para Aplicativos e tente novamente.\n" + error.localizedDescription
        }
        updateLoginStatus()
    }
    @objc func hideWindow() { window.close(); NSColorPanel.shared.orderOut(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { show(); return true }
    @objc func show() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func updateLabels() {
        brightnessLabel.stringValue = "Brilho: \(Int(brightness.doubleValue))%"
        speedLabel.stringValue = speed.isEnabled ? "Velocidade: \(Int(speed.doubleValue))% · lento → rápido" : "Velocidade: disponível nos efeitos animados"
    }
    @objc func effectChanged() {
        speed.isEnabled = effect.indexOfSelectedItem != 0
        color.isEnabled = effect.indexOfSelectedItem != 3
        updateLabels()
    }
    @objc func restoreLighting() {
        effect.selectItem(at: 3); brightness.doubleValue = 100; speed.doubleValue = 81
        effectChanged(); applyColor()
    }
    @objc func applyColor() {
        guard let rgb = color.color.usingColorSpace(.sRGB) else { return }
        let hex = String(format: "%02x%02x%02x", Int((rgb.redComponent*255).rounded()), Int((rgb.greenComponent*255).rounded()), Int((rgb.blueComponent*255).rounded()))
        UserDefaults.standard.set(hex, forKey: "color")
        UserDefaults.standard.set(brightness.doubleValue, forKey: "brightness")
        UserDefaults.standard.set(false, forKey: "lightsOff")
        let mode = modes[effect.indexOfSelectedItem]
        let tempo = Int(speed.doubleValue)
        UserDefaults.standard.set(mode, forKey: "effect")
        UserDefaults.standard.set(tempo, forKey: "speed")
        var arguments = [mode]
        if mode != "cycle" { arguments.append(hex) }
        arguments += ["-b", String(Int(brightness.doubleValue)), "-s", String(tempo)]
        // Equal on/off durations make blinking readable across the speed range.
        if mode == "blink" { arguments += ["-d", String(101 - tempo)] }
        start(arguments: arguments)
    }
    @objc func turnOff() { UserDefaults.standard.set(true, forKey: "lightsOff"); start(arguments: ["solid", "000000", "-b", "100"]) }
    func start(arguments: [String]) { lighting.apply(arguments) }
    @objc func willSleep(_ notification: Notification) { lighting.sleep() }
    @objc func didWake(_ notification: Notification) { lighting.wake() }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        lighting.shutdown()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
