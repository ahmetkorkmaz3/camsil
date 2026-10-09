import Foundation
import simd

/// One mist particle in flight, in view points (top-left origin, y down).
public struct MistParticle: Equatable {
    public var start: SIMD2<Float>
    public var end: SIMD2<Float>
    public var age: Float
    public var life: Float
    public var size: Float
    /// Droplet radius in simulation pixels when the particle lands. Zero for haze that only floats.
    public var dropRadius: Float

    /// Position on the path from the nozzle to the glass. Fast at the nozzle, slow near the glass.
    public var position: SIMD2<Float> {
        let t = min(age / life, 1)
        let eased = 1 - (1 - t) * (1 - t)
        return start + (end - start) * eased
    }
}

/// What reached the glass during one step.
public struct MistLanding: Equatable {
    /// Droplets as (x, y, radius): position in view points, radius in simulation pixels.
    public var drops: [SIMD3<Float>] = []
    /// Centers of sprays whose main cloud reached the glass, in view points.
    public var impacts: [SIMD2<Float>] = []
}

/// The spray cloud between the nozzle and the glass. Each particle becomes a droplet where it lands.
public final class MistSystem {
    public private(set) var particles: [MistParticle] = []
    private var impacts: [(center: SIMD2<Float>, delay: Float)] = []

    public init() {}

    public func spray(from nozzle: SIMD2<Float>, to target: SIMD2<Float>, radius: Float, rng: inout SeededRandom) {
        let total = Tuning.smallDropCount + Tuning.bigDropCount
        for i in 0..<total {
            let big = i >= Tuning.smallDropCount
            // Big drops come from the dense core of the cone.
            let reach = big ? radius * 0.35 : radius
            let end = target + Self.conePoint(radius: reach, rng: &rng)
            let r = Float.random(in: big ? Tuning.bigDropRadius : Tuning.smallDropRadius, using: &rng)
            particles.append(MistParticle(start: nozzle + Self.jitter(3, rng: &rng), end: end, age: 0,
                                          life: Float.random(in: Tuning.mistFlightTime, using: &rng),
                                          size: Float.random(in: 9...20, using: &rng), dropRadius: r))
        }
        // Fine haze that floats past the glass and fades.
        for _ in 0..<Tuning.mistHazeCount {
            let end = target + Self.conePoint(radius: radius * 1.25, rng: &rng)
            particles.append(MistParticle(start: nozzle + Self.jitter(4, rng: &rng), end: end, age: 0,
                                          life: Float.random(in: Tuning.mistHazeTime, using: &rng),
                                          size: Float.random(in: 24...48, using: &rng), dropRadius: 0))
        }
        impacts.append((target, Tuning.mistFlightTime.lowerBound))
    }

    /// Moves the cloud forward. Returns the droplets and spray centers that reached the glass.
    public func step(dt: Float) -> MistLanding {
        var landing = MistLanding()
        for i in particles.indices {
            particles[i].age += dt
            let p = particles[i]
            if p.age >= p.life && p.dropRadius > 0 {
                landing.drops.append(SIMD3(p.end.x, p.end.y, p.dropRadius))
            }
        }
        particles.removeAll { $0.age >= $0.life }
        for i in impacts.indices { impacts[i].delay -= dt }
        landing.impacts = impacts.filter { $0.delay <= 0 }.map(\.center)
        impacts.removeAll { $0.delay <= 0 }
        return landing
    }

    /// Opacity of a particle for drawing. Haze fades in and out. Spray fades as it spreads.
    public static func opacity(_ p: MistParticle) -> Float {
        let t = min(p.age / p.life, 1)
        if p.dropRadius == 0 {
            return Tuning.mistHazeOpacity * min(t * 6, 1) * (1 - t)
        }
        return Tuning.mistOpacity * (1 - t * 0.7)
    }

    /// Spray pattern of a trigger nozzle: dense in the center, thin at the rim, a little uneven.
    static func conePoint(radius: Float, rng: inout SeededRandom) -> SIMD2<Float> {
        let angle = Float.random(in: 0..<(2 * .pi), using: &rng)
        // Uniform distance (not sqrt) puts more drops near the center.
        let distance = radius * Float.random(in: 0...1, using: &rng)
        let wobble = 1 + 0.12 * sin(angle * 5)
        return SIMD2(cos(angle), sin(angle)) * distance * min(wobble, 1)
    }

    private static func jitter(_ amount: Float, rng: inout SeededRandom) -> SIMD2<Float> {
        SIMD2(Float.random(in: -amount...amount, using: &rng), Float.random(in: -amount...amount, using: &rng))
    }
}
