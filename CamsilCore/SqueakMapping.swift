import Foundation

public enum SqueakMapping {
    /// Cloth speed in points per second to squeak volume and playback rate.
    public static func params(speed: Float) -> (volume: Float, rate: Float) {
        let k = min(1, max(0, speed / 1500))
        return (volume: 0.8 * k, rate: 0.8 + 0.6 * k)
    }
}
