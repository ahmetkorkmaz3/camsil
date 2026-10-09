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

    func testClothIsYellowAtCenterAndEmptyAtCorner() throws {
        let px = try draw(Sprite(center: SIMD2(50, 50), size: SIMD2(60, 60), rotation: 0, alpha: 1, kind: .cloth), texture: nil)
        let center = px[50 * 100 + 50]
        XCTAssertGreaterThan(center.w, 230)
        XCTAssertGreaterThan(center.x, 180)
        XCTAssertGreaterThan(center.y, 140)
        XCTAssertLessThan(center.z, 80)
        XCTAssertEqual(px[2 * 100 + 2], .zero)
    }

    func testFastClothBendsItsEdgesBehindTheHand() throws {
        let still = Sprite(center: SIMD2(50, 50), size: SIMD2(60, 60), rotation: 0, alpha: 1, kind: .cloth)
        var moving = still
        moving.motion = SIMD4(4000, 0, 0, 0)   // fast to the right
        let a = try draw(still, texture: nil), b = try draw(moving, texture: nil)
        func coverage(_ px: [SIMD4<UInt8>], columns: Range<Int>) -> Int {
            (0..<100).reduce(0) { sum, y in sum + columns.filter { px[y * 100 + $0].w > 128 }.count }
        }
        // The trailing (left) edge drags out, the leading (right) edge pulls in.
        XCTAssertGreaterThan(coverage(b, columns: 0..<25), coverage(a, columns: 0..<25))
        XCTAssertLessThan(coverage(b, columns: 75..<100), coverage(a, columns: 75..<100) + 1)
    }

    func testClothShadowIsDarkAndSoft() throws {
        let px = try draw(Sprite(center: SIMD2(50, 50), size: SIMD2(60, 60), rotation: 0, alpha: 1, kind: .clothShadow), texture: nil)
        let center = px[50 * 100 + 50]
        XCTAssertGreaterThan(center.w, 20)
        XCTAssertLessThan(center.w, 120)
    }

    func testMistDrawsSoftDots() throws {
        let renderer = try SpriteRenderer(context: TestGPU.context, pixelFormat: .bgra8Unorm)
        let target = TestGPU.makeBGRA(width: 100, height: 100, usage: [.renderTarget, .shaderRead])
        TestGPU.run { cb in
            let rpd = MTLRenderPassDescriptor()
            rpd.colorAttachments[0].texture = target
            rpd.colorAttachments[0].loadAction = .clear
            rpd.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            rpd.colorAttachments[0].storeAction = .store
            let enc = cb.makeRenderCommandEncoder(descriptor: rpd)!
            renderer.drawMist([SIMD4(30, 30, 20, 1)], viewSize: SIMD2(100, 100), encoder: enc)
            enc.endEncoding()
        }
        let px = TestGPU.readBGRA(target)
        XCTAssertGreaterThan(px[30 * 100 + 30].w, px[30 * 100 + 37].w)
        XCTAssertGreaterThan(px[30 * 100 + 37].w, 0)
        XCTAssertEqual(px[70 * 100 + 70], .zero)
    }

    func testTextureSpriteUsesTopLeftCoordinates() throws {
        let red = TestGPU.makeBGRA(width: 2, height: 2) { _, _ in SIMD4(255, 0, 0, 255) }
        let px = try draw(Sprite(center: SIMD2(20, 20), size: SIMD2(20, 20), rotation: 0, alpha: 1, kind: .texture), texture: red)
        XCTAssertEqual(px[20 * 100 + 20].x, 255)
        XCTAssertEqual(px[80 * 100 + 20], .zero)
    }
}
