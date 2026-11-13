import AppKit

final class LightingPanel: NSView {
    override var isFlipped: Bool { true }
    let color = InlineColorPicker(frame: .zero)
    let preview = MicrophonePreview(frame: .zero)
    let effect = NSPopUpButton(frame: .zero, pullsDown: false)
    let brightness = NSSlider(value: 70, minValue: 0, maxValue: 100, target: nil, action: nil)
    let speed = NSSlider(value: 70, minValue: 1, maxValue: 100, target: nil, action: nil)
    let brightnessLabel = NSTextField(labelWithString: "Brightness: 70%")
    let speedLabel = NSTextField(labelWithString: "Speed: 70%")
    let applyButton = NSButton(title: "Apply", target: nil, action: nil)
    let offButton = NSButton(title: "Lights off", target: nil, action: nil)
    let hideButton = NSButton(title: "Hide", target: nil, action: nil)
    let restoreButton = NSButton(title: "Restore lighting — rainbow", target: nil, action: nil)
    let launchAtLogin = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)
    let loginSettings = NSButton(title: "Login Items Settings…", target: nil, action: nil)
    let status = NSTextField(wrappingLabelWithString: "Preview changes instantly. Click Apply to send your lighting to the microphone.")
    let stack = NSStackView()
    override init(frame: NSRect) {
        super.init(frame: frame)
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false; addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            bottomAnchor.constraint(equalTo: stack.bottomAnchor, constant: 20)
        ])
        let title = NSTextField(labelWithString: "Your microphone. Your color.")
        title.font = .systemFont(ofSize: 25, weight: .bold)
        stack.addArrangedSubview(title)
        let subtitle = NSTextField(labelWithString: "HyperX QuadCast S • Lighting control")
        subtitle.textColor = .secondaryLabelColor
        stack.addArrangedSubview(subtitle)
        stack.addArrangedSubview(preview)
        preview.heightAnchor.constraint(equalToConstant: 178).isActive = true
        preview.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        effect.addItems(withTitles: ["Solid color", "Pulse", "Blink", "Rainbow"])
        let effectRow = NSStackView(views: [NSTextField(labelWithString: "Effect"), effect]); effectRow.spacing = 16
        stack.addArrangedSubview(effectRow)
        let colorTitle = NSTextField(labelWithString: "Light color")
        colorTitle.font = .systemFont(ofSize: 12, weight: .medium)
        stack.addArrangedSubview(colorTitle)
        stack.addArrangedSubview(color)
        color.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        let controls = NSStackView(); controls.orientation = .horizontal; controls.spacing = 24; controls.distribution = .fillEqually
        for (label, slider) in [(brightnessLabel, brightness), (speedLabel, speed)] {
            let group = NSStackView(views: [label, slider]); group.orientation = .vertical; group.alignment = .leading; group.spacing = 4
            label.font = .systemFont(ofSize: 12)
            slider.widthAnchor.constraint(equalTo: group.widthAnchor).isActive = true
            controls.addArrangedSubview(group)
        }
        stack.addArrangedSubview(controls); controls.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        let buttons = NSStackView(views: [applyButton, offButton, hideButton]); buttons.spacing = 12
        [applyButton, offButton, hideButton, restoreButton, loginSettings].forEach { $0.bezelStyle = .rounded }
        applyButton.keyEquivalent = "\r"
        stack.addArrangedSubview(buttons)
        restoreButton.toolTip = "Recreates the rainbow effect. Does not reset firmware or change audio settings."
        stack.addArrangedSubview(restoreButton)
        stack.addArrangedSubview(launchAtLogin)
        stack.addArrangedSubview(loginSettings)
        loginSettings.isHidden = true
        status.font = .systemFont(ofSize: 12); status.textColor = .secondaryLabelColor
        stack.addArrangedSubview(status)
        status.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
