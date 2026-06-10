import XCTest
@testable import Plantify

final class DropGeneratorTests: XCTestCase {

    func testSameSeedProducesIdenticalSequence() {
        var a = DropGenerator(rng: SeededRandomSource(seed: 0xC0FFEE))
        var b = DropGenerator(rng: SeededRandomSource(seed: 0xC0FFEE))
        var seqA: [Tier] = []; for _ in 0..<50 { seqA.append(a.nextTier()) }
        var seqB: [Tier] = []; for _ in 0..<50 { seqB.append(b.nextTier()) }
        XCTAssertEqual(seqA, seqB)
    }

    func testDifferentSeedsDiverge() {
        var a = DropGenerator(rng: SeededRandomSource(seed: 1))
        var b = DropGenerator(rng: SeededRandomSource(seed: 2))
        var seqA: [Tier] = []; for _ in 0..<50 { seqA.append(a.nextTier()) }
        var seqB: [Tier] = []; for _ in 0..<50 { seqB.append(b.nextTier()) }
        XCTAssertNotEqual(seqA, seqB)
    }

    func testHoneymoonPhaseOnlyDropsTinyTiers() {
        var gen = DropGenerator(rng: SeededRandomSource(seed: 42))
        for _ in 0..<GameFeel.honeymoonPhase1 {
            let tier = gen.nextTier()
            XCTAssertTrue([Tier.seed, .sprout].contains(tier),
                          "Honeymoon drops should be seed or sprout, got \(tier)")
        }
    }

    func testAllDropsAreDroppableTiers() {
        var gen = DropGenerator(rng: SeededRandomSource(seed: 7))
        for _ in 0..<300 {
            XCTAssertTrue(gen.nextTier().isDroppable)
        }
    }

    func testWeightsMatchPhases() {
        XCTAssertEqual(DropGenerator.weights(forDropIndex: 0).count,
                       GameFeel.phase1Weights.count)
        XCTAssertEqual(DropGenerator.weights(forDropIndex: GameFeel.honeymoonPhase1).count,
                       GameFeel.phase2Weights.count)
        XCTAssertEqual(DropGenerator.weights(forDropIndex: GameFeel.honeymoonPhase2).count,
                       GameFeel.steadyWeights.count)
    }

    func testResetRestartsHoneymoon() {
        var gen = DropGenerator(rng: SeededRandomSource(seed: 9))
        for _ in 0..<100 { _ = gen.nextTier() }
        gen.reset()
        XCTAssertEqual(gen.dropsIssued, 0)
        let tier = gen.nextTier()
        XCTAssertTrue([Tier.seed, .sprout].contains(tier))
    }
}
