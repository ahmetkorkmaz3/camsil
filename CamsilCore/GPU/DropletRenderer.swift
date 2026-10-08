import Metal

public final class DropletRenderer {
    private let context: MetalContext
    private let pipeline: MTLRenderPipelineState

    public init(context: MetalContext) throws {
        self.context = context
        let d = MTLRenderPipelineDescriptor()
        d.vertexFunction = try context.function("dropVertex")
        d.fragmentFunction = try context.function("dropFragment")
        d.colorAttachments[0].pixelFormat = .rgba16Float
        pipeline = try context.device.makeRenderPipelineState(descriptor: d)
    }

    public func encode(_ droplets: [Droplet], into target: MTLTexture, commandBuffer: MTLCommandBuffer) {
        let rpd = MTLRenderPassDescriptor()
        rpd.colorAttachments[0].texture = target
        rpd.colorAttachments[0].loadAction = .clear
        rpd.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        rpd.colorAttachments[0].storeAction = .store
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: rpd) else { return }
        defer { encoder.endEncoding() }
        guard !droplets.isEmpty else { return }
        let data = droplets.map { SIMD4<Float>($0.position.x, $0.position.y, $0.radius, 0) }
        guard let buffer = context.device.makeBuffer(bytes: data, length: data.count * 16) else { return }
        var size = SIMD2<Float>(Float(target.width), Float(target.height))
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        encoder.setVertexBytes(&size, length: 8, index: 1)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: data.count)
    }
}
