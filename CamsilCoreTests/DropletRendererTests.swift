import XCTest
@testable import CamsilCore

final class DropletRendererTests: XCTestCase {
    func testDropletWritesThicknessAtCenterOnly() throws {
        let textures = try SimulationTextures(device: TestGPU.context.device, size: SIMD2(32, 32))
        let renderer = try DropletRenderer(context: TestGPU.context)
        TestGPU.run {
            renderer.encode([Droplet(position: SIMD2(16, 16), radius: 8, velocity: 0)],
                            into: textures.dropNormals, commandBuffer: $0)
        }
        let px = TestGPU.readRGBA16(textures.dropNormals)
        XCTAssertGreaterThan(px[16 * 32 + 16].z, 0.95)
        XCTAssertEqual(px[2 * 32 + 2].z, 0)
    }

    func testEmptyListClearsTexture() throws {
        let textures = try SimulationTextures(device: TestGPU.context.device, size: SIMD2(32, 32))
        let renderer = try DropletRenderer(context: TestGPU.context)
        TestGPU.run { renderer.encode([Droplet(position: SIMD2(16, 16), radius: 8, velocity: 0)], into: textures.dropNormals, commandBuffer: $0) }
        TestGPU.run { renderer.encode([], into: textures.dropNormals, commandBuffer: $0) }
        XCTAssertTrue(TestGPU.readRGBA16(textures.dropNormals).allSatisfy { $0.z == 0 })
    }

    func testDropletNormalPointsAwayFromCenter() throws {
        let textures = try SimulationTextures(device: TestGPU.context.device, size: SIMD2(32, 32))
        let renderer = try DropletRenderer(context: TestGPU.context)
        TestGPU.run {
            renderer.encode([Droplet(position: SIMD2(16, 16), radius: 8, velocity: 0)],
                            into: textures.dropNormals, commandBuffer: $0)
        }
        let px = TestGPU.readRGBA16(textures.dropNormals)
        let right = px[16 * 32 + 20]
        let below = px[20 * 32 + 16]
        XCTAssertGreaterThan(right.x, 0.3)
        XCTAssertLessThan(abs(right.y), 0.1)
        XCTAssertGreaterThan(below.y, 0.3)
        XCTAssertLessThan(abs(below.x), 0.1)
    }
}
