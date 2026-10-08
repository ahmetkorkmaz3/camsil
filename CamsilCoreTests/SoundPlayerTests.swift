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
}
