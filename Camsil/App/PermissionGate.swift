import AppKit
import CoreGraphics

enum PermissionGate {
    private static let requestedKey = "didRequestScreenCapture"

    /// Returns true when Screen Recording is allowed. Otherwise returns false after one dialog:
    /// the system prompt on the first launch, our own alert on later launches.
    static func ensureScreenRecording() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: requestedKey) {
            // The system prompt has its own "Open System Settings" button.
            defaults.set(true, forKey: requestedKey)
            CGRequestScreenCaptureAccess()
            return false
        }
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
