import AppKit
import CoreGraphics

enum PermissionGate {
    /// Returns true when Screen Recording is allowed. Otherwise asks for it and returns false.
    static func ensureScreenRecording() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        // This call also puts Camsil in the Screen Recording list, for example after
        // `tccutil reset`. macOS shows its own prompt only when no decision exists.
        if !CGRequestScreenCaptureAccess() {
            // A window of an inactive app can open behind other windows. System Settings always shows.
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
        return false
    }
}
