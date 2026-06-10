import Foundation

/// Pure game-rules engine: merge results, chain windows, scoring, discoveries
/// and the danger-line countdown. No UIKit/SpriteKit imports — fully unit
/// testable and driven entirely by injected timestamps.
final class GameEngine {

    struct MergeOutcome: Equatable {
        /// Tier created by the merge, or `nil` when two max-tier plants pop.
        let resultTier: Tier?
        let pointsAwarded: Int
        /// 1 = lone merge, 2+ = chain reaction multiplier.
        let chainCount: Int
        let isFirstDiscovery: Bool
    }

    // MARK: State
    private(set) var score = 0
    private(set) var totalMerges = 0
    private(set) var bestChain = 0
    private(set) var discoveredTiers: Set<Tier>
    /// Discoveries made during the current run only.
    private(set) var newDiscoveries: Set<Tier> = []
    private(set) var isGameOver = false

    private var lastMergeTime: TimeInterval?
    private var chainCount = 0
    private var dangerSince: TimeInterval?

    let chainWindow: TimeInterval
    let dangerGrace: TimeInterval

    init(discovered: Set<Tier> = [],
         chainWindow: TimeInterval = GameFeel.chainWindow,
         dangerGrace: TimeInterval = GameFeel.dangerSeconds) {
        self.discoveredTiers = discovered.union([.seed])
        self.chainWindow = chainWindow
        self.dangerGrace = dangerGrace
    }

    // MARK: Merging

    static func canMerge(_ a: Tier, _ b: Tier) -> Bool { a == b }

    /// Register that two plants of `tier` touched and fused at `time`
    /// (any monotonic clock — the SpriteKit update time in production).
    @discardableResult
    func registerMerge(of tier: Tier, at time: TimeInterval) -> MergeOutcome {
        if let last = lastMergeTime, time - last <= chainWindow {
            chainCount += 1
        } else {
            chainCount = 1
        }
        lastMergeTime = time
        bestChain = max(bestChain, chainCount)
        totalMerges += 1

        let result = tier.next
        let base: Int
        if let result {
            base = result.points
        } else {
            // Two Great Oaks vanish in glory.
            base = tier.points * GameFeel.maxOakBonusMultiplier
        }
        let awarded = base * chainCount
        score += awarded

        var isFirst = false
        if let result, !discoveredTiers.contains(result) {
            discoveredTiers.insert(result)
            newDiscoveries.insert(result)
            isFirst = true
        }
        return MergeOutcome(resultTier: result,
                            pointsAwarded: awarded,
                            chainCount: chainCount,
                            isFirstDiscovery: isFirst)
    }

    /// Chain multiplier a merge would receive if it landed at `time`.
    func chainMultiplierIfMerged(at time: TimeInterval) -> Int {
        guard let last = lastMergeTime, time - last <= chainWindow else { return 1 }
        return chainCount + 1
    }

    // MARK: Danger line

    /// Feed every physics tick. Returns `true` the moment the run ends
    /// (plants sat above the line for the full grace period).
    @discardableResult
    func updateDanger(anyPlantAboveLine: Bool, at time: TimeInterval) -> Bool {
        guard !isGameOver else { return true }
        if anyPlantAboveLine {
            if dangerSince == nil { dangerSince = time }
            if time - (dangerSince ?? time) >= dangerGrace {
                isGameOver = true
                return true
            }
        } else {
            dangerSince = nil
        }
        return false
    }

    /// 0…1 progress toward game over, for the HUD warning meter.
    func dangerProgress(at time: TimeInterval) -> Double {
        if isGameOver { return 1 }
        guard let since = dangerSince else { return 0 }
        return min(1, max(0, (time - since) / dangerGrace))
    }

    // MARK: Lifecycle

    func reset(keepDiscoveries: Bool = true) {
        score = 0
        totalMerges = 0
        bestChain = 0
        chainCount = 0
        lastMergeTime = nil
        dangerSince = nil
        isGameOver = false
        newDiscoveries = []
        if !keepDiscoveries { discoveredTiers = [.seed] }
    }
}
