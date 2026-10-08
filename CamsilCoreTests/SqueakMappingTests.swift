import XCTest
@testable import CamsilCore

final class SqueakMappingTests: XCTestCase {
    func testStillClothIsSilent() {
        XCTAssertEqual(SqueakMapping.params(speed: 0).volume, 0)
    }

    func testFastClothIsLoudAndHigh() {
        let p = SqueakMapping.params(speed: 10_000)
        XCTAssertEqual(p.volume, 0.8, accuracy: 1e-6)
        XCTAssertEqual(p.rate, 1.4, accuracy: 1e-6)
    }

    func testNegativeSpeedIsSilent() {
        XCTAssertEqual(SqueakMapping.params(speed: -5).volume, 0)
    }
}
