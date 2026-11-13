import AppKit
import ServiceManagement

final class App: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var statusItem: NSStatusItem!
    let panel = LightingPanel(frame: .zero)
    var color: InlineColorPicker { panel.color }
    var brightness: NSSlider { panel.brightness }
    var speed: NSSlider { panel.speed }
    var effect: NSPopUpButton { panel.effect }
    var launchAtLogin: NSButton { panel.launchAtLogin }
    var loginSettings: NSButton { panel.loginSettings }
    var speedLabel: NSTextField { panel.speedLabel }
    var brightnessLabel: NSTextField { panel.brightnessLabel }
    var status: NSTextField { panel.status }
    let modes = ["solid", "pulse", "blink", "cycle"]
    var previewLightsOff = false
    lazy var lighting = LightingController(
        executable: Bundle.main.executableURL!.deletingLastPathComponent().appendingPathComponent("quadcastrgb")
    ) { [weak self] text in self?.status.stringValue = text }
    func applicationDidFinishLaunching(_ notification: Notification) {
        let height = min(CGFloat(800), (NSScreen.main?.visibleFrame.height ?? 900) - 70)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: height), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "HyperX Colors"; window.delegate = self
        window.center(); window.isReleasedWhenClosed = false
        let scroll = NSScrollView(frame: window.contentView!.bounds)
        scroll.autoresizingMask = [.width, .height]; scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        panel.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = panel
        window.contentView!.addSubview(scroll)
        NSLayoutConstraint.activate([panel.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor), panel.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor), panel.topAnchor.constraint(equalTo: scroll.contentView.topAnchor)])
        color.onChange = { [weak self] in self?.previewLightsOff = false; self?.refreshPreview() }
        color.color = NSColor(srgbRed: 0.53, green: 0.27, blue: 1, alpha: 1)
        if let hex = UserDefaults.standard.string(forKey: "color"), let rgb = UInt32(hex, radix: 16) {
            color.color = NSColor(srgbRed: Double((rgb >> 16) & 255)/255, green: Double((rgb >> 8) & 255)/255, blue: Double(rgb & 255)/255, alpha: 1)
        }
        if UserDefaults.standard.object(forKey: "brightness") != nil { brightness.doubleValue = UserDefaults.standard.double(forKey: "brightness") }
        if let saved = UserDefaults.standard.string(forKey: "effect"), let index = modes.firstIndex(of: saved) { effect.selectItem(at: index) }
        if UserDefaults.standard.object(forKey: "speed") != nil { speed.doubleValue = min(100, max(1, UserDefaults.standard.double(forKey: "speed"))) }
        effect.target = self; effect.action = #selector(effectChanged)
        speed.target = self; speed.action = #selector(updateLabels); speed.isContinuous = true
        brightness.target = self; brightness.action = #selector(updateLabels); brightness.isContinuous = true
        for (button, action) in [(panel.applyButton, #selector(applyColor)), (panel.offButton, #selector(turnOff)), (panel.hideButton, #selector(hideWindow)), (panel.restoreButton, #selector(restoreLighting)), (launchAtLogin, #selector(toggleLogin)), (loginSettings, #selector(openLoginSettings))] {
            button.target = self; button.action = action
        }
        updateLoginStatus()
        NotificationCenter.default.addObserver(self, selector: #selector(updateLoginStatus), name: NSApplication.didBecomeActiveNotification, object: nil)
        effectChanged()
        previewLightsOff = UserDefaults.standard.bool(forKey: "lightsOff")
        refreshPreview()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "HyperX Colors")
        let menu = NSMenu()
        menu.addItem(withTitle: "Open HyperX Colors", action: #selector(show), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q").target = self
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
                    status.stringValue = "Allow HyperX Colors in macOS Login Items settings."
                } else {
                    status.stringValue = "The app will launch at login and restore your last lighting settings. You can close this window."
                }
            } else {
                try SMAppService.mainApp.unregister()
                UserDefaults.standard.set(false, forKey: "restoreOnLaunch")
                status.stringValue = "Launch at login is disabled."
            }
        } catch {
            status.stringValue = "Could not change the login setting. Move the app to Applications and try again.\n" + error.localizedDescription
        }
        updateLoginStatus()
    }
    func windowWillClose(_ notification: Notification) { panel.preview.stopAnimation() }
    func windowDidMiniaturize(_ notification: Notification) { panel.preview.stopAnimation() }
    func windowDidDeminiaturize(_ notification: Notification) { panel.preview.resumeAnimation() }
    @objc func hideWindow() { window.close() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { show(); return true }
    @objc func show() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); panel.preview.resumeAnimation() }
    func refreshPreview() {
        panel.preview.color = color.color
        panel.preview.mode = modes[max(0, effect.indexOfSelectedItem)]
        panel.preview.brightness = brightness.doubleValue
        panel.preview.speed = speed.doubleValue
        panel.preview.lightsOff = previewLightsOff
        panel.preview.refresh()
    }
    @objc func updateLabels() {
        previewLightsOff = false
        refreshPreview()
        brightnessLabel.stringValue = "Brightness: \(Int(brightness.doubleValue))%"
        speedLabel.stringValue = speed.isEnabled ? "Speed: \(Int(speed.doubleValue))% · slow → fast" : "Speed · animated effects only"
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
        previewLightsOff = false; refreshPreview()
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
    @objc func turnOff() { previewLightsOff = true; refreshPreview(); UserDefaults.standard.set(true, forKey: "lightsOff"); start(arguments: ["solid", "000000", "-b", "100"]) }
    func start(arguments: [String]) { lighting.apply(arguments) }
    @objc func willSleep(_ notification: Notification) { panel.preview.stopAnimation(); lighting.sleep() }
    @objc func didWake(_ notification: Notification) { panel.preview.resumeAnimation(); lighting.wake() }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        panel.preview.stopAnimation()
        lighting.shutdown()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
