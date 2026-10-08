import Metal

public struct CompositeUniforms {
    var state: SIMD4<Float>
    var optics: SIMD4<Float>

    public init(dirtOpacity: Float, windowOpacity: Float, sparkle: Float?, debugMode: Int,
                refraction: Float = Tuning.refraction) {
        state = SIMD4(dirtOpacity, windowOpacity, sparkle ?? -1, Float(debugMode))
        optics = SIMD4(refraction, 0, 0, 0)
    }
}

/// Draws the final image: the screen behind dirty, wet glass with droplets.
public final class Compositor {
    private let context: MetalContext
    private let pipeline: MTLRenderPipelineState
    private var blur: MTLTexture?

    public init(context: MetalContext, pixelFormat: MTLPixelFormat) throws {
        self.context = context
        let d = MTLRenderPipelineDescriptor()
        d.vertexFunction = try context.function("fullscreenVertex")
        d.fragmentFunction = try context.function("compositeFragment")
        d.colorAttachments[0].pixelFormat = pixelFormat
        pipeline = try context.device.makeRenderPipelineState(descriptor: d)
    }

    /// Copies the screen into a mipmapped texture. Higher mip levels give the blur.
    public func prepareBlur(screen: MTLTexture, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        if blur?.width != screen.width || blur?.height != screen.height || blur?.pixelFormat != screen.pixelFormat {
            let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: screen.pixelFormat, width: screen.width,
                                                             height: screen.height, mipmapped: true)
            d.usage = [.shaderRead]
            d.storageMode = .private
            blur = context.device.makeTexture(descriptor: d)
        }
        guard let blur, let blit = commandBuffer.makeBlitCommandEncoder() else { return nil }
        blit.copy(from: screen, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(),
                  sourceSize: MTLSize(width: screen.width, height: screen.height, depth: 1),
                  to: blur, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin())
        blit.generateMipmaps(for: blur)
        blit.endEncoding()
        return blur
    }

    public func encode(encoder: MTLRenderCommandEncoder, screen: MTLTexture, blur: MTLTexture,
                       textures: SimulationTextures, uniforms: CompositeUniforms) {
        var u = uniforms
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(screen, index: 0)
        encoder.setFragmentTexture(blur, index: 1)
        encoder.setFragmentTexture(textures.dirt, index: 2)
        encoder.setFragmentTexture(textures.wet, index: 3)
        encoder.setFragmentTexture(textures.dropNormals, index: 4)
        encoder.setFragmentBytes(&u, length: MemoryLayout<CompositeUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }
}
