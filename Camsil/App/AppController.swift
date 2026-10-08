import AppKit
import CamsilCore
import MetalKit

final class AppController: NSObject, NSApplicationDelegate {
    private var window: OverlayWindow?
    private var scene: CleaningScene?
    private var capture: ScreenCapture?
    private var screenFrame: NSRect = .zero

    func applicationDidFinishLaunching(_ notification: Notification) {
        let context: MetalContext
        do {
            context = try MetalContext()
        } catch {
            fail("Bu Mac'te Metal kullanılamıyor.")
            return
        }
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
            scene = try CleaningScene(
                context: context, capture: capture,
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
        capture.onStreamStopped = { [weak self] in self?.startCapture(displayID: displayID) }
        self.window = window
        self.scene = scene
        self.capture = capture

        startCapture(displayID: displayID)
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appResignedActive),
                                               name: NSApplication.didResignActiveNotification, object: nil)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        NSCursor.hide()
    }

    private func startCapture(displayID: CGDirectDisplayID) {
        Task { @MainActor in
            do {
                try await self.capture?.start(displayID: displayID)
            } catch {
                self.fail("Ekran görüntüsü alınamadı: \(error.localizedDescription)")
            }
        }
    }

    @objc private func screensChanged() {
        if NSScreen.screens.first?.frame != screenFrame { quit() }
    }

    /// Keeps keyboard focus, so Esc and Cmd+Q always work.
    @objc private func appResignedActive() {
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    func quit() {
        NSCursor.unhide()
        capture?.stop()
        NSApp.terminate(nil)
    }

    private func fail(_ message: String) {
        NotificationCenter.default.removeObserver(self)
        window?.orderOut(nil)
        NSCursor.unhide()
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
