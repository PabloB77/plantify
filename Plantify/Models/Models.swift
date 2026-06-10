import Foundation
import SwiftData

// MARK: - Player profile

@Model
final class PlayerProfile {
    var coins: Int
    var xp: Int
    var level: Int
    var bestScore: Int
    var streak: Int
    var freezes: Int
    var lastPlayedDay: Date?
    var totalMerges: Int
    var gamesPlayed: Int
    var notificationsEnabled: Bool
    var soundEnabled: Bool
    var selectedThemeID: String
    var ownedThemeIDs: [String]
    var isSupporter: Bool

    init(coins: Int = 0,
         xp: Int = 0,
         level: Int = 1,
         bestScore: Int = 0,
         streak: Int = 0,
         freezes: Int = 1,
         lastPlayedDay: Date? = nil,
         totalMerges: Int = 0,
         gamesPlayed: Int = 0,
         notificationsEnabled: Bool = false,
         soundEnabled: Bool = true,
         selectedThemeID: String = Theme.day.id,
         ownedThemeIDs: [String] = [Theme.day.id],
         isSupporter: Bool = false) {
        self.coins = coins
        self.xp = xp
        self.level = level
        self.bestScore = bestScore
        self.streak = streak
        self.freezes = freezes
        self.lastPlayedDay = lastPlayedDay
        self.totalMerges = totalMerges
        self.gamesPlayed = gamesPlayed
        self.notificationsEnabled = notificationsEnabled
        self.soundEnabled = soundEnabled
        self.selectedThemeID = selectedThemeID
        self.ownedThemeIDs = ownedThemeIDs
        self.isSupporter = isSupporter
    }
}

// MARK: - Plantipedia discoveries

@Model
final class DiscoveryRecord {
    @Attribute(.unique) var tierRaw: Int
    var discoveredAt: Date

    init(tier: Tier, discoveredAt: Date = .now) {
        self.tierRaw = tier.rawValue
        self.discoveredAt = discoveredAt
    }

    var tier: Tier? { Tier(rawValue: tierRaw) }
}

// MARK: - Missions

enum MissionKind: String, Codable {
    case mergeTier      // create `param` tier plants `target` times
    case reachScore     // finish a run with at least `target` points
    case chainOf        // land a chain of `target`
    case playRuns       // finish `target` runs
}

@Model
final class MissionRecord {
    @Attribute(.unique) var key: String
    var periodKey: String       // day key for dailies, season key for seasonal
    var kindRaw: String
    var param: Int              // e.g. tier raw value for .mergeTier
    var target: Int
    var progress: Int
    var rewardCoins: Int
    var title: String
    var isSeasonal: Bool
    var isClaimed: Bool

    init(key: String, periodKey: String, kind: MissionKind, param: Int,
         target: Int, rewardCoins: Int, title: String, isSeasonal: Bool) {
        self.key = key
        self.periodKey = periodKey
        self.kindRaw = kind.rawValue
        self.param = param
        self.target = target
        self.progress = 0
        self.rewardCoins = rewardCoins
        self.title = title
        self.isSeasonal = isSeasonal
        self.isClaimed = false
    }

    var kind: MissionKind { MissionKind(rawValue: kindRaw) ?? .playRuns }
    var isComplete: Bool { progress >= target }
    var fractionDone: Double { min(1, Double(progress) / Double(max(1, target))) }
}

// MARK: - Cosmetic themes (coins only — never pay-to-win)

struct Theme: Identifiable, Equatable {
    struct RGBA: Equatable {
        let r: Double, g: Double, b: Double, a: Double
    }

    let id: String
    let name: String
    let cost: Int
    /// Color washed over the farm backdrop; alpha 0 = untouched daylight.
    let skyOverlay: RGBA

    static let day = Theme(id: "theme.day", name: "Morning Farm", cost: 0,
                           skyOverlay: RGBA(r: 0, g: 0, b: 0, a: 0))
    static let sunset = Theme(id: "theme.sunset", name: "Harvest Sunset", cost: 300,
                              skyOverlay: RGBA(r: 0.95, g: 0.45, b: 0.25, a: 0.28))
    static let night = Theme(id: "theme.night", name: "Firefly Night", cost: 500,
                             skyOverlay: RGBA(r: 0.07, g: 0.10, b: 0.32, a: 0.45))

    static let all: [Theme] = [.day, .sunset, .night]

    static func byID(_ id: String) -> Theme {
        all.first { $0.id == id } ?? .day
    }
}

// MARK: - Events flowing from a run into missions/stats

enum GameEvent {
    case merged(result: Tier)
    case runFinished(score: Int, bestChain: Int)
}
