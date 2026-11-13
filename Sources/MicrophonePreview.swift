import AppKit

/// A visual approximation, independent of the hardware animation clock.
enum PreviewAnimation {
    static func sample(mode: String, time: TimeInterval, speed: Double) -> (hue: CGFloat?, level: CGFloat) {
        let tempo = max(1, min(100, speed))
        let slow = (100 - tempo) / 100
        switch mode {
        case "pulse":
            let up = Double(Int(3 + 7 * slow)) * 0.055
            let down = Double(Int(21 + 110 * slow)) * 0.055
            let pause = Double(Int(1 + 8 * slow)) * 0.055
            let phase = max(0, time).truncatingRemainder(dividingBy: up + down + pause)
            let value = phase < up ? phase / up : (phase < up + down ? 1 - (phase - up) / down : 0)
            return (nil, CGFloat(value))
        case "blink":
            let half = (101 - tempo) * 0.055
            return (nil, max(0, time).truncatingRemainder(dividingBy: half * 2) < half ? 1 : 0)
        case "cycle":
            let period = (12 + 116 * slow) * 9 * 0.055
            return (CGFloat(max(0, time).truncatingRemainder(dividingBy: period) / period), 1)
        default: return (nil, 1)
        }
    }
}

final class MicrophonePreview: NSView {
    private var base: NSImage?
    private var emission: NSImage?
    private var timer: Timer?
    private let epoch = ProcessInfo.processInfo.systemUptime
    var color: NSColor = .systemPurple
    var mode = "solid"
    var brightness: Double = 70
    var speed: Double = 70
    var lightsOff = false
    var snapshotTime: TimeInterval?
    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityLabel("Microphone lighting preview")
        if let url = Bundle.main.url(forResource: "Microphone", withExtension: "png"), let image = NSImage(contentsOf: url) { prepare(image) }
    }
    convenience init(image: NSImage) { self.init(frame: .zero); prepare(image) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func prepare(_ image: NSImage) {
        // Work on a small in-memory copy. The source artwork remains unchanged.
        let side = 400
        func bitmap() -> NSBitmapImageRep {
            NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bitmapFormat: [], bytesPerRow: side*4, bitsPerPixel: 32)!
        }
        let neutral = bitmap(), mask = bitmap()
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: neutral)
        image.draw(in: NSRect(x: 0, y: 0, width: side, height: side), from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        let pixels = neutral.bitmapData!, alpha = mask.bitmapData!
        for y in 0..<side { for x in 0..<side {
            let i = y * neutral.bytesPerRow + x * 4
            let r = Double(pixels[i])/255, g = Double(pixels[i+1])/255, b = Double(pixels[i+2])/255
            let high = max(r, max(g, b)), low = min(r, min(g, b))
            let saturation = high > 0 ? (high - low)/high : 0
            let weight = max(0, min(1, (saturation - 0.25)/0.35)) * max(0, min(1, (high - 0.18)/0.25))
            for channel in 0..<3 { pixels[i+channel] = UInt8(Double(pixels[i+channel]) * (1-weight) + 12 * weight) }
            let coverage = UInt8(weight * high * Double(pixels[i+3]))
            alpha[i] = coverage; alpha[i+1] = coverage; alpha[i+2] = coverage
            alpha[i+3] = coverage
        } }
        let size = NSSize(width: side, height: side)
        base = NSImage(size: size); base!.addRepresentation(neutral)
        emission = NSImage(size: size); emission!.addRepresentation(mask)
        needsDisplay = true
    }
    func refresh() { needsDisplay = true; resumeAnimation() }
    func stopAnimation() { timer?.invalidate(); timer = nil }
    func resumeAnimation() {
        stopAnimation()
        guard window?.isVisible == true, window?.isMiniaturized == false, mode != "solid", !lightsOff else { return }
        let next = Timer(timeInterval: 1/24, repeats: true) { [weak self] _ in self?.needsDisplay = true }
        timer = next; RunLoop.main.add(next, forMode: .common)
    }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); resumeAnimation() }
    override func draw(_ dirtyRect: NSRect) {
        let side = min(bounds.width, bounds.height - 22)
        let rect = NSRect(x: (bounds.width-side)/2, y: 22, width: side, height: side)
        base?.draw(in: rect)
        let sample = PreviewAnimation.sample(mode: mode, time: snapshotTime ?? (ProcessInfo.processInfo.systemUptime - epoch), speed: speed)
        let tint = sample.hue.map { NSColor(hue: $0, saturation: 1, brightness: 1, alpha: 1) } ?? color
        let level = lightsOff ? 0 : sample.level * CGFloat(max(0, min(100, brightness))/100)
        if let emission = emission, level > 0 {
            let tinted = NSImage(size: emission.size, flipped: false) { region in
                emission.draw(in: region)
                tint.setFill(); region.fill(using: .sourceIn)
                return true
            }
            tinted.draw(in: rect, from: .zero, operation: .plusLighter, fraction: level)
        }
        let label = "Live preview · " + (lightsOff ? "Lights off" : ["solid":"Solid color", "pulse":"Pulse", "blink":"Blink", "cycle":"Rainbow"][mode, default:"Solid color"])
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
        let text = NSAttributedString(string: label, attributes: attributes)
        text.draw(at: NSPoint(x: (bounds.width-text.size().width)/2, y: 2))
    }
    deinit { timer?.invalidate() }
}
