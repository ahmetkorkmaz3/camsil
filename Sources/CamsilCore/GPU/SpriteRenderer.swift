import Metal

public enum SpriteKind {
    case texture
    case cloth
    /// The soft shadow under the cloth. Draw it before the cloth.
    case clothShadow
}

public struct Sprite {
    public var center: SIMD2<Float>
    public var size: SIMD2<Float>
    public var rotation: Float
    public var alpha: Float
    public var kind: SpriteKind
    /// Velocity x, velocity y (points per second), time (seconds), lift (0 on the glass, 1 in the air).
    /// Only the cloth uses it.
    public var motion: SIMD4<Float>

    public init(center: SIMD2<Float>, size: SIMD2<Float>, rotation: Float, alpha: Float, kind: SpriteKind,
                motion: SIMD4<Float> = .zero) {
        self.center = center
        self.size = size
        self.rotation = rotation
        self.alpha = alpha
        self.kind = kind
        self.motion = motion
    }
}

struct SpriteData {
    var frame: SIMD4<Float>
    var extra: SIMD4<Float>
    var motion: SIMD4<Float>
}

/// Vertices in the cloth mesh: a 24 × 24 grid of two triangles each. Matches kClothGrid.
private let clothVertexCount = 24 * 24 * 6

public final class SpriteRenderer {
    private let texturePipeline: MTLRenderPipelineState
    private let clothPipeline: MTLRenderPipelineState
    private let clothShadowPipeline: MTLRenderPipelineState
    private let mistPipeline: MTLRenderPipelineState
    private let device: MTLDevice

    public init(context: MetalContext, pixelFormat: MTLPixelFormat) throws {
        func make(_ fragment: String, vertex: String = "spriteVertex") throws -> MTLRenderPipelineState {
            let d = MTLRenderPipelineDescriptor()
            d.vertexFunction = try context.function(vertex)
            d.fragmentFunction = try context.function(fragment)
            let c = d.colorAttachments[0]!
            c.pixelFormat = pixelFormat
            c.isBlendingEnabled = true
            c.sourceRGBBlendFactor = .sourceAlpha
            c.destinationRGBBlendFactor = .oneMinusSourceAlpha
            c.sourceAlphaBlendFactor = .one
            c.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            return try context.device.makeRenderPipelineState(descriptor: d)
        }
        texturePipeline = try make("spriteTextureFragment")
        clothPipeline = try make("clothFragment", vertex: "clothVertex")
        clothShadowPipeline = try make("clothShadowFragment", vertex: "clothVertex")
        mistPipeline = try make("mistFragment", vertex: "mistVertex")
        device = context.device
    }

    public func draw(_ sprite: Sprite, texture: MTLTexture?, viewSize: SIMD2<Float>, encoder: MTLRenderCommandEncoder) {
        var data = SpriteData(frame: SIMD4(sprite.center.x, sprite.center.y, sprite.size.x, sprite.size.y),
                              extra: SIMD4(sprite.rotation, sprite.alpha, 0, 0), motion: sprite.motion)
        var size = viewSize
        encoder.setVertexBytes(&data, length: MemoryLayout<SpriteData>.stride, index: 0)
        encoder.setVertexBytes(&size, length: 8, index: 1)
        switch sprite.kind {
        case .texture:
            guard let texture else { return }
            encoder.setRenderPipelineState(texturePipeline)
            encoder.setFragmentTexture(texture, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        case .cloth, .clothShadow:
            encoder.setRenderPipelineState(sprite.kind == .cloth ? clothPipeline : clothShadowPipeline)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: clothVertexCount)
        }
    }

    /// Draws the spray mist. Each item is (x, y, size, alpha) in view points.
    public func drawMist(_ mist: [SIMD4<Float>], viewSize: SIMD2<Float>, encoder: MTLRenderCommandEncoder) {
        guard !mist.isEmpty,
              let buffer = device.makeBuffer(bytes: mist, length: mist.count * MemoryLayout<SIMD4<Float>>.stride)
        else { return }
        var size = viewSize
        encoder.setRenderPipelineState(mistPipeline)
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        encoder.setVertexBytes(&size, length: 8, index: 1)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: mist.count)
    }
}
