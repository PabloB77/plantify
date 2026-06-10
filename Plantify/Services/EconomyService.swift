import Foundation

/// Coins, XP, levels, streaks and freezes. Pure logic over a `PlayerProfile`
/// with injectable calendar + clock so every rule is unit-testable.
/// Coins buy cosmetics and streak freezes only — never power.
final class EconomyService {

    struct StreakResult: Equatable {
        let streak: Int
        let usedFreeze: Bool
        let earnedWeeklyReward: Bool
    }

    let profile: PlayerProfile
    private let calendar: Calendar
    private let now: () -> Date

    init(profile: PlayerProfile,
         calendar: Calendar = .current,
         now: @escaping () -> Date = Date.init) {
        self.profile = profile
        self.calendar = calendar
        self.now = now
    }

    // MARK: Streak

    /// Call once whenever a run finishes. Handles consecutive days, a single
    /// missed day covered by a streak freeze, resets, and the day-7 reward.
    @discardableResult
    func recordDailyPlay() -> StreakResult {
        let today = calendar.startOfDay(for: now())
        var usedFreeze = false

        if let last = profile.lastPlayedDay {
            let lastDay = calendar.startOfDay(for: last)
            let gap = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            switch gap {
            case 0:
                return StreakResult(streak: profile.streak,
                                    usedFreeze: false,
                                    earnedWeeklyReward: false)
            case 1:
                profile.streak += 1
            case 2 where profile.freezes > 0:
                profile.freezes -= 1
                profile.streak += 1
                usedFreeze = true
            default:
                profile.streak = 1
            }
        } else {
            profile.streak = 1
        }
        profile.lastPlayedDay = today

        var weekly = false
        if profile.streak > 0, profile.streak % 7 == 0 {
            profile.freezes += GameFeel.day7FreezeReward
            profile.coins += GameFeel.day7Coins
            weekly = true
        }
        return StreakResult(streak: profile.streak,
                            usedFreeze: usedFreeze,
                            earnedWeeklyReward: weekly)
    }

    // MARK: Coins

    func award(coins: Int) {
        profile.coins += max(0, coins)
    }

    @discardableResult
    func spend(coins: Int) -> Bool {
        guard coins >= 0, profile.coins >= coins else { return false }
        profile.coins -= coins
        return true
    }

    @discardableResult
    func purchaseFreeze() -> Bool {
        guard spend(coins: GameFeel.freezeCost) else { return false }
        profile.freezes += 1
        return true
    }

    @discardableResult
    func purchaseTheme(_ theme: Theme) -> Bool {
        guard !profile.ownedThemeIDs.contains(theme.id) else { return true }
        guard spend(coins: theme.cost) else { return false }
        profile.ownedThemeIDs.append(theme.id)
        return true
    }

    func selectTheme(_ theme: Theme) {
        guard profile.ownedThemeIDs.contains(theme.id) else { return }
        profile.selectedThemeID = theme.id
    }

    // MARK: XP & levels

    static func xpNeeded(forLevel level: Int) -> Int { 100 * max(1, level) }

    /// Returns `true` if the player leveled up at least once.
    @discardableResult
    func addXP(_ amount: Int) -> Bool {
        guard amount > 0 else { return false }
        profile.xp += amount
        var leveled = false
        while profile.xp >= Self.xpNeeded(forLevel: profile.level) {
            profile.xp -= Self.xpNeeded(forLevel: profile.level)
            profile.level += 1
            leveled = true
        }
        return leveled
    }

    // MARK: Run settlement

    struct RunReward {
        let coins: Int
        let xp: Int
        let leveledUp: Bool
        let streak: StreakResult
        let isNewBest: Bool
    }

    /// Converts a finished run into coins, XP, streak progress and best score.
    func settleRun(score: Int, merges: Int, discoveries: Int) -> RunReward {
        let coins = score / GameFeel.coinsPerScoreDivisor
            + discoveries * GameFeel.discoveryCoinBonus
        let xp = merges * GameFeel.xpPerMerge + score / GameFeel.xpPerScoreDivisor
        award(coins: coins)
        let leveled = addXP(xp)
        let streak = recordDailyPlay()
        profile.totalMerges += merges
        profile.gamesPlayed += 1
        var newBest = false
        if score > profile.bestScore {
            profile.bestScore = score
            newBest = true
        }
        return RunReward(coins: coins, xp: xp, leveledUp: leveled,
                         streak: streak, isNewBest: newBest)
    }
}
