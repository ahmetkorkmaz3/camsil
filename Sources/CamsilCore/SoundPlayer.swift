import AVFoundation

/// Plays the spray, squeak and finish sounds. A missing file means no sound, not a crash.
/// Each sound goes player node → varispeed → main mixer, so the rate changes the pitch.
public final class SoundPlayer {
    private struct Voice {
        let node: AVAudioPlayerNode
        let varispeed: AVAudioUnitVarispeed
        let buffer: AVAudioPCMBuffer
    }

    private let engine = AVAudioEngine()
    private var spray: Voice?
    private var squeak: Voice?
    private var done: Voice?
    private var configObserver: NSObjectProtocol?

    /// True when no sound loaded or the audio engine does not run.
    public var isSilent: Bool { !engine.isRunning }

    public init(bundle: Bundle) {
        spray = load("spray", from: bundle)
        squeak = load("squeak", from: bundle)
        done = load("done", from: bundle)
        guard spray != nil || squeak != nil || done != nil else { return }
        startEngine()
        // An output device change stops the engine. Start it again.
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in self?.startEngine() }
    }

    deinit {
        if let configObserver { NotificationCenter.default.removeObserver(configObserver) }
        engine.stop()
    }

    public func playSpray() {
        guard engine.isRunning, let spray else { return }
        spray.node.stop()
        spray.varispeed.rate = Float.random(in: 0.92...1.08)
        spray.node.scheduleBuffer(spray.buffer, at: nil, options: [])
        spray.node.play()
    }

    public func setSqueak(speed: Float) {
        guard engine.isRunning, let squeak else { return }
        let p = SqueakMapping.params(speed: speed)
        squeak.node.volume = p.volume
        squeak.varispeed.rate = p.rate
    }

    public func playDone() {
        guard engine.isRunning, let done else { return }
        done.node.stop()
        done.node.scheduleBuffer(done.buffer, at: nil, options: [])
        done.node.play()
    }

    private func load(_ name: String, from bundle: Bundle) -> Voice? {
        guard let url = bundle.url(forResource: name, withExtension: "wav"),
              let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil else { return nil }
        let node = AVAudioPlayerNode()
        let varispeed = AVAudioUnitVarispeed()
        engine.attach(node)
        engine.attach(varispeed)
        engine.connect(node, to: varispeed, format: buffer.format)
        engine.connect(varispeed, to: engine.mainMixerNode, format: buffer.format)
        return Voice(node: node, varispeed: varispeed, buffer: buffer)
    }

    /// Starts the engine and the silent squeak loop. On failure the player stays silent.
    private func startEngine() {
        guard !engine.isRunning else { return }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            return
        }
        if let squeak {
            squeak.node.stop()
            squeak.node.scheduleBuffer(squeak.buffer, at: nil, options: .loops)
            squeak.node.volume = 0
            squeak.node.play()
        }
    }
}
