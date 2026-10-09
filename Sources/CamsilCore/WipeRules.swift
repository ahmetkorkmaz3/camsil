import Foundation
import simd

public struct DirtSample: Equatable {
    public var dust: Float
    public var spots: Float
    public var prints: Float

    public init(dust: Float, spots: Float, prints: Float) {
        self.dust = dust
        self.spots = spots
        self.prints = prints
    }
}

/// Reduction rates for one cloth segment. `fullPass` is one full pass over a pixel.
public struct WipeRates: Equatable {
    public var wetDust: Float
    public var wetSpots: Float
    public var wetPrints: Float
    public var dryDust: Float
    public var pickup: Float
    public var smear: Float

    public static let fullPass = WipeRates(
        wetDust: Tuning.wetDustRate,
        wetSpots: Tuning.wetSpotsRate,
        wetPrints: Tuning.wetPrintsRate,
        dryDust: Tuning.dryDustRate,
        pickup: Tuning.wetPickupRate,
        smear: Tuning.smearRate
    )

    /// Scales every rate so that segments that add up to 2 * radius give one full pass.
    public static func forSegment(length: Float, radius: Float) -> WipeRates {
        func scale(_ rate: Float) -> Float {
            WipeRules.effectiveRate(rate, segmentLength: length, radius: radius)
        }
        let full = fullPass
        return WipeRates(
            wetDust: scale(full.wetDust),
            wetSpots: scale(full.wetSpots),
            wetPrints: scale(full.wetPrints),
            dryDust: scale(full.dryDust),
            pickup: scale(full.pickup),
            smear: scale(full.smear)
        )
    }
}

/// CPU reference of the wipe kernel in Simulation.metal. Keep both in sync.
public enum WipeRules {
    public static func isWet(_ wetness: Float) -> Bool {
        wetness > Tuning.wetThreshold
    }

    public static func effectiveRate(_ rate: Float, segmentLength: Float, radius: Float) -> Float {
        guard radius > 0 else { return 0 }
        let pass = min(1, max(0, segmentLength / (2 * radius)))
        return 1 - pow(1 - rate, pass)
    }

    public static func falloff(distance: Float, radius: Float) -> Float {
        1 - smoothstep(radius * 0.6, radius, distance)
    }

    public static func distanceToSegment(_ p: SIMD2<Float>, _ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
        let ab = b - a
        let len2 = max(simd_length_squared(ab), 1e-4)
        let t = min(1, max(0, simd_dot(p - a, ab) / len2))
        return simd_distance(p, a + ab * t)
    }

    public static func stripe(position: SIMD2<Float>, direction: SIMD2<Float>) -> Float {
        let perp = SIMD2<Float>(-direction.y, direction.x)
        return 0.5 + 0.5 * sin(simd_dot(position, perp) * Tuning.stripeFrequency)
    }

    public static func wipe(_ d: DirtSample, wetness: Float, strength s: Float, stripe: Float, rates: WipeRates) -> DirtSample {
        var out = d
        if isWet(wetness) {
            out.dust *= 1 - rates.wetDust * s
            out.spots *= 1 - rates.wetSpots * s
            out.prints *= 1 - rates.wetPrints * s
        } else {
            out.dust *= 1 - rates.dryDust * s * 2 * stripe
        }
        return out
    }

    public static func wetnessAfterWipe(_ wetness: Float, strength s: Float, rates: WipeRates) -> Float {
        wetness * (1 - rates.pickup * s)
    }

    static func smoothstep(_ e0: Float, _ e1: Float, _ x: Float) -> Float {
        let t = min(1, max(0, (x - e0) / (e1 - e0)))
        return t * t * (3 - 2 * t)
    }
}
