import XCTest
import simd
@testable import CamsilCore

final class MistSystemTests: XCTestCase {
    private let nozzle = SIMD2<Float>(600, 520)
    private let target = SIMD2<Float>(500, 500)

    func testSprayStartsAtTheNozzle() {
        let mist = MistSystem()
        var rng = SeededRandom(seed: 1)
        mist.spray(from: nozzle, to: target, radius: 100, rng: &rng)
        XCTAssertEqual(mist.particles.count, Tuning.smallDropCount + Tuning.bigDropCount + Tuning.mistHazeCount)
        for p in mist.particles {
            XCTAssertLessThan(simd_distance(p.position, nozzle), 6)
        }
    }

    func testDropsLandInsideTheRadiusOverTime() {
        let mist = MistSystem()
        var rng = SeededRandom(seed: 2)
        mist.spray(from: nozzle, to: target, radius: 100, rng: &rng)
        let first = mist.step(dt: 0.05)
        XCTAssertTrue(first.drops.isEmpty, "the mist needs time to reach the glass")
        var drops: [SIMD3<Float>] = []
        for _ in 0..<10 { drops += mist.step(dt: 0.02).drops }
        XCTAssertEqual(drops.count, Tuning.smallDropCount + Tuning.bigDropCount)
        for d in drops {
            XCTAssertLessThanOrEqual(simd_distance(SIMD2(d.x, d.y), target), 100)
        }
    }

    func testImpactComesOnceWhenTheFirstMistLands() {
        let mist = MistSystem()
        var rng = SeededRandom(seed: 3)
        mist.spray(from: nozzle, to: target, radius: 100, rng: &rng)
        XCTAssertTrue(mist.step(dt: 0.03).impacts.isEmpty)
        XCTAssertEqual(mist.step(dt: 0.05).impacts, [target])
        XCTAssertTrue(mist.step(dt: 0.05).impacts.isEmpty)
    }

    func testHazeFadesAndIsRemoved() {
        let mist = MistSystem()
        var rng = SeededRandom(seed: 4)
        mist.spray(from: nozzle, to: target, radius: 100, rng: &rng)
        _ = mist.step(dt: 0.3)
        XCTAssertFalse(mist.particles.isEmpty)
        XCTAssertTrue(mist.particles.allSatisfy { $0.dropRadius == 0 && MistSystem.opacity($0) > 0 })
        _ = mist.step(dt: 1)
        XCTAssertTrue(mist.particles.isEmpty)
    }
}
