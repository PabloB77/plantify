import XCTest
@testable import Plantify

final class GameEngineTests: XCTestCase {

    func testMergeProducesNextTier() {
        let engine = GameEngine()
        let outcome = engine.registerMerge(of: .seed, at: 0)
        XCTAssertEqual(outcome.resultTier, .sprout)
        XCTAssertEqual(outcome.chainCount, 1)
        XCTAssertEqual(outcome.pointsAwarded, Tier.sprout.points)
        XCTAssertEqual(engine.score, Tier.sprout.points)
    }

    func testChainMultiplierGrowsInsideWindowAndResetsOutside() {
        let engine = GameEngine(chainWindow: 2.0)

        let first = engine.registerMerge(of: .seed, at: 0)
        XCTAssertEqual(first.chainCount, 1)

        let second = engine.registerMerge(of: .seed, at: 1.0)
        XCTAssertEqual(second.chainCount, 2)
        XCTAssertEqual(second.pointsAwarded, Tier.sprout.points * 2)

        let third = engine.registerMerge(of: .sprout, at: 2.5)
        XCTAssertEqual(third.chainCount, 3, "1.5s after the last merge is still inside the window")

        let cold = engine.registerMerge(of: .seed, at: 10)
        XCTAssertEqual(cold.chainCount, 1, "Chains reset after the window lapses")
        XCTAssertEqual(engine.bestChain, 3)
    }

    func testChainMultiplierIfMergedPredictsWithoutMutating() {
        let engine = GameEngine(chainWindow: 2.0)
        XCTAssertEqual(engine.chainMultiplierIfMerged(at: 0), 1)
        engine.registerMerge(of: .seed, at: 0)
        XCTAssertEqual(engine.chainMultiplierIfMerged(at: 1.0), 2)
        XCTAssertEqual(engine.chainMultiplierIfMerged(at: 5.0), 1)
        XCTAssertEqual(engine.totalMerges, 1, "Prediction must not register a merge")
    }

    func testDiscoveryReportedOnlyOnce() {
        let engine = GameEngine()
        let first = engine.registerMerge(of: .seed, at: 0)
        XCTAssertTrue(first.isFirstDiscovery)
        XCTAssertEqual(engine.newDiscoveries, [.sprout])

        let again = engine.registerMerge(of: .seed, at: 10)
        XCTAssertFalse(again.isFirstDiscovery)
        XCTAssertEqual(engine.newDiscoveries, [.sprout])
    }

    func testPreseededDiscoveriesAreNotRediscovered() {
        let engine = GameEngine(discovered: [.sprout])
        let outcome = engine.registerMerge(of: .seed, at: 0)
        XCTAssertFalse(outcome.isFirstDiscovery)
        XCTAssertTrue(engine.newDiscoveries.isEmpty)
    }

    func testTwoGreatOaksPopForBonus() {
        let engine = GameEngine()
        let outcome = engine.registerMerge(of: .greatOak, at: 0)
        XCTAssertNil(outcome.resultTier)
        XCTAssertEqual(outcome.pointsAwarded,
                       Tier.greatOak.points * GameFeel.maxOakBonusMultiplier)
    }

    func testDangerGracePeriodAndRecovery() {
        let engine = GameEngine(dangerGrace: 2.0)

        XCTAssertFalse(engine.updateDanger(anyPlantAboveLine: true, at: 0))
        XCTAssertFalse(engine.updateDanger(anyPlantAboveLine: true, at: 1.9))
        XCTAssertEqual(engine.dangerProgress(at: 1.0), 0.5, accuracy: 0.001)

        // Dropping below the line resets the countdown.
        XCTAssertFalse(engine.updateDanger(anyPlantAboveLine: false, at: 1.95))
        XCTAssertEqual(engine.dangerProgress(at: 1.95), 0)

        XCTAssertFalse(engine.updateDanger(anyPlantAboveLine: true, at: 5))
        XCTAssertTrue(engine.updateDanger(anyPlantAboveLine: true, at: 7.0))
        XCTAssertTrue(engine.isGameOver)
        XCTAssertEqual(engine.dangerProgress(at: 99), 1)
    }

    func testResetKeepsDiscoveriesByDefault() {
        let engine = GameEngine()
        engine.registerMerge(of: .seed, at: 0)
        engine.updateDanger(anyPlantAboveLine: true, at: 0)
        engine.updateDanger(anyPlantAboveLine: true, at: 10)
        XCTAssertTrue(engine.isGameOver)

        engine.reset()
        XCTAssertEqual(engine.score, 0)
        XCTAssertEqual(engine.totalMerges, 0)
        XCTAssertFalse(engine.isGameOver)
        XCTAssertTrue(engine.newDiscoveries.isEmpty)
        XCTAssertTrue(engine.discoveredTiers.contains(.sprout),
                      "Plantipedia knowledge survives a restart")

        engine.reset(keepDiscoveries: false)
        XCTAssertEqual(engine.discoveredTiers, [.seed])
    }

    func testScoreAccumulatesAcrossMerges() {
        let engine = GameEngine(chainWindow: 0.5)
        engine.registerMerge(of: .seed, at: 0)     // sprout: 3
        engine.registerMerge(of: .clover, at: 10)  // tulip: 10
        XCTAssertEqual(engine.score, Tier.sprout.points + Tier.tulip.points)
        XCTAssertEqual(engine.totalMerges, 2)
    }
}
