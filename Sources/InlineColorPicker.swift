import AppKit

final class ColorWheel: NSControl {
    var color = NSColor.systemPurple { didSet { needsDisplay = true } }
    private var wheelImage: NSImage?
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    private var disc: NSRect { bounds.insetBy(dx: 6, dy: 6) }
    override func draw(_ dirtyRect: NSRect) {
        if wheelImage == nil {
            let size = 256
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: size * 4, bitsPerPixel: 32)!
            let bytes = rep.bitmapData!
            for y in 0..<size { for x in 0..<size {
                let dx = (Double(x) - 127.5) / 127, dy = (Double(y) - 127.5) / 127
                let radius = hypot(dx, dy)
                let c = NSColor(hue: (atan2(dy, dx) / (2 * .pi) + 1).truncatingRemainder(dividingBy: 1), saturation: min(1, radius), brightness: 1, alpha: 1).usingColorSpace(.deviceRGB)!
                let i = (y * size + x) * 4
                let coverage = max(0, min(1, (1 - radius) * 127))
                bytes[i] = UInt8(c.redComponent * 255 * coverage); bytes[i+1] = UInt8(c.greenComponent * 255 * coverage); bytes[i+2] = UInt8(c.blueComponent * 255 * coverage)
                bytes[i+3] = UInt8(coverage * 255)
            } }
            let image = NSImage(size: NSSize(width: size, height: size)); image.addRepresentation(rep); wheelImage = image
        }
        wheelImage?.draw(in: disc, from: .zero, operation: .sourceOver, fraction: isEnabled ? 1 : 0.25, respectFlipped: true, hints: nil)
        guard let rgb = color.usingColorSpace(.sRGB) else { return }
        let angle = rgb.hueComponent * 2 * .pi
        let radius = rgb.saturationComponent * disc.width / 2
        let p = NSPoint(x: disc.midX + cos(angle) * radius, y: disc.midY + sin(angle) * radius)
        let ring = NSBezierPath(ovalIn: NSRect(x: p.x-6, y: p.y-6, width: 12, height: 12))
        NSColor.black.withAlphaComponent(0.55).setStroke(); ring.lineWidth = 4; ring.stroke()
        NSColor.white.setStroke(); ring.lineWidth = 2; ring.stroke()
    }
    private func choose(_ event: NSEvent) {
        guard isEnabled else { return }
        let p = convert(event.locationInWindow, from: nil)
        let dx = p.x - disc.midX, dy = p.y - disc.midY
        let hue = (atan2(dy, dx) / (2 * .pi) + 1).truncatingRemainder(dividingBy: 1)
        color = NSColor(hue: hue, saturation: min(1, hypot(dx, dy) / (disc.width / 2)), brightness: 1, alpha: 1)
        sendAction(action, to: target)
    }
    override func mouseDown(with event: NSEvent) { choose(event) }
    override func mouseDragged(with event: NSEvent) { choose(event) }
}

