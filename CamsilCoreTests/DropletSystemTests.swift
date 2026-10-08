import XCTest
import simd
@testable import CamsilCore

final class DropletSystemTests: XCTestCase {
    private let bounds = SIMD2<Float>(1000, 1000)

    func testSprayAddsDropletsInsideRadius() {
        let system = DropletSystem(bounds: bounds)
        var rng = SeededRandom(seed: 3)
        system.spray(center: SIMD2(500, 500), radius: 100, rng: &rng)
        XCTAssertGreaterThan(system.droplets.count, 200)
        for d in system.droplets {
            XCTAssertLessThanOrEqual(simd_distance(d.position, SIMD2(500, 500)), 100 + 7)
        }
    }

    func testSmallDropletsEvaporate() {
        let system = DropletSystem(bounds: bounds)
        system.add(Droplet(position: SIMD2(10, 10), radius: 1, velocity: 0))
        for _ in 0..<40 { _ = system.step(dt: 0.1) }
        XCTAssertTrue(system.droplets.isEmpty)
    }

    func testBigDropletSlidesDownAndLeavesTrail() {
        let system = DropletSystem(bounds: bounds)
        system.add(Droplet(position: SIMD2(100, 100), radius: 5, velocity: 0))
        let trail = system.step(dt: 0.5)
        XCTAssertEqual(system.droplets.count, 1)
        XCTAssertGreaterThan(system.droplets[0].position.y, 100)
        XCTAssertEqual(trail.count, 1)
        XCTAssertEqual(trail[0].x, 100, accuracy: 1e-4)
    }

    func testSmallDropletDoesNotSlide() {
        let system = DropletSystem(bounds: bounds)
        system.add(Droplet(position: SIMD2(100, 100), radius: 3, velocity: 0))
        XCTAssertTrue(system.step(dt: 0.5).isEmpty)
        XCTAssertEqual(system.droplets[0].position.y, 100)
    }

    func testMergeConservesArea() {
        let system = DropletSystem(bounds: bounds)
        system.add(Droplet(position: SIMD2(100, 100), radius: 3, velocity: 0))
        system.add(Droplet(position: SIMD2(102, 100), radius: 4, velocity: 0))
        system.merge()
        XCTAssertEqual(system.droplets.count, 1)
        XCTAssertEqual(system.droplets[0].radius, 5, accuracy: 1e-4)
    }

    func testWipeRemovesOnlyDropletsUnderCloth() {
        let system = DropletSystem(bounds: bounds)
        system.add(Droplet(position: SIMD2(100, 100), radius: 2, velocity: 0))
        system.add(Droplet(position: SIMD2(400, 400), radius: 2, velocity: 0))
        system.wipe(from: SIMD2(80, 100), to: SIMD2(120, 100), radius: 30)
        XCTAssertEqual(system.droplets.map(\.position), [SIMD2(400, 400)])
    }

    func testDropletCountIsCapped() {
        let system = DropletSystem(bounds: bounds, maxCount: 500)
        var rng = SeededRandom(seed: 9)
        for _ in 0..<30 { system.spray(center: SIMD2(500, 500), radius: 200, rng: &rng) }
        XCTAssertLessThanOrEqual(system.droplets.count, 500)
    }

    func testDropletsLeavingScreenAreRemoved() {
        let system = DropletSystem(bounds: bounds)
        system.add(Droplet(position: SIMD2(100, 999), radius: 5, velocity: 80))
        _ = system.step(dt: 1)
        XCTAssertTrue(system.droplets.isEmpty)
    }

    func testDropletsOutsideScreenAreNotAdded() {
        let system = DropletSystem(bounds: bounds)
        system.add(Droplet(position: SIMD2(-5, 10), radius: 2, velocity: 0))
        XCTAssertTrue(system.droplets.isEmpty)
    }
}
