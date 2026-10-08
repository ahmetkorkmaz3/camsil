import XCTest
@testable import CamsilCore

final class CompositorTests: XCTestCase {
    private let n = 64
    private var textures: SimulationTextures!
    private var compositor: Compositor!
    private var screen: MTLTexture!

    override func setUpWithError() throws {
        textures = try SimulationTextures(device: TestGPU.context.device, size: SIMD2(n, n))
        compositor = try Compositor(context: TestGPU.context, pixelFormat: .bgra8Unorm)
        screen = TestGPU.makeBGRA(width: n, height: n) { x, y in
            ((x / 8 + y / 8) % 2 == 0) ? SIMD4(255, 255, 255, 255) : SIMD4(0, 0, 0, 255)
        }
        TestGPU.fillRGBA16(textures.dirt, SIMD4(0, 0, 0, 1))
        TestGPU.fillR16(textures.wet, 0)
    }

    private func render(_ uniforms: CompositeUniforms) -> [SIMD4<UInt8>] {
        let target = TestGPU.makeBGRA(width: n, height: n, usage: [.renderTarget, .shaderRead])
        let dropRenderer = try! DropletRenderer(context: TestGPU.context)
        TestGPU.run { cb in
            dropRenderer.encode([], into: textures.dropNormals, commandBuffer: cb)
            let blur = compositor.prepareBlur(screen: screen, commandBuffer: cb)!
            let rpd = MTLRenderPassDescriptor()
            rpd.colorAttachments[0].texture = target
            rpd.colorAttachments[0].loadAction = .clear
            rpd.colorAttachments[0].storeAction = .store
            let enc = cb.makeRenderCommandEncoder(descriptor: rpd)!
            compositor.encode(encoder: enc, screen: screen, blur: blur, textures: textures, uniforms: uniforms)
            enc.endEncoding()
        }
        return TestGPU.readBGRA(target)
    }

    private func contrast(_ px: [SIMD4<UInt8>]) -> Int {
        let r = px.map { Int($0.x) }
        return r.max()! - r.min()!
    }

    func testCleanGlassShowsScreenUnchanged() {
        let out = render(CompositeUniforms(dirtOpacity: 1, windowOpacity: 1, sparkle: nil, debugMode: 0))
        let src = TestGPU.readBGRA(screen)
        for i in out.indices {
            XCTAssertLessThanOrEqual(abs(Int(out[i].x) - Int(src[i].x)), 1)
        }
        XCTAssertTrue(out.allSatisfy { $0.w == 255 })
    }

    func testDustLowersContrast() {
        TestGPU.fillRGBA16(textures.dirt, SIMD4(1, 0, 0, 1))
        let out = render(CompositeUniforms(dirtOpacity: 1, windowOpacity: 1, sparkle: nil, debugMode: 0))
        XCTAssertLessThan(contrast(out), Int(Double(255) * 0.6))
    }

    func testDirtOpacityZeroHidesDirt() {
        TestGPU.fillRGBA16(textures.dirt, SIMD4(1, 1, 1, 1))
        let out = render(CompositeUniforms(dirtOpacity: 0, windowOpacity: 1, sparkle: nil, debugMode: 0))
        XCTAssertGreaterThanOrEqual(contrast(out), 254)
    }

    func testWindowOpacityZeroIsTransparent() {
        let out = render(CompositeUniforms(dirtOpacity: 1, windowOpacity: 0, sparkle: nil, debugMode: 0))
        XCTAssertTrue(out.allSatisfy { $0 == .zero })
    }

    func testDebugModeShowsDirtMap() {
        TestGPU.fillRGBA16(textures.dirt, SIMD4(1, 0, 0, 1))
        let out = render(CompositeUniforms(dirtOpacity: 1, windowOpacity: 1, sparkle: nil, debugMode: 1))
        XCTAssertTrue(out.allSatisfy { $0.x == 255 && $0.y == 0 })
    }

    func testSparkleBrightensGlass() {
        let plain = render(CompositeUniforms(dirtOpacity: 0, windowOpacity: 1, sparkle: nil, debugMode: 0))
        let shiny = render(CompositeUniforms(dirtOpacity: 0, windowOpacity: 1, sparkle: 0.5, debugMode: 0))
        let sum = { (px: [SIMD4<UInt8>]) in px.reduce(0) { $0 + Int($1.y) } }
        XCTAssertGreaterThan(sum(shiny), sum(plain))
    }
}
