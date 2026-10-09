import Foundation

/// Every tunable number in one place. Values come from the design spec.
public enum Tuning {
    // Wipe rules, rates for one full pass of the cloth.
    public static let wetThreshold: Float = 0.3
    public static let wetDustRate: Float = 0.70
    public static let wetSpotsRate: Float = 0.50
    public static let wetPrintsRate: Float = 0.30
    public static let dryDustRate: Float = 0.10
    public static let wetPickupRate: Float = 0.40
    public static let smearRate: Float = 0.50
    /// Distance of the smear source behind the cloth, as a fraction of the cloth radius.
    public static let smearDistance: Float = 0.15
    public static let stripeFrequency: Float = 0.9

    // Tools, in points.
    public static let sprayRadiusPoints: Float = 180
    public static let clothRadiusPoints: Float = 70
    public static let sprayRate: Double = 4
    public static let sprayWetAmount: Float = 0.9
    public static let bottleHeightPoints: Float = 520
    /// Nozzle tip relative to the cursor. The spray flies from here to the cursor.
    public static let nozzleOffsetPoints = SIMD2<Float>(80, 30)
    /// Bottle tilt at rest, in radians. The nozzle points up and to the left.
    public static let bottleTilt: Float = 0.36
    public static let clothSizePoints: Float = 170

    // Spray mist, in view points and seconds.
    public static let mistFlightTime: ClosedRange<Float> = 0.07...0.2
    public static let mistHazeTime: ClosedRange<Float> = 0.35...0.8
    public static let mistHazeCount = 70
    public static let mistOpacity: Float = 0.13
    public static let mistHazeOpacity: Float = 0.07

    // Droplets, in simulation pixels.
    public static let smallDropCount = 250
    public static let bigDropCount = 6
    public static let smallDropRadius: ClosedRange<Float> = 0.8...2.5
    public static let bigDropRadius: ClosedRange<Float> = 3.5...6
    public static let dropSlideRadius: Float = 4.5
    public static let dropGravity: Float = 120
    public static let dropMaxSpeed: Float = 90
    public static let dropEvaporation: Float = 0.3
    public static let dropTrailLoss: Float = 0.25
    public static let maxDroplets = 4000
    public static let trailWetAmount: Float = 0.6

    // Time, in seconds.
    public static let dryTime: Float = 8
    public static let introDuration: Double = 1.5
    public static let finishFadeDuration: Double = 0.5
    public static let windowFadeDuration: Double = 1.0
    public static let idleTimeout: Double = 120
    public static let hintDuration: Double = 3
    public static let progressInterval: Double = 0.5

    public static let cleanThreshold: Float = 0.95
    public static let simScale: Float = 0.5
    public static let refraction: Float = 0.015
    public static let maxSpots = 600
}
