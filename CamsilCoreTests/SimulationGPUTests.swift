import XCTest
@testable import CamsilCore

final class SimulationGPUTests: XCTestCase {
    private let size = SIMD2(64, 64)
    private var textures: SimulationTextures!
    private var sim: SimulationGPU!

    override func setUpWithError() throws {
        textures = try SimulationTextures(device: TestGPU.context.device, size: size)
        sim = try SimulationGPU(context: TestGPU.context, textures: textures)
    }

    private func at(_ x: Int, _ y: Int) -> Int { y * size.x + x }

    func testAddWetnessIsStrongestAtCenter() {
        TestGPU.run { sim.encodeAddWetness([SIMD4(32, 32, 10, 0.9)], commandBuffer: $0) }
        let wet = TestGPU.readR16(textures.wet)
        XCTAssertEqual(wet[at(32, 32)], 0.9, accuracy: 0.01)
        XCTAssertEqual(wet[at(5, 5)], 0)
    }

    func testAddWetnessClampsAtOne() {
        TestGPU.run { sim.encodeAddWetness([SIMD4(32, 32, 10, 0.9), SIMD4(32, 32, 10, 0.9)], commandBuffer: $0) }
        XCTAssertEqual(TestGPU.readR16(textures.wet)[at(32, 32)], 1, accuracy: 0.001)
    }

    func testDryReducesAndClamps() {
        TestGPU.fillR16(textures.wet, 0.5)
        TestGPU.run { sim.encodeDry(dt: 2, commandBuffer: $0) }
        XCTAssertEqual(TestGPU.readR16(textures.wet)[0], 0.25, accuracy: 0.002)
        TestGPU.run { sim.encodeDry(dt: 10, commandBuffer: $0) }
        XCTAssertEqual(TestGPU.readR16(textures.wet)[0], 0)
    }

    func testWetWipeMatchesCPURules() {
        TestGPU.fillRGBA16(textures.dirt, SIMD4(0.8, 0.6, 0.5, 1))
        TestGPU.fillR16(textures.wet, 1)
        TestGPU.run { sim.encodeWipe(from: SIMD2(22, 32), to: SIMD2(42, 32), radius: 10, commandBuffer: $0) }
        let dirt = TestGPU.readRGBA16(textures.dirt)
        let expected = WipeRules.wipe(DirtSample(dust: 0.8, spots: 0.6, prints: 0.5),
                                      wetness: 1, strength: 1, stripe: 0, rates: .fullPass)
        XCTAssertEqual(dirt[at(32, 32)].x, expected.dust, accuracy: 0.004)
        XCTAssertEqual(dirt[at(32, 32)].y, expected.spots, accuracy: 0.004)
        XCTAssertEqual(dirt[at(32, 32)].z, expected.prints, accuracy: 0.004)
        XCTAssertEqual(dirt[at(32, 5)].x, 0.8, accuracy: 0.002)
        XCTAssertEqual(TestGPU.readR16(textures.wet)[at(32, 32)], 0.6, accuracy: 0.004)
    }

    func testDryWipeMatchesCPURules() {
        TestGPU.fillRGBA16(textures.dirt, SIMD4(0.8, 0.6, 0.5, 1))
        TestGPU.fillR16(textures.wet, 0)
        TestGPU.run { sim.encodeWipe(from: SIMD2(22, 32), to: SIMD2(42, 32), radius: 10, commandBuffer: $0) }
        let dirt = TestGPU.readRGBA16(textures.dirt)
        let stripe = WipeRules.stripe(position: SIMD2(32.5, 32.5), direction: SIMD2(1, 0))
        let expected = WipeRules.wipe(DirtSample(dust: 0.8, spots: 0.6, prints: 0.5),
                                      wetness: 0, strength: 1, stripe: stripe, rates: .fullPass)
        XCTAssertEqual(dirt[at(32, 32)].x, expected.dust, accuracy: 0.004)
        XCTAssertEqual(dirt[at(32, 32)].y, 0.6, accuracy: 0.002)
    }

    func testDrySmearPullsDirtForward() {
        // Dirty left half, clean right half. A dry wipe to the right carries dirt into the clean half.
        let raw = (0..<(size.x * size.y)).flatMap { i -> [Float16] in
            i % size.x < 32 ? [0.9, 0, 0, 1] : [0, 0, 0, 1]
        }
        raw.withUnsafeBytes {
            textures.dirt.replace(region: MTLRegionMake2D(0, 0, size.x, size.y), mipmapLevel: 0,
                                  withBytes: $0.baseAddress!, bytesPerRow: size.x * 8)
        }
        TestGPU.fillR16(textures.wet, 0)
        TestGPU.run { sim.encodeWipe(from: SIMD2(20, 32), to: SIMD2(40, 32), radius: 10, commandBuffer: $0) }
        // Pixel 32 is clean. Its smear source is 1.5 px behind it, in the dirty half.
        XCTAssertGreaterThan(TestGPU.readRGBA16(textures.dirt)[at(32, 32)].x, 0.05)
    }

    func testWipeCleansWholeLongSegment() {
        TestGPU.fillRGBA16(textures.dirt, SIMD4(0.8, 0, 0, 1))
        TestGPU.fillR16(textures.wet, 1)
        TestGPU.run { sim.encodeWipe(from: SIMD2(5, 32), to: SIMD2(60, 32), radius: 6, commandBuffer: $0) }
        let dirt = TestGPU.readRGBA16(textures.dirt)
        for x in [8, 32, 57] {
            XCTAssertEqual(dirt[at(x, 32)].x, 0.8 * 0.3, accuracy: 0.004, "x = \(x)")
        }
    }

    func testWipeAtTextureEdge() {
        TestGPU.fillRGBA16(textures.dirt, SIMD4(0.8, 0, 0, 1))
        TestGPU.fillR16(textures.wet, 1)
        TestGPU.run { sim.encodeWipe(from: SIMD2(-20, 2), to: SIMD2(10, 2), radius: 8, commandBuffer: $0) }
        XCTAssertLessThan(TestGPU.readRGBA16(textures.dirt)[at(0, 2)].x, 0.5)
    }

    func testWipeFullyOutsideTextureDoesNothing() {
        TestGPU.fillRGBA16(textures.dirt, SIMD4(0.8, 0, 0, 1))
        TestGPU.run { sim.encodeWipe(from: SIMD2(-100, -100), to: SIMD2(-80, -100), radius: 8, commandBuffer: $0) }
        XCTAssertTrue(TestGPU.readRGBA16(textures.dirt).allSatisfy { abs($0.x - 0.8) < 0.002 })
    }
}
