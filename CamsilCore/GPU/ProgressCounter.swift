import Metal

/// Mean of max(dust, spots, prints) over the dirt texture.
public final class ProgressCounter {
    private let context: MetalContext
    private let pipeline: MTLComputePipelineState

    public init(context: MetalContext) throws {
        self.context = context
        pipeline = try context.computePipeline("sumDirtRows")
    }

    /// `completion` runs on a Metal thread after the command buffer completes.
    /// It gets nil when the work cannot be encoded (called at once) or the GPU does not complete it.
    public func encode(dirt: MTLTexture, commandBuffer: MTLCommandBuffer, completion: @escaping (Float?) -> Void) {
        let rows = dirt.height
        let pixels = Double(dirt.width * dirt.height)
        guard let buffer = context.device.makeBuffer(length: rows * 4, options: .storageModeShared),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            completion(nil)
            return
        }
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(dirt, index: 0)
        encoder.setBuffer(buffer, offset: 0, index: 0)
        encoder.dispatchThreads(MTLSize(width: rows, height: 1, depth: 1),
                                threadsPerThreadgroup: MTLSize(width: 64, height: 1, depth: 1))
        encoder.endEncoding()
        commandBuffer.addCompletedHandler { cb in
            // A GPU fault must not read as a clean screen.
            guard cb.status == .completed else {
                completion(nil)
                return
            }
            let sums = buffer.contents().bindMemory(to: Float.self, capacity: rows)
            var total = 0.0
            for i in 0..<rows { total += Double(sums[i]) }
            completion(Float(total / pixels))
        }
    }

    /// Blocks until the GPU is done. Use only at startup and in tests. Nil when the GPU work fails.
    public func measureNow(dirt: MTLTexture) -> Float? {
        guard let cb = context.queue.makeCommandBuffer() else { return nil }
        var result: Float?
        let done = DispatchSemaphore(value: 0)
        encode(dirt: dirt, commandBuffer: cb) { result = $0; done.signal() }
        cb.commit()
        done.wait()
        return result
    }
}
