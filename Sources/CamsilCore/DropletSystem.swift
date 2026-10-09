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

    // Reused across merge() calls: per-cell linked lists (head, tail, next-in-cell).
    private static let cell: Float = 16
    private lazy var gridWidth = Int((bounds.x / Self.cell).rounded(.up)) + 1
    private lazy var gridHeight = Int((bounds.y / Self.cell).rounded(.up)) + 1
    private lazy var cellHead = [Int32](repeating: -1, count: gridWidth * gridHeight)
    private lazy var cellTail = [Int32](repeating: -1, count: gridWidth * gridHeight)
    private var nextInCell: [Int32] = []

    /// Joins overlapping droplets. Area is kept: r = sqrt(r1² + r2²).
    func merge() {
        let count = droplets.count
        if nextInCell.count < count {
            nextInCell = [Int32](repeating: -1, count: count)
        }
        let width = gridWidth, height = gridHeight
        var alive = [Bool](repeating: true, count: count)
        var used: [Int] = []
        used.reserveCapacity(count)
        var anyMerged = false
        // Raw buffers: this runs every frame, and Debug-build array access is slow.
        droplets.withUnsafeMutableBufferPointer { items in
        cellHead.withUnsafeMutableBufferPointer { head in
        cellTail.withUnsafeMutableBufferPointer { tail in
        nextInCell.withUnsafeMutableBufferPointer { next in
        alive.withUnsafeMutableBufferPointer { alive in
            for i in 0..<count {
                let a = items[i]
                let ax = a.position.x, ay = a.position.y
                let cx = min(max(Int((ax / Self.cell).rounded(.down)), 0), width - 1)
                let cy = min(max(Int((ay / Self.cell).rounded(.down)), 0), height - 1)
                var merged = false
                var ny = max(cy - 1, 0)
                let nyEnd = min(cy + 1, height - 1), nxEnd = min(cx + 1, width - 1)
                search: while ny <= nyEnd {
                    var nx = max(cx - 1, 0)
                    while nx <= nxEnd {
                        var j = head[ny * width + nx]
                        while j >= 0 {
                            let ju = Int(j)
                            j = next[ju]
                            guard alive[ju] else { continue }
                            let bx = items[ju].position.x - ax, by = items[ju].position.y - ay
                            let reach = (a.radius + items[ju].radius) * 0.8
                            guard bx * bx + by * by < reach * reach else { continue }
                            let b = items[ju]
                            let area = a.radius * a.radius + b.radius * b.radius
                            let wa = a.radius * a.radius / area
                            items[ju].position = a.position * wa + b.position * (1 - wa)
                            items[ju].radius = sqrt(area)
                            items[ju].velocity = max(a.velocity, b.velocity)
                            alive[i] = false
                            merged = true
                            anyMerged = true
                            break search
                        }
                        nx += 1
                    }
                    ny += 1
                }
                if !merged {
                    let c = cy * width + cx
                    next[i] = -1
                    if tail[c] >= 0 { next[Int(tail[c])] = Int32(i) } else { head[c] = Int32(i) }
                    tail[c] = Int32(i)
                    used.append(c)
                }
            }
            for c in used { head[c] = -1; tail[c] = -1 }
        }}}}}
        if anyMerged {
            var write = 0
            for read in 0..<count where alive[read] {
                droplets[write] = droplets[read]
                write += 1
            }
            droplets.removeLast(count - write)
        }
    }
}
