import AppKit
import CamsilCore
import MetalKit
import os

private let log = Logger(subsystem: "com.ahmetkorkmaz.Camsil", category: "app")

final class AppController: NSObject, NSApplicationDelegate {
    private var window: OverlayWindow?
    private var view: OverlayView?
    private var scene: CleaningScene?
    private var capture: ScreenCapture?
    private var screenFrame: NSRect = .zero
    private var didGetFirstFrame = false
    private var isClosing = false
    private var cursorHidden = false

    /// Seconds to wait for the first screen frame after the capture starts.
    private let firstFrameTimeout: TimeInterval = 3

    func applicationDidFinishLaunching(_ notification: Notification) {
        let context: MetalContext
        do {
            context = try MetalContext()
        } catch {
            fail("Bu Mac'te Metal kullanılamıyor.")
            return
        }
        log.notice("launch, active: \(NSApp.isActive)")
        guard PermissionGate.ensureScreenRecording() else {
            NSApp.terminate(nil)
            return
        }
        guard let screen = NSScreen.screens.first, let displayID = screen.displayID else {
            fail("Ana ekran bulunamadı.")
            return
        }
        screenFrame = screen.frame

        let window = OverlayWindow(screen: screen)
        let view = OverlayView(frame: NSRect(origin: .zero, size: screen.frame.size), device: context.device)
        window.contentView = view
        let capture = ScreenCapture(device: context.device)
        let scene: CleaningScene
        do {
            let hud = HUD(in: view)
            scene = try CleaningScene(
                context: context, capture: capture, sound: SoundPlayer(bundle: .main), hud: hud,
                bottle: try BottleSprite.load(device: context.device),
                viewSizePoints: SIMD2(Float(screen.frame.width), Float(screen.frame.height)),
                backingScale: Float(screen.backingScaleFactor), pixelFormat: view.colorPixelFormat)
        } catch {
            fail("Grafik sistemi başlatılamadı: \(error)")
            return
        }

        view.delegate = scene
        view.inputHandler = { [weak scene] in scene?.handle($0) }
        view.debugHandler = { [weak scene] in scene?.toggleDebug() }
        view.quitHandler = { [weak self] in self?.quit() }
        scene.onQuit = { [weak self] in self?.quit() }
        scene.onFirstFrame = { [weak self] in self?.firstFrameArrived() }
        capture.onStreamStopped = { [weak self] in self?.startCapture(displayID: displayID) }
        self.window = window
        self.view = view
        self.scene = scene
        self.capture = capture

        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        // Until the first frame: clicks pass through and the cursor stays visible,
        // so a system consent prompt can still be answered.
        NSApp.activate()
        window.ignoresMouseEvents = true
        window.orderFrontRegardless()
        startCapture(displayID: displayID)
    }

    private func startCapture(displayID: CGDirectDisplayID) {
        Task { @MainActor in
            do {
                try await self.capture?.start(displayID: displayID)
            } catch {
                self.fail("Ekran görüntüsü alınamadı: \(error.localizedDescription)")
                return
            }
            guard !self.didGetFirstFrame else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + self.firstFrameTimeout) { [weak self] in
                guard let self, !self.didGetFirstFrame else { return }
                self.fail("Ekran görüntüsü alınamadı.")
            }
        }
    }

    /// The overlay now shows the screen. Take the mouse and the keyboard.
    private func firstFrameArrived() {
        guard !didGetFirstFrame, !isClosing else { return }
        didGetFirstFrame = true
        // From now on the overlay takes all clicks. A click while Camsil is not active
        // makes Camsil active again, so Esc always has a way back.
        window?.ignoresMouseEvents = false
        sendMousePosition()
        NotificationCenter.default.addObserver(self, selector: #selector(appResignedActive),
                                               name: NSApplication.didResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appBecameActive),
                                               name: NSApplication.didBecomeActiveNotification, object: nil)
        log.notice("first frame, active: \(NSApp.isActive)")
        if NSApp.isActive {
            takeInput()
        } else {
            // didBecomeActive calls takeInput.
            NSApp.activate()
        }
    }

    /// Puts the tool under the real mouse, so it does not start at the top-left corner.
    private func sendMousePosition() {
        guard let window, let view else { return }
        let inWindow = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let p = view.convert(inWindow, from: nil)
        scene?.handle(.moved(SIMD2(Float(p.x), Float(view.bounds.height - p.y))))
    }

    private func takeInput() {
        guard didGetFirstFrame, !isClosing, let window, let view else { return }
        window.ignoresMouseEvents = false
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        setCursorHidden(true)
    }

    /// Keeps NSCursor.hide and unhide balanced. They are counted calls.
    private func setCursorHidden(_ hidden: Bool) {
        guard hidden != cursorHidden else { return }
        cursorHidden = hidden
        if hidden { NSCursor.hide() } else { NSCursor.unhide() }
    }

    @objc private func screensChanged() {
        if NSScreen.screens.first?.frame != screenFrame { quit() }
    }

    /// While another app is active, the overlay still shows the dirt and the cursor.
    /// A click on the overlay makes Camsil active again.
    @objc private func appResignedActive() {
        log.notice("resigned active")
        setCursorHidden(false)
    }

    @objc private func appBecameActive() {
        log.notice("became active")
        takeInput()
    }

    func applicationWillTerminate(_ notification: Notification) {
        setCursorHidden(false)
    }

    func quit() {
        guard !isClosing else { return }
        isClosing = true
        NotificationCenter.default.removeObserver(self)
        setCursorHidden(false)
        capture?.stop()
        NSApp.terminate(nil)
    }

    private func fail(_ message: String) {
        guard !isClosing else { return }
        isClosing = true
        NotificationCenter.default.removeObserver(self)
        setCursorHidden(false)
        capture?.stop()
        window?.orderOut(nil)
        let alert = NSAlert()
        alert.messageText = "Camsil açılamadı"
        alert.informativeText = message
        alert.addButton(withTitle: "Kapat")
        NSApp.activate()
        alert.runModal()
        NSApp.terminate(nil)
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
