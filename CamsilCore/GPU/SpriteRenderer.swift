import Metal

public enum SpriteKind {
    case texture
    case cloth
}

public struct Sprite {
    public var center: SIMD2<Float>
    public var size: SIMD2<Float>
    public var rotation: Float
    public var alpha: Float
    public var kind: SpriteKind

    public init(center: SIMD2<Float>, size: SIMD2<Float>, rotation: Float, alpha: Float, kind: SpriteKind) {
        self.center = center
        self.size = size
        self.rotation = rotation
        self.alpha = alpha
        self.kind = kind
    }
}

struct SpriteData {
    var frame: SIMD4<Float>
    var extra: SIMD4<Float>
}

public final class SpriteRenderer {
    private let texturePipeline: MTLRenderPipelineState
    private let clothPipeline: MTLRenderPipelineState

    public init(context: MetalContext, pixelFormat: MTLPixelFormat) throws {
        func make(_ fragment: String) throws -> MTLRenderPipelineState {
            let d = MTLRenderPipelineDescriptor()
            d.vertexFunction = try context.function("spriteVertex")
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
        clothPipeline = try make("clothFragment")
    }

    public func draw(_ sprite: Sprite, texture: MTLTexture?, viewSize: SIMD2<Float>, encoder: MTLRenderCommandEncoder) {
        var data = SpriteData(frame: SIMD4(sprite.center.x, sprite.center.y, sprite.size.x, sprite.size.y),
                              extra: SIMD4(sprite.rotation, sprite.alpha, 0, 0))
        var size = viewSize
        switch sprite.kind {
        case .texture:
            guard let texture else { return }
            encoder.setRenderPipelineState(texturePipeline)
            encoder.setFragmentTexture(texture, index: 0)
        case .cloth:
            encoder.setRenderPipelineState(clothPipeline)
        }
        encoder.setVertexBytes(&data, length: MemoryLayout<SpriteData>.stride, index: 0)
        encoder.setVertexBytes(&size, length: 8, index: 1)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }
}
