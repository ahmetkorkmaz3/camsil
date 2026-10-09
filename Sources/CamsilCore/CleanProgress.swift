import Foundation

/// Clean fraction relative to the dirt at the start. Dirt per pixel is max(dust, spots, prints).
public struct CleanProgress {
    public let initialDirt: Float

    public init(initialDirt: Float) {
        self.initialDirt = initialDirt
    }

    public func fraction(currentDirt: Float) -> Float {
        guard initialDirt > 0 else { return 1 }
        return min(1, max(0, 1 - currentDirt / initialDirt))
    }
}
