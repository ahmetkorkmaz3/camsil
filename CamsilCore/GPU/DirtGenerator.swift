import Metal

public struct DirtLayout {
    public let spots: [SIMD4<Float>]   // x, y, radius, strength
    public let prints: [SIMD4<Float>]  // x, y, radius, angle

    public static func make(size: SIMD2<Int>, seed: UInt64) -> DirtLayout {
        var rng = SeededRandom(seed: seed)
        let w = Float(size.x), h = Float(size.y)
        let spotCount = min(Tuning.maxSpots, max(1, Int(w * h / 2500)))
        let spots = (0..<spotCount).map { _ in
            SIMD4<Float>(Float.random(in: 0..<w, using: &rng),
                         Float.random(in: 0..<h, using: &rng),
                         Float.random(in: 3...12, using: &rng),
                         Float.random(in: 0.4...0.9, using: &rng))
        }
        let printCount = Int.random(in: 4...6, using: &rng)
        let prints = (0..<printCount).map { _ in
            SIMD4<Float>(Float.random(in: (0.1 * w)...(0.9 * w), using: &rng),
                         Float.random(in: (0.1 * h)...(0.9 * h), using: &rng),
                         Float.random(in: 30...55, using: &rng),
                         Float.random(in: 0..<Float.pi, using: &rng))
        }
        return DirtLayout(spots: spots, prints: prints)
    }
}

struct DirtParams {
    var size: SIMD4<Float>
    var counts: SIMD4<Float>
}

public final class DirtGenerator {
    private let context: MetalContext
    private let pipeline: MTLComputePipelineState

    public init(context: MetalContext) throws {
        self.context = context
        pipeline = try context.computePipeline("generateDirt")
    }

    public func encode(into dirt: MTLTexture, seed: UInt64, commandBuffer: MTLCommandBuffer) {
        let layout = DirtLayout.make(size: SIMD2(dirt.width, dirt.height), seed: seed)
        var params = DirtParams(
            size: SIMD4(Float(dirt.width), Float(dirt.height), Float(seed % 1000) * 0.1, Float(layout.spots.count)),
            counts: SIMD4(Float(layout.prints.count), 0, 0, 0)
        )
        guard let spots = context.device.makeBuffer(bytes: layout.spots, length: layout.spots.count * 16),
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(dirt, index: 0)
        encoder.setBytes(&params, length: MemoryLayout<DirtParams>.stride, index: 0)
        encoder.setBuffer(spots, offset: 0, index: 1)
        encoder.setBytes(layout.prints, length: layout.prints.count * 16, index: 2)
        context.dispatch2D(encoder, width: dirt.width, height: dirt.height)
        encoder.endEncoding()
    }
}
