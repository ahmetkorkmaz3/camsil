import XCTest
@testable import CamsilCore

final class WipeRulesTests: XCTestCase {
    private let sample = DirtSample(dust: 0.8, spots: 0.6, prints: 0.5)

    func testWetFullPassUsesSpecRates() {
        let out = WipeRules.wipe(sample, wetness: 1, strength: 1, stripe: 0.5, rates: .fullPass)
        XCTAssertEqual(out.dust, 0.8 * 0.30, accuracy: 1e-5)
        XCTAssertEqual(out.spots, 0.6 * 0.50, accuracy: 1e-5)
        XCTAssertEqual(out.prints, 0.5 * 0.70, accuracy: 1e-5)
    }

    func testDryPassReducesDustByTenPercentOnAverageStripe() {
        let out = WipeRules.wipe(sample, wetness: 0, strength: 1, stripe: 0.5, rates: .fullPass)
        XCTAssertEqual(out.dust, 0.8 * 0.90, accuracy: 1e-5)
        XCTAssertEqual(out.spots, 0.6, accuracy: 1e-5)
        XCTAssertEqual(out.prints, 0.5, accuracy: 1e-5)
    }

    func testDryStripeMakesStreaks() {
        let low = WipeRules.wipe(sample, wetness: 0, strength: 1, stripe: 0, rates: .fullPass)
        let high = WipeRules.wipe(sample, wetness: 0, strength: 1, stripe: 1, rates: .fullPass)
        XCTAssertEqual(low.dust, 0.8, accuracy: 1e-5)
        XCTAssertEqual(high.dust, 0.8 * 0.80, accuracy: 1e-5)
    }

    func testWetThresholdIsStrict() {
        XCTAssertFalse(WipeRules.isWet(0.3))
        XCTAssertTrue(WipeRules.isWet(0.31))
    }

    func testZeroStrengthChangesNothing() {
        let out = WipeRules.wipe(sample, wetness: 1, strength: 0, stripe: 0.5, rates: .fullPass)
        XCTAssertEqual(out, sample)
    }

    func testWetnessPickup() {
        XCTAssertEqual(WipeRules.wetnessAfterWipe(0.9, strength: 1, rates: .fullPass), 0.9 * 0.6, accuracy: 1e-5)
    }

    func testTwoHalfSegmentsEqualOneFullPass() {
        let half = WipeRules.effectiveRate(0.7, segmentLength: 70, radius: 70)
        XCTAssertEqual((1 - half) * (1 - half), 0.3, accuracy: 1e-5)
    }

    func testEffectiveRateClampsLongSegments() {
        XCTAssertEqual(WipeRules.effectiveRate(0.7, segmentLength: 10_000, radius: 70), 0.7, accuracy: 1e-6)
        XCTAssertEqual(WipeRules.effectiveRate(0.7, segmentLength: 10, radius: 0), 0)
    }

    func testForSegmentOfFullLengthEqualsFullPass() {
        let rates = WipeRates.forSegment(length: 140, radius: 70)
        XCTAssertEqual(rates.wetDust, WipeRates.fullPass.wetDust, accuracy: 1e-6)
        XCTAssertEqual(rates.pickup, WipeRates.fullPass.pickup, accuracy: 1e-6)
    }

    func testFalloff() {
        XCTAssertEqual(WipeRules.falloff(distance: 0, radius: 10), 1)
        XCTAssertEqual(WipeRules.falloff(distance: 6, radius: 10), 1)
        XCTAssertEqual(WipeRules.falloff(distance: 10, radius: 10), 0)
    }

    func testDistanceToSegment() {
        let a = SIMD2<Float>(0, 0), b = SIMD2<Float>(10, 0)
        XCTAssertEqual(WipeRules.distanceToSegment(SIMD2(5, 3), a, b), 3, accuracy: 1e-5)
        XCTAssertEqual(WipeRules.distanceToSegment(SIMD2(-4, 0), a, b), 4, accuracy: 1e-5)
        XCTAssertEqual(WipeRules.distanceToSegment(SIMD2(3, 4), a, a), 5, accuracy: 1e-5)
    }

    func testStripeMatchesShaderFormula() {
        let s = WipeRules.stripe(position: SIMD2(10.5, 32.5), direction: SIMD2(1, 0))
        XCTAssertEqual(s, 0.5 + 0.5 * sin(32.5 * Tuning.stripeFrequency), accuracy: 1e-5)
    }
}
