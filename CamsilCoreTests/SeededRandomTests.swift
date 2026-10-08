import XCTest
@testable import CamsilCore

final class SeededRandomTests: XCTestCase {
    func testSameSeedGivesSameSequence() {
        var a = SeededRandom(seed: 42)
        var b = SeededRandom(seed: 42)
        for _ in 0..<100 { XCTAssertEqual(a.next(), b.next()) }
    }

    func testDifferentSeedsGiveDifferentSequences() {
        var a = SeededRandom(seed: 1)
        var b = SeededRandom(seed: 2)
        XCTAssertNotEqual(a.next(), b.next())
    }

    func testWorksWithFloatRandom() {
        var rng = SeededRandom(seed: 7)
        for _ in 0..<1000 {
            let v = Float.random(in: 0..<1, using: &rng)
            XCTAssertTrue(v >= 0 && v < 1)
        }
    }
}
