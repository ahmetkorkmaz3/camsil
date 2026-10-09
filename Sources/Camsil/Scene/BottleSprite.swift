import Metal
import MetalKit

enum BottleSprite {
    /// Nozzle tip in the bottle image, 0...1 from the top-left. Check it in Step 6.
    static let nozzleAnchor = SIMD2<Float>(0.017, 0.013)

    static func load(device: MTLDevice) throws -> MTLTexture {
        guard let url = Bundle.main.url(forResource: "bottle", withExtension: "png") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try MTKTextureLoader(device: device).newTexture(URL: url, options: [
            .SRGB: false,
            .origin: MTKTextureLoader.Origin.topLeft,
        ])
    }
}
