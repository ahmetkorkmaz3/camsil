import XCTest
@testable import CamsilCore

final class DirtGeneratorTests: GPUTestCase {
    private let size = SIMD2(256, 160)

    func testLayoutIsDeterministic() {
        let a = DirtLayout.make(size: size, seed: 5)
        let b = DirtLayout.make(size: size, seed: 5)
        XCTAssertEqual(a.spots, b.spots)
        XCTAssertEqual(a.prints, b.prints)
        XCTAssertTrue((4...6).contains(a.prints.count))
    }

    func testSpotCountIsCapped() {
        let layout = DirtLayout.make(size: SIMD2(5120, 2880), seed: 1)
        XCTAssertEqual(layout.spots.count, Tuning.maxSpots)
    }

    func testGeneratedDirtIsInRangeAndHasAllKinds() throws {
        let pixels = try generate(seed: 11)
        XCTAssertTrue(pixels.allSatisfy { p in (0...1).contains(p.x) && (0...1).contains(p.y) && (0...1).contains(p.z) })
        let meanDust = pixels.map(\.x).reduce(0, +) / Float(pixels.count)
        XCTAssertTrue((0.5...1).contains(meanDust), "mean dust \(meanDust)")
        XCTAssertTrue(pixels.contains { $0.y > 0.3 }, "no water spots")
        XCTAssertTrue(pixels.contains { $0.z > 0.3 }, "no fingerprints")
    }

    func testSameSeedGivesSameDirt() throws {
        XCTAssertEqual(try generate(seed: 4), try generate(seed: 4))
        XCTAssertNotEqual(try generate(seed: 4), try generate(seed: 5))
    }

    private func generate(seed: UInt64) throws -> [SIMD4<Float>] {
        let textures = try SimulationTextures(device: TestGPU.context.device, size: size)
        let generator = try DirtGenerator(context: TestGPU.context)
        TestGPU.run { generator.encode(into: textures.dirt, seed: seed, commandBuffer: $0) }
        return TestGPU.readRGBA16(textures.dirt)
    }
}
