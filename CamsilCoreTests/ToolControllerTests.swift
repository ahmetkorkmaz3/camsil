import XCTest
@testable import CamsilCore

final class ToolControllerTests: XCTestCase {
    private let p = SIMD2<Float>(100, 100)
    private let q = SIMD2<Float>(130, 110)

    func testStartsWithBottle() {
        XCTAssertEqual(ToolController().tool, .bottle)
    }

    func testBottleSpraysOnClick() {
        let c = ToolController()
        XCTAssertEqual(c.handle(.leftDown(p), time: 0), [.spray(p)])
    }

    func testHeldBottleRepeatsFourTimesPerSecond() {
        let c = ToolController()
        _ = c.handle(.leftDown(p), time: 0)
        XCTAssertEqual(c.tick(time: 0.2), [])
        XCTAssertEqual(c.tick(time: 0.25), [.spray(p)])
        XCTAssertEqual(c.tick(time: 0.3), [])
        XCTAssertEqual(c.tick(time: 0.5), [.spray(p)])
    }

    func testHeldBottleSpraysAtNewCursor() {
        let c = ToolController()
        _ = c.handle(.leftDown(p), time: 0)
        _ = c.handle(.leftDragged(q), time: 0.1)
        XCTAssertEqual(c.tick(time: 0.25), [.spray(q)])
    }

    func testReleaseStopsSpray() {
        let c = ToolController()
        _ = c.handle(.leftDown(p), time: 0)
        _ = c.handle(.leftUp(p), time: 0.1)
        XCTAssertEqual(c.tick(time: 1), [])
    }

    func testRightClickToggles() {
        let c = ToolController()
        XCTAssertEqual(c.handle(.rightDown, time: 0), [.toolChanged(.cloth)])
        XCTAssertEqual(c.handle(.rightDown, time: 0), [.toolChanged(.bottle)])
    }

    func testKeys() {
        let c = ToolController()
        XCTAssertEqual(c.handle(.key(" "), time: 0), [.toolChanged(.cloth)])
        XCTAssertEqual(c.handle(.key("1"), time: 0), [.toolChanged(.bottle)])
        XCTAssertEqual(c.handle(.key("1"), time: 0), [])
        XCTAssertEqual(c.handle(.key("2"), time: 0), [.toolChanged(.cloth)])
        XCTAssertEqual(c.handle(.key("x"), time: 0), [])
    }

    func testClothWipesWhileDragging() {
        let c = ToolController()
        _ = c.handle(.key("2"), time: 0)
        XCTAssertEqual(c.handle(.leftDown(p), time: 0), [])
        XCTAssertEqual(c.handle(.leftDragged(q), time: 0.01), [.wipe(from: p, to: q)])
    }

    func testClothDoesNotWipeWithoutMovement() {
        let c = ToolController()
        _ = c.handle(.key("2"), time: 0)
        _ = c.handle(.leftDown(p), time: 0)
        XCTAssertEqual(c.handle(.leftDragged(p), time: 0.01), [])
    }

    func testMoveUpdatesCursorOnly() {
        let c = ToolController()
        XCTAssertEqual(c.handle(.moved(q), time: 0), [])
        XCTAssertEqual(c.cursor, q)
    }

    func testSwitchingToolWhilePressedStopsSpray() {
        let c = ToolController()
        _ = c.handle(.leftDown(p), time: 0)
        _ = c.handle(.rightDown, time: 0.1)
        _ = c.handle(.rightDown, time: 0.2)
        XCTAssertFalse(c.isPressed)
        XCTAssertEqual(c.tick(time: 1), [])
    }
}