final class InlineColorPicker: NSView, NSTextFieldDelegate {
    let wheel = ColorWheel()
    let hexField = NSTextField(string: "#8844FF")
    private let chip = NSView()
    private var presets: [NSButton] = []
    var onChange: (() -> Void)?
    var color: NSColor {
        get { wheel.color }
        set { wheel.color = newValue; updateFields() }
    }
    var isEnabled = true {
        didSet {
            wheel.isEnabled = isEnabled; wheel.needsDisplay = true
            hexField.isEnabled = isEnabled
            presets.forEach { $0.isEnabled = isEnabled }
            alphaValue = isEnabled ? 1 : 0.45
        }
    }
    override init(frame: NSRect) {
        super.init(frame: frame)
        wheel.target = self; wheel.action = #selector(wheelChanged)
        wheel.setAccessibilityLabel("Color wheel. Use the hex field or preset buttons for keyboard input.")
        wheel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(wheel)
        hexField.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        hexField.delegate = self; hexField.target = self; hexField.action = #selector(commitHex)
        hexField.setAccessibilityLabel("Hex color")
        hexField.toolTip = "Enter a six-digit hex color, such as #8844FF, then press Return."
        chip.wantsLayer = true; chip.layer?.cornerRadius = 5
        chip.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([chip.widthAnchor.constraint(equalToConstant: 26), chip.heightAnchor.constraint(equalToConstant: 26)])
        let hexRow = NSStackView(views: [chip, hexField]); hexRow.spacing = 10
        hexField.widthAnchor.constraint(equalToConstant: 112).isActive = true
        let palette = NSStackView(); palette.orientation = .vertical; palette.alignment = .leading; palette.spacing = 10
        let swatches = ["FF3355", "FF8A24", "FFD83D", "4DDD88", "36BDF5", "4776FF", "A263FF", "FF59D7", "FFFFFF", "000000"]
        for row in 0..<2 {
            let strip = NSStackView(); strip.spacing = 8
            for col in 0..<5 {
                let hex = swatches[row * 5 + col]
                let button = NSButton(title: "", target: self, action: #selector(presetSelected(_:)))
                button.identifier = NSUserInterfaceItemIdentifier(hex)
                button.toolTip = "#" + hex; button.setAccessibilityLabel("Color #" + hex)
                button.isBordered = false
                let c = Self.parse(hex)!
                button.image = NSImage(size: NSSize(width: 24, height: 24), flipped: false) { rect in
                    let path = NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2)); c.setFill(); path.fill()
                    NSColor.gray.withAlphaComponent(0.6).setStroke(); path.lineWidth = 1; path.stroke(); return true
                }
                button.widthAnchor.constraint(equalToConstant: 26).isActive = true
                button.heightAnchor.constraint(equalToConstant: 26).isActive = true
                presets.append(button); strip.addArrangedSubview(button)
            }
            palette.addArrangedSubview(strip)
        }
        palette.addArrangedSubview(hexRow)
        palette.translatesAutoresizingMaskIntoConstraints = false; addSubview(palette)
        NSLayoutConstraint.activate([
            wheel.leadingAnchor.constraint(equalTo: leadingAnchor), wheel.topAnchor.constraint(equalTo: topAnchor),
            wheel.widthAnchor.constraint(equalToConstant: 140), wheel.heightAnchor.constraint(equalToConstant: 140),
            palette.leadingAnchor.constraint(equalTo: wheel.trailingAnchor, constant: 28),
            palette.centerYAnchor.constraint(equalTo: wheel.centerYAnchor), palette.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            heightAnchor.constraint(equalToConstant: 140)
        ])
        updateFields()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    static func parse(_ text: String) -> NSColor? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard value.count == 6, value.allSatisfy({ $0.isHexDigit }), let rgb = UInt32(value, radix: 16) else { return nil }
        return NSColor(srgbRed: CGFloat((rgb >> 16) & 255)/255, green: CGFloat((rgb >> 8) & 255)/255, blue: CGFloat(rgb & 255)/255, alpha: 1)
    }
    private func updateFields() {
        let rgb = color.usingColorSpace(.sRGB)!
        hexField.stringValue = String(format: "#%02X%02X%02X", Int((rgb.redComponent*255).rounded()), Int((rgb.greenComponent*255).rounded()), Int((rgb.blueComponent*255).rounded()))
        chip.layer?.backgroundColor = rgb.cgColor
    }
    @objc private func wheelChanged() { updateFields(); onChange?() }
    @objc private func presetSelected(_ button: NSButton) {
        if let hex = button.identifier?.rawValue, let c = Self.parse(hex) { color = c; onChange?() }
    }
    @objc private func commitHex() {
        guard let c = Self.parse(hexField.stringValue) else { NSSound.beep(); updateFields(); return }
        color = c; onChange?()
    }
    func controlTextDidEndEditing(_ obj: Notification) { commitHex() }
}
