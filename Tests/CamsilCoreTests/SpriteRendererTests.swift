import XCTest
@testable import CamsilCore

final class SpriteRendererTests: GPUTestCase {
    private func draw(_ sprite: Sprite, texture: MTLTexture?) throws -> [SIMD4<UInt8>] {
        let renderer = try SpriteRenderer(context: TestGPU.context, pixelFormat: .bgra8Unorm)
        let target = TestGPU.makeBGRA(width: 100, height: 100, usage: [.renderTarget, .shaderRead])
        TestGPU.run { cb in
            let rpd = MTLRenderPassDescriptor()
            rpd.colorAttachments[0].texture = target
            rpd.colorAttachments[0].loadAction = .clear
            rpd.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            rpd.colorAttachments[0].storeAction = .store
            let enc = cb.makeRenderCommandEncoder(descriptor: rpd)!
            renderer.draw(sprite, texture: texture, viewSize: SIMD2(100, 100), encoder: enc)
            enc.endEncoding()
        }
        return TestGPU.readBGRA(target)
    }

    func testClothIsGreenAtCenterAndEmptyAtCorner() throws {
        let px = try draw(Sprite(center: SIMD2(50, 50), size: SIMD2(60, 60), rotation: 0, alpha: 1, kind: .cloth), texture: nil)
        let center = px[50 * 100 + 50]
        XCTAssertGreaterThan(center.w, 230)
        XCTAssertGreaterThan(center.y, center.x)
        XCTAssertEqual(px[2 * 100 + 2], .zero)
    }

    func testTextureSpriteUsesTopLeftCoordinates() throws {
        let red = TestGPU.makeBGRA(width: 2, height: 2) { _, _ in SIMD4(255, 0, 0, 255) }
        let px = try draw(Sprite(center: SIMD2(20, 20), size: SIMD2(20, 20), rotation: 0, alpha: 1, kind: .texture), texture: red)
        XCTAssertEqual(px[20 * 100 + 20].x, 255)
        XCTAssertEqual(px[80 * 100 + 20], .zero)
    }
}
