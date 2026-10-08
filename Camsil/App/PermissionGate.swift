import AppKit
import CoreGraphics

enum PermissionGate {
    /// Returns true when Screen Recording is allowed. Otherwise explains the permission and returns false.
    static func ensureScreenRecording() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        CGRequestScreenCaptureAccess()
        let alert = NSAlert()
        alert.messageText = "Ekran Kaydı izni gerekli"
        alert.informativeText = "Camsil, kirli camın arkasındaki ekranı göstermek için Ekran Kaydı iznini kullanır. Sistem Ayarları'nda izni ver ve Camsil'i yeniden aç."
        alert.addButton(withTitle: "Sistem Ayarları'nı aç")
        alert.addButton(withTitle: "Kapat")
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
        return false
    }
}
