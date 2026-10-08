import AppKit
import CamsilCore

/// A label that never takes mouse clicks from the overlay view.
final class PassthroughLabel: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

final class HUD {
    private let percentLabel = HUD.makeLabel(size: 15)
    private let hintLabel = HUD.makeLabel(size: 14)
    private let startTime: Double
    private var lastPercent = -1

    init(in view: NSView, startTime: Double) {
        self.startTime = startTime
        hintLabel.stringValue = "  Sağ tık: araç değiştir · Esc: çık  "
        percentLabel.stringValue = "  %0 temiz  "
        for label in [percentLabel, hintLabel] {
            label.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(label)
        }
        NSLayoutConstraint.activate([
            percentLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
            percentLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            hintLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -60),
            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    func update(fraction: Float, time: Double, visible: Bool) {
        let percent = Int(fraction * 100)
        if percent != lastPercent {
            lastPercent = percent
            percentLabel.stringValue = "  %\(percent) temiz  "
        }
        percentLabel.isHidden = !visible
        let age = time - startTime
        hintLabel.alphaValue = CGFloat(max(0, min(1, (Tuning.hintDuration + 0.5 - age) / 0.5)))
        hintLabel.isHidden = !visible
    }

    private static func makeLabel(size: CGFloat) -> PassthroughLabel {
        let label = PassthroughLabel(labelWithString: "")
        label.font = .systemFont(ofSize: size, weight: .semibold)
        label.textColor = .white
        label.alignment = .center
        label.wantsLayer = true
        label.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor
        label.layer?.cornerRadius = 8
        return label
    }
}
