import Foundation

/// Converts view points (top-left origin) to simulation pixels.
public struct SimSpace {
    public let viewSizePoints: SIMD2<Float>
    public let backingScale: Float

    public init(viewSizePoints: SIMD2<Float>, backingScale: Float) {
        self.viewSizePoints = viewSizePoints
        self.backingScale = backingScale
    }

    private var factor: Float { backingScale * Tuning.simScale }

    public var simSize: SIMD2<Int> {
        let s = (viewSizePoints * factor).rounded(.toNearestOrAwayFromZero)
        return SIMD2(max(1, Int(s.x)), max(1, Int(s.y)))
    }

    public func toSim(_ point: SIMD2<Float>) -> SIMD2<Float> {
        point * factor
    }

    public func lengthToSim(_ length: Float) -> Float {
        length * factor
    }
}
