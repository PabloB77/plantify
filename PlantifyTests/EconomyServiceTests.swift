import XCTest
@testable import Plantify

final class EconomyServiceTests: XCTestCase {

    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    /// A date in "day n" of our fake timeline (1 hour past midnight UTC).
    private func day(_ n: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(n) * 86_400 + 3_600)
    }

    /// Builds a profile + economy whose "now" is controlled by a mutable box.
    private func makeEconomy(startDay: Int = 10) -> (PlayerProfile, EconomyService, (Int) -> Void) {
        let profile = PlayerProfile()
        let clock = Box(date: day(startDay))
        let economy = EconomyService(profile: profile, calendar: calendar, now: { clock.date })
        let advance: (Int) -> Void = { n in clock.date = self.day(n) }
        return (profile, economy, advance)
    }

    private final class Box {
        var date: Date
        init(date: Date) { self.date = date }
    }

    // MARK: - Streaks

    func testFirstPlayStartsStreakAtOne() {
        let (profile, economy, _) = makeEconomy()
        let result = economy.recordDailyPlay()
        XCTAssertEqual(result.streak, 1)
        XCTAssertEqual(profile.streak, 1)
        XCTAssertFalse(result.usedFreeze)
    }

    func testSameDayPlayDoesNotChangeStreak() {
        let (profile, economy, _) = makeEconomy()
        _ = economy.recordDailyPlay()
        let again = economy.recordDailyPlay()
        XCTAssertEqual(again.streak, 1)
        XCTAssertEqual(profile.streak, 1)
    }

    func testConsecutiveDaysIncrementStreak() {
        let (profile, economy, advance) = makeEconomy(startDay: 10)
        _ = economy.recordDailyPlay()
        advance(11)
        let result = economy.recordDailyPlay()
        XCTAssertEqual(result.streak, 2)
        XCTAssertEqual(profile.streak, 2)
    }

    func testMissedDayConsumesFreezeAndKeepsStreak() {
        let (profile, economy, advance) = makeEconomy(startDay: 10)
        profile.freezes = 1
        _ = economy.recordDailyPlay()        // day 10, streak 1
        advance(12)                          // skipped day 11
        let result = economy.recordDailyPlay()
        XCTAssertTrue(result.usedFreeze)
        XCTAssertEqual(result.streak, 2)     // freeze bridges the gap
        XCTAssertEqual(profile.freezes, 0)
    }

    func testMissedDayWithoutFreezeResetsStreak() {
        let (profile, economy, advance) = makeEconomy(startDay: 10)
        profile.freezes = 0
        _ = economy.recordDailyPlay()
        advance(12)
        let result = economy.recordDailyPlay()
        XCTAssertFalse(result.usedFreeze)
        XCTAssertEqual(result.streak, 1)
        XCTAssertEqual(profile.streak, 1)
    }

    func testLongGapAlwaysResetsStreak() {
        let (profile, economy, advance) = makeEconomy(startDay: 10)
        profile.freezes = 5
        _ = economy.recordDailyPlay()
        advance(15)                          // gap of 5 days — freezes can't save this
        let result = economy.recordDailyPlay()
        XCTAssertEqual(result.streak, 1)
        XCTAssertEqual(profile.freezes, 5)   // not consumed on hard reset
    }

    func testDaySevenGrantsWeeklyReward() {
        let (profile, economy, advance) = makeEconomy(startDay: 10)
        profile.freezes = 0
        let startCoins = profile.coins
        var result = economy.recordDailyPlay()
        for d in 11...16 {
            advance(d)
            result = economy.recordDailyPlay()
        }
        XCTAssertEqual(result.streak, 7)
        XCTAssertTrue(result.earnedWeeklyReward)
        XCTAssertEqual(profile.freezes, GameFeel.day7FreezeReward)
        XCTAssertEqual(profile.coins, startCoins + GameFeel.day7Coins)
    }

    // MARK: - Coins

    func testSpendFailsWhenInsufficient() {
        let (profile, economy, _) = makeEconomy()
        profile.coins = 10
        XCTAssertFalse(economy.spend(coins: 50))
        XCTAssertEqual(profile.coins, 10)
    }

    func testSpendSucceedsWhenAffordable() {
        let (profile, economy, _) = makeEconomy()
        profile.coins = 100
        XCTAssertTrue(economy.spend(coins: 60))
        XCTAssertEqual(profile.coins, 40)
    }

    func testPurchaseFreeze() {
        let (profile, economy, _) = makeEconomy()
        profile.coins = GameFeel.freezeCost
        profile.freezes = 0
        XCTAssertTrue(economy.purchaseFreeze())
        XCTAssertEqual(profile.freezes, 1)
        XCTAssertEqual(profile.coins, 0)
        XCTAssertFalse(economy.purchaseFreeze()) // broke now
    }

    // MARK: - XP / levels

    func testAddXPLevelsUp() {
        let (profile, economy, _) = makeEconomy()
        XCTAssertEqual(profile.level, 1)
        let leveled = economy.addXP(EconomyService.xpNeeded(forLevel: 1))
        XCTAssertTrue(leveled)
        XCTAssertEqual(profile.level, 2)
    }

    func testAddXPWithoutLevelUp() {
        let (profile, economy, _) = makeEconomy()
        let leveled = economy.addXP(10)
        XCTAssertFalse(leveled)
        XCTAssertEqual(profile.level, 1)
        XCTAssertEqual(profile.xp, 10)
    }

    // MARK: - Run settlement

    func testSettleRunMathAndBestScore() {
        let (profile, economy, _) = makeEconomy()
        let startCoins = profile.coins
        let score = 500, merges = 12, discoveries = 2

        let reward = economy.settleRun(score: score, merges: merges, discoveries: discoveries)

        let expectedCoins = score / GameFeel.coinsPerScoreDivisor
            + discoveries * GameFeel.discoveryCoinBonus
        let expectedXP = merges * GameFeel.xpPerMerge + score / GameFeel.xpPerScoreDivisor

        XCTAssertEqual(reward.coins, expectedCoins)
        XCTAssertEqual(reward.xp, expectedXP)
        XCTAssertEqual(profile.coins, startCoins + expectedCoins)
        XCTAssertTrue(reward.isNewBest)
        XCTAssertEqual(profile.bestScore, score)

        // Lower score doesn't beat best
        let second = economy.settleRun(score: 100, merges: 1, discoveries: 0)
        XCTAssertFalse(second.isNewBest)
        XCTAssertEqual(profile.bestScore, score)
    }

    // MARK: - Themes

    func testPurchaseAndSelectTheme() {
        let (profile, economy, _) = makeEconomy()
        let sunset = Theme.sunset
        profile.coins = sunset.cost

        XCTAssertTrue(economy.purchaseTheme(sunset))
        XCTAssertTrue(profile.ownedThemeIDs.contains(sunset.id))
        XCTAssertEqual(profile.coins, 0)

        economy.selectTheme(sunset)
        XCTAssertEqual(profile.selectedThemeID, sunset.id)
    }

    func testSelectThemeIgnoresUnowned() {
        let (profile, economy, _) = makeEconomy()
        let night = Theme.night
        let before = profile.selectedThemeID
        economy.selectTheme(night)               // never purchased
        XCTAssertEqual(profile.selectedThemeID, before)
    }
}
