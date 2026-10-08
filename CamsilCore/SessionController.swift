import Foundation

public enum SessionPhase: Equatable {
    case intro
    case cleaning
    case finishing
    case done
}

/// The life of one cleaning session: dirt fades in, user cleans, glass shines, window fades out.
public final class SessionController {
    public private(set) var phase: SessionPhase = .intro
    public private(set) var dirtOpacity: Float = 0
    public private(set) var windowOpacity: Float = 1
    /// 0...1 while the finish sparkle moves over the glass, nil otherwise.
    public private(set) var sparkle: Float?
    public private(set) var shouldQuit = false

    private let startTime: Double
    private var finishStart: Double = 0

    public init(startTime: Double) {
        self.startTime = startTime
    }

    public func update(time: Double, cleanFraction: Float, lastInputTime: Double) {
        if time - lastInputTime >= Tuning.idleTimeout {
            shouldQuit = true
        }
        switch phase {
        case .intro:
            dirtOpacity = Float(min(1, (time - startTime) / Tuning.introDuration))
            if dirtOpacity >= 1 { phase = .cleaning }
        case .cleaning:
            if cleanFraction >= Tuning.cleanThreshold {
                phase = .finishing
                finishStart = time
                sparkle = 0
            }
        case .finishing:
            let t = time - finishStart
            let total = Tuning.finishFadeDuration + Tuning.windowFadeDuration
            dirtOpacity = Float(max(0, 1 - t / Tuning.finishFadeDuration))
            windowOpacity = t <= Tuning.finishFadeDuration
                ? 1
                : Float(max(0, 1 - (t - Tuning.finishFadeDuration) / Tuning.windowFadeDuration))
            sparkle = Float(min(1, t / total))
            if t >= total {
                phase = .done
                sparkle = nil
                shouldQuit = true
            }
        case .done:
            break
        }
    }
}
