import XCTest
@testable import CamsilCore

final class SessionControllerTests: XCTestCase {
    func testIntroFadesDirtIn() {
        let s = SessionController(startTime: 10)
        s.update(time: 10.75, cleanFraction: 0, lastInputTime: 10)
        XCTAssertEqual(s.phase, .intro)
        XCTAssertEqual(s.dirtOpacity, 0.5, accuracy: 1e-5)
        s.update(time: 11.5, cleanFraction: 0, lastInputTime: 10)
        XCTAssertEqual(s.phase, .cleaning)
        XCTAssertEqual(s.dirtOpacity, 1)
    }

    func testFinishStartsAtThreshold() {
        let s = cleaningSession()
        s.update(time: 20, cleanFraction: 0.94, lastInputTime: 20)
        XCTAssertEqual(s.phase, .cleaning)
        s.update(time: 21, cleanFraction: 0.95, lastInputTime: 21)
        XCTAssertEqual(s.phase, .finishing)
    }

    func testFinishTimeline() {
        let s = cleaningSession()
        s.update(time: 20, cleanFraction: 1, lastInputTime: 20)
        s.update(time: 20.25, cleanFraction: 1, lastInputTime: 20)
        XCTAssertEqual(s.dirtOpacity, 0.5, accuracy: 1e-5)
        XCTAssertEqual(s.windowOpacity, 1)
        XCTAssertNotNil(s.sparkle)
        s.update(time: 21.0, cleanFraction: 1, lastInputTime: 20)
        XCTAssertEqual(s.dirtOpacity, 0)
        XCTAssertEqual(s.windowOpacity, 0.5, accuracy: 1e-5)
        XCTAssertFalse(s.shouldQuit)
        s.update(time: 21.5, cleanFraction: 1, lastInputTime: 20)
        XCTAssertEqual(s.phase, .done)
        XCTAssertTrue(s.shouldQuit)
        XCTAssertNil(s.sparkle)
    }

    func testIdleTimeoutQuits() {
        let s = SessionController(startTime: 0)
        s.update(time: 119, cleanFraction: 0, lastInputTime: 0)
        XCTAssertFalse(s.shouldQuit)
        s.update(time: 120, cleanFraction: 0, lastInputTime: 0)
        XCTAssertTrue(s.shouldQuit)
    }

    func testCleanFractionDuringIntroDoesNotFinish() {
        let s = SessionController(startTime: 0)
        s.update(time: 0.5, cleanFraction: 1, lastInputTime: 0)
        XCTAssertEqual(s.phase, .intro)
    }

    private func cleaningSession() -> SessionController {
        let s = SessionController(startTime: 0)
        s.update(time: 2, cleanFraction: 0, lastInputTime: 2)
        return s
    }
}
