import Foundation
import SwiftData

/// Three deterministic daily missions + one seasonal mission. Deterministic
/// means everyone (and every reinstall) gets the same missions on the same
/// day: the generator is seeded with the day number, never the system RNG.
final class MissionService {

    private let context: ModelContext
    private let calendar: Calendar
    private let now: () -> Date

    init(context: ModelContext,
         calendar: Calendar = .current,
         now: @escaping () -> Date = Date.init) {
        self.context = context
        self.calendar = calendar
        self.now = now
    }

    // MARK: Period keys

    private var dayNumber: Int {
        let reference = Date(timeIntervalSince1970: 0)
        return calendar.dateComponents([.day], from: reference, to: now()).day ?? 0
    }

    private var dayKey: String { "day-\(dayNumber)" }

    private var seasonKey: String {
        let comps = calendar.dateComponents([.year, .month], from: now())
        let month = comps.month ?? 1
        let season: String
        switch month {
        case 3...5: season = "spring"
        case 6...8: season = "summer"
        case 9...11: season = "fall"
        default: season = "winter"
        }
        let year = comps.year ?? 0
        return "season-\(season)-\(year)"
    }

    // MARK: Generation

    /// Returns today's 3 dailies + the seasonal mission, creating them
    /// (and pruning stale ones) if needed.
    func currentMissions() -> [MissionRecord] {
        pruneStale()
        var missions = fetch(periodKey: dayKey)
        if missions.isEmpty {
            missions = makeDailies()
            missions.forEach { context.insert($0) }
        }
        var seasonal = fetch(periodKey: seasonKey)
        if seasonal.isEmpty {
            let mission = makeSeasonal()
            context.insert(mission)
            seasonal = [mission]
        }
        try? context.save()
        return missions.sorted { $0.key < $1.key } + seasonal
    }

    private func fetch(periodKey: String) -> [MissionRecord] {
        let descriptor = FetchDescriptor<MissionRecord>(
            predicate: #Predicate { $0.periodKey == periodKey })
        return (try? context.fetch(descriptor)) ?? []
    }

    private func pruneStale() {
        let day = dayKey
        let season = seasonKey
        let descriptor = FetchDescriptor<MissionRecord>(
            predicate: #Predicate { $0.periodKey != day && $0.periodKey != season })
        for stale in (try? context.fetch(descriptor)) ?? [] {
            context.delete(stale)
        }
    }

    private func makeDailies() -> [MissionRecord] {
        var rng = SeededRandomSource(seed: UInt64(bitPattern: Int64(dayNumber)))
        func pick(_ upper: Int) -> Int { Int(rng.nextUniform() * Double(upper)) }

        // Mission 1: merge a specific mid tier N times.
        let tier = Tier(rawValue: 2 + pick(4)) ?? .tulip      // clover…sunflower
        let count = 3 + pick(4)                               // 3…6
        let m1 = MissionRecord(
            key: "\(dayKey)-merge", periodKey: dayKey, kind: .mergeTier,
            param: tier.rawValue, target: count,
            rewardCoins: 30 + 10 * tier.rawValue,
            title: "Grow \(count) \(tier.displayName)s", isSeasonal: false)

        // Mission 2: reach a score in a single run.
        let goal = (4 + pick(6)) * 100                        // 400…900
        let m2 = MissionRecord(
            key: "\(dayKey)-score", periodKey: dayKey, kind: .reachScore,
            param: 0, target: goal, rewardCoins: 40 + goal / 20,
            title: "Score \(goal) in one run", isSeasonal: false)

        // Mission 3: land a chain.
        let chain = 2 + pick(2)                               // 2…3
        let m3 = MissionRecord(
            key: "\(dayKey)-chain", periodKey: dayKey, kind: .chainOf,
            param: 0, target: chain, rewardCoins: 25 + chain * 15,
            title: "Land a x\(chain) chain", isSeasonal: false)

        return [m1, m2, m3]
    }

    private func makeSeasonal() -> MissionRecord {
        MissionRecord(
            key: "\(seasonKey)-grow", periodKey: seasonKey, kind: .mergeTier,
            param: Tier.pumpkin.rawValue, target: 25, rewardCoins: 400,
            title: "Season goal: grow 25 Pumpkins", isSeasonal: true)
    }

    // MARK: Progress

    func report(_ event: GameEvent) {
        let missions = currentMissions().filter { !$0.isClaimed && !$0.isComplete }
        for mission in missions {
            switch (event, mission.kind) {
            case let (.merged(result), .mergeTier) where result.rawValue == mission.param:
                mission.progress += 1
            case let (.runFinished(score, _), .reachScore):
                mission.progress = max(mission.progress, score)
            case let (.runFinished(_, bestChain), .chainOf):
                mission.progress = max(mission.progress, bestChain)
            case (.runFinished, .playRuns):
                mission.progress += 1
            default:
                break
            }
        }
        try? context.save()
    }

    /// Claims a completed mission; returns coins granted (0 if not claimable).
    @discardableResult
    func claim(_ mission: MissionRecord, economy: EconomyService) -> Int {
        guard mission.isComplete, !mission.isClaimed else { return 0 }
        mission.isClaimed = true
        economy.award(coins: mission.rewardCoins)
        try? context.save()
        return mission.rewardCoins
    }
}
