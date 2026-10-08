import AVFoundation

/// Plays the spray, squeak and finish sounds. A missing file means no sound, not a crash.
public final class SoundPlayer {
    private let spray: AVAudioPlayer?
    private let squeak: AVAudioPlayer?
    private let done: AVAudioPlayer?

    public var isSilent: Bool { spray == nil && squeak == nil && done == nil }

    public init(bundle: Bundle) {
        func load(_ name: String) -> AVAudioPlayer? {
            guard let url = bundle.url(forResource: name, withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
            player.enableRate = true
            player.prepareToPlay()
            return player
        }
        spray = load("spray")
        squeak = load("squeak")
        done = load("done")
        squeak?.numberOfLoops = -1
        squeak?.volume = 0
        squeak?.play()
    }

    public func playSpray() {
        guard let spray else { return }
        spray.currentTime = 0
        spray.rate = Float.random(in: 0.92...1.08)
        spray.play()
    }

    public func setSqueak(speed: Float) {
        let p = SqueakMapping.params(speed: speed)
        squeak?.volume = p.volume
        squeak?.rate = p.rate
    }

    public func playDone() {
        done?.currentTime = 0
        done?.play()
    }
}
