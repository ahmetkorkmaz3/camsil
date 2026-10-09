import XCTest
@testable import CamsilCore

final class SimSpaceTests: XCTestCase {
    func testRetinaHalfResolution() {
        let space = SimSpace(viewSizePoints: SIMD2(1440, 900), backingScale: 2)
        XCTAssertEqual(space.simSize, SIMD2(1440, 900))
        XCTAssertEqual(space.toSim(SIMD2(100, 50)), SIMD2(100, 50))
        XCTAssertEqual(space.lengthToSim(70), 70)
    }

    func testNonRetina() {
        let space = SimSpace(viewSizePoints: SIMD2(1920, 1080), backingScale: 1)
        XCTAssertEqual(space.simSize, SIMD2(960, 540))
        XCTAssertEqual(space.toSim(SIMD2(100, 50)), SIMD2(50, 25))
    }
}
