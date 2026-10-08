import XCTest
@testable import CamsilCore

final class CleanProgressTests: XCTestCase {
    func testFraction() {
        let p = CleanProgress(initialDirt: 0.8)
        XCTAssertEqual(p.fraction(currentDirt: 0.8), 0)
        XCTAssertEqual(p.fraction(currentDirt: 0.4), 0.5, accuracy: 1e-6)
        XCTAssertEqual(p.fraction(currentDirt: 0), 1)
    }

    func testClamps() {
        let p = CleanProgress(initialDirt: 0.5)
        XCTAssertEqual(p.fraction(currentDirt: 0.9), 0)
        XCTAssertEqual(p.fraction(currentDirt: -1), 1)
    }

    func testZeroInitialDirtIsClean() {
        XCTAssertEqual(CleanProgress(initialDirt: 0).fraction(currentDirt: 0), 1)
    }
}
