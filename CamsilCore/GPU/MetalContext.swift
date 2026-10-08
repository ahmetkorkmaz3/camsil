import Metal

public enum MetalError: Error, Equatable {
    case noDevice
    case missingFunction(String)
    case textureCreation
    case bufferCreation
}

public final class MetalContext {
    public let device: MTLDevice
    public let queue: MTLCommandQueue
    public let library: MTLLibrary

    public init() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw MetalError.noDevice
        }
        self.device = device
        self.queue = queue
        library = try device.makeDefaultLibrary(bundle: Bundle(for: MetalContext.self))
    }

    public func function(_ name: String) throws -> MTLFunction {
        guard let f = library.makeFunction(name: name) else { throw MetalError.missingFunction(name) }
        return f
    }

    public func computePipeline(_ name: String) throws -> MTLComputePipelineState {
        try device.makeComputePipelineState(function: function(name))
    }

    public func dispatch2D(_ encoder: MTLComputeCommandEncoder, width: Int, height: Int) {
        encoder.dispatchThreads(MTLSize(width: width, height: height, depth: 1),
                                threadsPerThreadgroup: MTLSize(width: 16, height: 16, depth: 1))
    }
}
