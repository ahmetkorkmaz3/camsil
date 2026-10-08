import Foundation
import simd

public struct Droplet: Equatable {
    public var position: SIMD2<Float>
    public var radius: Float
    public var velocity: Float

    public init(position: SIMD2<Float>, radius: Float, velocity: Float) {
        self.position = position
        self.radius = radius
        self.velocity = velocity
    }
}

/// Water droplets on the glass, in simulation pixels (top-left origin, y down).
public final class DropletSystem {
    public private(set) var droplets: [Droplet] = []
    public let bounds: SIMD2<Float>
    public let maxCount: Int

    public init(bounds: SIMD2<Float>, maxCount: Int = Tuning.maxDroplets) {
        self.bounds = bounds
        self.maxCount = maxCount
    }

    public func spray(center: SIMD2<Float>, radius: Float, rng: inout SeededRandom) {
        let total = Tuning.smallDropCount + Tuning.bigDropCount
        for i in 0..<total {
            let big = i >= Tuning.smallDropCount
            let angle = Float.random(in: 0..<(2 * .pi), using: &rng)
            // Uniform distance (not sqrt) puts more drops near the center.
            let distance = radius * Float.random(in: 0...1, using: &rng)
            let r = Float.random(in: big ? Tuning.bigDropRadius : Tuning.smallDropRadius, using: &rng)
            add(Droplet(position: center + SIMD2(cos(angle), sin(angle)) * distance, radius: r, velocity: 0))
        }
        merge()
        if droplets.count > maxCount {
            droplets.removeFirst(droplets.count - maxCount)
        }
    }

    /// Moves big droplets down, dries small ones. Returns trail points (x, y, radius).
    public func step(dt: Float) -> [SIMD3<Float>] {
        var trail: [SIMD3<Float>] = []
        for i in droplets.indices {
            var d = droplets[i]
            if d.radius >= Tuning.dropSlideRadius {
                d.velocity = min(d.velocity + Tuning.dropGravity * dt, Tuning.dropMaxSpeed)
                d.position.y += d.velocity * dt
                d.radius -= Tuning.dropTrailLoss * dt
                trail.append(SIMD3(d.position.x, d.position.y, d.radius))
            } else {
                d.velocity = 0
                d.radius -= Tuning.dropEvaporation * dt
            }
            droplets[i] = d
        }
        droplets.removeAll { $0.radius < 0.5 || $0.position.y > bounds.y }
        merge()
        return trail
    }

    public func wipe(from a: SIMD2<Float>, to b: SIMD2<Float>, radius: Float) {
        droplets.removeAll { WipeRules.distanceToSegment($0.position, a, b) < radius }
    }

    func add(_ droplet: Droplet) {
        let p = droplet.position
        guard p.x >= 0, p.y >= 0, p.x < bounds.x, p.y < bounds.y else { return }
        droplets.append(droplet)
    }

    /// Joins overlapping droplets. Area is kept: r = sqrt(r1² + r2²).
    func merge() {
        let cell: Float = 16
        var grid: [SIMD2<Int32>: [Int]] = [:]
        var alive = [Bool](repeating: true, count: droplets.count)
        for i in droplets.indices {
            let key = SIMD2<Int32>(Int32((droplets[i].position.x / cell).rounded(.down)),
                                   Int32((droplets[i].position.y / cell).rounded(.down)))
            var merged = false
            search: for dx in Int32(-1)...1 {
                for dy in Int32(-1)...1 {
                    for j in grid[key &+ SIMD2(dx, dy)] ?? [] where alive[j] {
                        let a = droplets[i], b = droplets[j]
                        guard simd_distance(a.position, b.position) < (a.radius + b.radius) * 0.8 else { continue }
                        let area = a.radius * a.radius + b.radius * b.radius
                        let wa = a.radius * a.radius / area
                        droplets[j].position = a.position * wa + b.position * (1 - wa)
                        droplets[j].radius = sqrt(area)
                        droplets[j].velocity = max(a.velocity, b.velocity)
                        alive[i] = false
                        merged = true
                        break search
                    }
                }
            }
            if !merged { grid[key, default: []].append(i) }
        }
        droplets = droplets.indices.filter { alive[$0] }.map { droplets[$0] }
    }
}
