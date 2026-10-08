import Metal

/// The state of the glass, at simulation resolution.
public final class SimulationTextures {
    public let size: SIMD2<Int>
    /// R dust, G water spots, B fingerprints. 0 clean, 1 fully dirty.
    public let dirt: MTLTexture
    /// Copy of `dirt` that the wipe kernel reads from.
    public let dirtScratch: MTLTexture
    /// 0 dry, 1 fully wet.
    public let wet: MTLTexture
    /// RG droplet normal, B droplet thickness. Drawn again every frame.
    public let dropNormals: MTLTexture

    public init(device: MTLDevice, size: SIMD2<Int>) throws {
        self.size = size
        func make(_ format: MTLPixelFormat, _ usage: MTLTextureUsage, _ storage: MTLStorageMode) throws -> MTLTexture {
            let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: size.x, height: size.y, mipmapped: false)
            d.usage = usage
            d.storageMode = storage
            guard let t = device.makeTexture(descriptor: d) else { throw MetalError.textureCreation }
            return t
        }
        dirt = try make(.rgba16Float, [.shaderRead, .shaderWrite], .shared)
        dirtScratch = try make(.rgba16Float, [.shaderRead], .private)
        wet = try make(.r16Float, [.shaderRead, .shaderWrite], .shared)
        dropNormals = try make(.rgba16Float, [.renderTarget, .shaderRead], .shared)
        let zeros = [UInt16](repeating: 0, count: size.x * size.y)
        wet.replace(region: MTLRegionMake2D(0, 0, size.x, size.y), mipmapLevel: 0, withBytes: zeros, bytesPerRow: size.x * 2)
    }
}
