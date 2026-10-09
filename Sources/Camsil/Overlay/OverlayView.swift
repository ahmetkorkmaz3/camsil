import AppKit
import CamsilCore
import MetalKit

/// Metal view that turns mouse and key events into ToolInput (points, top-left origin).
final class OverlayView: MTKView {
    var inputHandler: ((ToolInput) -> Void)?
    var quitHandler: (() -> Void)?
    var debugHandler: (() -> Void)?

    override init(frame: CGRect, device: MTLDevice?) {
        super.init(frame: frame, device: device)
        colorPixelFormat = .bgra8Unorm
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        preferredFramesPerSecond = 120
        colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        layer?.isOpaque = false
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self))
    }

    private func point(_ event: NSEvent) -> SIMD2<Float> {
        let p = convert(event.locationInWindow, from: nil)
        return SIMD2(Float(p.x), Float(bounds.height - p.y))
    }

    override func mouseDown(with event: NSEvent) { inputHandler?(.leftDown(point(event))) }
    override func mouseDragged(with event: NSEvent) { inputHandler?(.leftDragged(point(event))) }
    override func mouseUp(with event: NSEvent) { inputHandler?(.leftUp(point(event))) }
    override func mouseMoved(with event: NSEvent) { inputHandler?(.moved(point(event))) }
    override func rightMouseDown(with event: NSEvent) { inputHandler?(.rightDown) }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {  // Esc
            quitHandler?()
            return
        }
        // A held tool key (Space, 1, 2) must not switch tools again and again.
        guard !event.isARepeat, let key = event.charactersIgnoringModifiers?.lowercased() else { return }
        #if DEBUG
        if key == "d" {
            debugHandler?()
            return
        }
        #endif
        inputHandler?(.key(key))
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "q" {
            quitHandler?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
