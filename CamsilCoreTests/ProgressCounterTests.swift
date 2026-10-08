import XCTest
@testable import CamsilCore

final class ProgressCounterTests: XCTestCase {
    func testMeanUsesMaxChannel() throws {
        let textures = try SimulationTextures(device: TestGPU.context.device, size: SIMD2(64, 32))
        TestGPU.fillRGBA16(textures.dirt, SIMD4(0.2, 0.6, 0.1, 1))
        let counter = try ProgressCounter(context: TestGPU.context)
        XCTAssertEqual(counter.measureNow(dirt: textures.dirt), 0.6, accuracy: 0.002)
    }

    func testAsyncCompletion() throws {
        let textures = try SimulationTextures(device: TestGPU.context.device, size: SIMD2(64, 32))
        TestGPU.fillRGBA16(textures.dirt, SIMD4(0.25, 0, 0, 1))
        let counter = try ProgressCounter(context: TestGPU.context)
        let done = expectation(description: "measured")
        var result: Float = -1
        TestGPU.run { cb in
            counter.encode(dirt: textures.dirt, commandBuffer: cb) { result = $0; done.fulfill() }
        }
        wait(for: [done], timeout: 2)
        XCTAssertEqual(result, 0.25, accuracy: 0.002)
    }

    func testWetStartsDry() throws {
        let textures = try SimulationTextures(device: TestGPU.context.device, size: SIMD2(16, 16))
        XCTAssertTrue(TestGPU.readR16(textures.wet).allSatisfy { $0 == 0 })
    }
}
