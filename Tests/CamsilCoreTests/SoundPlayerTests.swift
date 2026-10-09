import XCTest
@testable import CamsilCore

final class SoundPlayerTests: XCTestCase {
    func testMissingSoundFilesAreSilent() {
        let player = SoundPlayer(bundle: Bundle(for: SoundPlayerTests.self))
        XCTAssertTrue(player.isSilent)
        player.playSpray()
        player.setSqueak(speed: 900)
        player.playDone()
    }

    func testSilentPlayerIsSafeToCallManyTimes() {
        let player = SoundPlayer(bundle: Bundle(for: SoundPlayerTests.self))
        XCTAssertTrue(player.isSilent)
        for i in 0..<200 {
            player.setSqueak(speed: Float(i * 10))
            player.playSpray()
        }
        player.setSqueak(speed: 0)
        XCTAssertTrue(player.isSilent)
    }
}
