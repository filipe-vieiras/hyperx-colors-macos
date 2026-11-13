import AppKit

@main
struct InterfaceTests {
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let output = URL(fileURLWithPath: CommandLine.arguments[2])
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let image = NSImage(contentsOf: root.appendingPathComponent("Assets/AppIcon.png"))!
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 800), styleMask: [.titled], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        let scroll = NSScrollView(frame: window.contentView!.bounds)
        scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        let panel = LightingPanel(frame: .zero)
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.preview.prepare(image)
        panel.color.color = InlineColorPicker.parse("#BA54FF")!
        panel.preview.color = panel.color.color
        panel.preview.snapshotTime = 0.2
        panel.speed.isEnabled = false
        panel.speedLabel.stringValue = "Speed · animated effects only"
        scroll.documentView = panel; window.contentView!.addSubview(scroll)
        NSLayoutConstraint.activate([panel.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor), panel.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor), panel.topAnchor.constraint(equalTo: scroll.contentView.topAnchor)])
        window.contentView!.layoutSubtreeIfNeeded(); panel.layoutSubtreeIfNeeded()
        print("Panel: \(panel.frame), preview: \(panel.preview.frame), picker: \(panel.color.frame), status: \(panel.status.frame)")
        fflush(stdout)
        precondition(panel.frame.width >= 500 && panel.frame.height > 500)
        precondition(panel.convert(panel.color.bounds, from: panel.color).maxY < panel.convert(panel.status.bounds, from: panel.status).minY)
        precondition(panel.convert(panel.status.bounds, from: panel.status).maxY <= panel.bounds.maxY)
        precondition(InlineColorPicker.parse("#aabbcc") != nil)
        precondition(InlineColorPicker.parse("wrong!") == nil)
        precondition(InlineColorPicker.parse("ff00") == nil)
        precondition(InlineColorPicker.parse("000000")!.usingColorSpace(.sRGB)!.redComponent == 0)
        let steady = PreviewAnimation.sample(mode: "solid", time: 0.5, speed: 100)
        precondition(steady.level == 1 && steady.hue == nil)
        precondition(PreviewAnimation.sample(mode: "blink", time: 0.06, speed: 100).level == 0)
        precondition(PreviewAnimation.sample(mode: "blink", time: 0.06, speed: 1).level == 1)
        precondition(PreviewAnimation.sample(mode: "pulse", time: 0, speed: 50).level == 0)
        for mode in ["solid", "pulse", "blink", "cycle"] { for speed in [1.0, 50.0, 100.0] { for t in stride(from: 0.0, through: 20, by: 0.05) {
            let sample = PreviewAnimation.sample(mode: mode, time: t, speed: speed)
            precondition(sample.level.isFinite && sample.level >= 0 && sample.level <= 1)
            if let hue = sample.hue { precondition(hue >= 0 && hue < 1) }
        } } }
        guard let bitmap = panel.bitmapImageRepForCachingDisplay(in: panel.bounds) else { fatalError("Cannot render interface") }
        print("Snapshot format: \(bitmap.bitsPerSample) bits/sample, \(bitmap.samplesPerPixel) channels")
        panel.cacheDisplay(in: panel.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!.write(to: output)
        // Render the actual preview with distinct colors/effect phases; it must change visually.
        func capture(_ color: NSColor, mode: String, time: Double, off: Bool = false) -> Data {
            panel.preview.color = color; panel.preview.mode = mode; panel.preview.snapshotTime = time; panel.preview.lightsOff = off
            let rep = panel.preview.bitmapImageRepForCachingDisplay(in: panel.preview.bounds)!
            panel.preview.cacheDisplay(in: panel.preview.bounds, to: rep)
            return rep.representation(using: .png, properties: [:])!
        }
        let red = capture(.red, mode: "solid", time: 0)
        let blue = capture(.blue, mode: "solid", time: 0)
        precondition(red != blue, "preview must reflect the chosen color")
        precondition(capture(.red, mode: "pulse", time: 0) != capture(.red, mode: "pulse", time: 0.3))
        precondition(capture(.red, mode: "cycle", time: 0) != capture(.red, mode: "cycle", time: 3))
        precondition(capture(.red, mode: "solid", time: 0, off: true) == capture(.blue, mode: "solid", time: 0, off: true))
        print("OK: layout, hex input, animation ranges, recoloring, effect phases, and lights-off preview.")
    }
}
