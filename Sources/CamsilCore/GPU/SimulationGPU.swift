import Metal
import simd

struct WipeParams {
    var segment: SIMD4<Float>
    var info: SIMD4<Float>
    var rates: SIMD4<Float>
    var extra: SIMD4<Float>
}

public final class SimulationGPU {
    private let context: MetalContext
    private let textures: SimulationTextures
    private let addWetPipeline: MTLComputePipelineState
    private let dryPipeline: MTLComputePipelineState
    private let wipePipeline: MTLComputePipelineState

    public init(context: MetalContext, textures: SimulationTextures) throws {
        self.context = context
        self.textures = textures
        addWetPipeline = try context.computePipeline("addWetness")
        dryPipeline = try context.computePipeline("dryWetness")
        wipePipeline = try context.computePipeline("wipe")
    }

    /// Circles are (x, y, radius, amount) in simulation pixels.
    public func encodeAddWetness(_ circles: [SIMD4<Float>], commandBuffer: MTLCommandBuffer) {
        guard !circles.isEmpty else { return }
        for start in stride(from: 0, to: circles.count, by: 64) {
            let chunk = Array(circles[start..<min(start + 64, circles.count)])
            var count = UInt32(chunk.count)
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
            encoder.setComputePipelineState(addWetPipeline)
            encoder.setTexture(textures.wet, index: 0)
            encoder.setBytes(chunk, length: chunk.count * 16, index: 0)
            encoder.setBytes(&count, length: 4, index: 1)
            context.dispatch2D(encoder, width: textures.size.x, height: textures.size.y)
            encoder.endEncoding()
        }
    }

    public func encodeDry(dt: Float, commandBuffer: MTLCommandBuffer) {
        var amount = dt / Tuning.dryTime
        guard amount > 0, let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        encoder.setComputePipelineState(dryPipeline)
        encoder.setTexture(textures.wet, index: 0)
        encoder.setBytes(&amount, length: 4, index: 0)
        context.dispatch2D(encoder, width: textures.size.x, height: textures.size.y)
        encoder.endEncoding()
    }

    public func encodeWipe(from: SIMD2<Float>, to: SIMD2<Float>, radius: Float, commandBuffer: MTLCommandBuffer) {
        let w = textures.size.x, h = textures.size.y
        func rect(margin: Float) -> (x: Int, y: Int, w: Int, h: Int)? {
            let x0 = max(0, Int((min(from.x, to.x) - margin).rounded(.down)))
            let y0 = max(0, Int((min(from.y, to.y) - margin).rounded(.down)))
            let x1 = min(w, Int((max(from.x, to.x) + margin).rounded(.up)))
            let y1 = min(h, Int((max(from.y, to.y) + margin).rounded(.up)))
            guard x1 > x0, y1 > y0 else { return nil }
            return (x0, y0, x1 - x0, y1 - y0)
        }
        // The copy is larger than the wipe area because the smear reads behind the cloth.
        guard let work = rect(margin: radius),
              let copy = rect(margin: radius * (1 + Tuning.smearDistance) + 2) else { return }

        guard let blit = commandBuffer.makeBlitCommandEncoder() else { return }
        blit.copy(from: textures.dirt, sourceSlice: 0, sourceLevel: 0,
                  sourceOrigin: MTLOrigin(x: copy.x, y: copy.y, z: 0),
                  sourceSize: MTLSize(width: copy.w, height: copy.h, depth: 1),
                  to: textures.dirtScratch, destinationSlice: 0, destinationLevel: 0,
                  destinationOrigin: MTLOrigin(x: copy.x, y: copy.y, z: 0))
        blit.endEncoding()

        let rates = WipeRates.forSegment(length: simd_distance(from, to), radius: radius)
        var params = WipeParams(
            segment: SIMD4(from.x, from.y, to.x, to.y),
            info: SIMD4(radius, Float(work.x), Float(work.y), Tuning.wetThreshold),
            rates: SIMD4(rates.wetDust, rates.wetSpots, rates.wetPrints, rates.dryDust),
            extra: SIMD4(Tuning.smearDistance, rates.smear, rates.pickup, Tuning.stripeFrequency)
        )
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        encoder.setComputePipelineState(wipePipeline)
        encoder.setTexture(textures.dirtScratch, index: 0)
        encoder.setTexture(textures.dirt, index: 1)
        encoder.setTexture(textures.wet, index: 2)
        encoder.setBytes(&params, length: MemoryLayout<WipeParams>.stride, index: 0)
        context.dispatch2D(encoder, width: work.w, height: work.h)
        encoder.endEncoding()
    }
}
