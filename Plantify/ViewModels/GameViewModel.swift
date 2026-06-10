import Foundation
import SwiftData
import CoreGraphics

/// How the SpriteKit scene talks back to the app. The scene owns physics and
/// pixels; everything that *means* something (rules, score, rewards, haptics,
/// audio, missions) lives behind this bridge on the main actor.
@MainActor
protocol GameSceneBridge: AnyObject {
    /// Tier currently in the player's hand (for the preview sprite).
    func bridgeHeldTier() -> Tier
    /// Consumes the held tier for an actual drop and advances the queue.
    func bridgeConsumeDrop() -> Tier
    /// A plant just left the hand (haptic/audio tick).
    func bridgeDidDrop(tier: Tier)
    /// Two plants of `tier` fused at scene time `time`.
    func bridgeMerge(of tier: Tier, at time: TimeInterval) -> GameEngine.MergeOutcome
    /// Per-frame danger-line report. Returns whether the run is over plus
    /// the 0…1 countdown progress for visuals.
    func bridgeDanger(anyPlantAboveLine: Bool, at time: TimeInterval) -> (isGameOver: Bool, progress: Double)
}

@MainActor
final class GameViewModel: ObservableObject {

    // MARK: Published HUD state
    @Published private(set) var score = 0
    @Published private(set) var chain = 1
    @Published private(set) var heldTier: Tier = .seed
    @Published private(set) var upNext: Tier = .seed
    @Published private(set) var dangerProgress: Double = 0
    @Published private(set) var isGameOver = false
    @Published private(set) var reward: EconomyService.RunReward?
    @Published private(set) var runDiscoveries: [Tier] = []

    // MARK: Guts
    private let engine: GameEngine
    private var generator = DropGenerator()
    private let services: AppServices
    private var runSettled = false
    private var liveScene: GameScene?

    init(services: AppServices) {
        self.services = services
        let persisted = (try? services.context.fetch(FetchDescriptor<DiscoveryRecord>())) ?? []
        engine = GameEngine(discovered: Set(persisted.compactMap(\.tier)))
        heldTier = generator.nextTier()
        upNext = generator.nextTier()
    }

    var bestScore: Int { services.profile.bestScore }

    // MARK: Scene

    /// Builds (once) and returns the SpriteKit scene for the given view size.
    func scene(for size: CGSize) -> GameScene {
        if let liveScene { return liveScene }
        let scene = GameScene(size: size)
        scene.scaleMode = .resizeFill
        scene.bridge = self
        scene.theme = services.currentTheme
        liveScene = scene
        return scene
    }

    /// Instant restart — no loading, no confirmation, straight back in.
    func restart() {
        engine.reset(keepDiscoveries: true)
        generator.reset()
        heldTier = generator.nextTier()
        upNext = generator.nextTier()
        score = 0
        chain = 1
        dangerProgress = 0
        isGameOver = false
        reward = nil
        runDiscoveries = []
        runSettled = false
        liveScene?.resetBoard()
    }

    // MARK: Settlement

    private func finishRun() {
        guard !runSettled else { return }
        runSettled = true
        isGameOver = true

        services.haptics.gameOverThud()
        services.audio.playGameOver()

        for tier in engine.newDiscoveries {
            services.context.insert(DiscoveryRecord(tier: tier))
            services.gameCenter.reportDiscovery(of: tier)
        }
        services.missions.report(.runFinished(score: engine.score,
                                              bestChain: engine.bestChain))
        reward = services.economy.settleRun(score: engine.score,
                                            merges: engine.totalMerges,
                                            discoveries: engine.newDiscoveries.count)
        services.gameCenter.submit(score: engine.score)
        try? services.context.save()
    }
}

// MARK: - GameSceneBridge

extension GameViewModel: GameSceneBridge {

    func bridgeHeldTier() -> Tier { heldTier }

    func bridgeConsumeDrop() -> Tier {
        let dropped = heldTier
        heldTier = upNext
        upNext = generator.nextTier()
        return dropped
    }

    func bridgeDidDrop(tier: Tier) {
        services.haptics.dropTap()
        services.audio.playDrop()
    }

    func bridgeMerge(of tier: Tier, at time: TimeInterval) -> GameEngine.MergeOutcome {
        let outcome = engine.registerMerge(of: tier, at: time)
        score = engine.score
        chain = outcome.chainCount

        let popTier = outcome.resultTier ?? tier
        services.haptics.mergePop(tier: popTier)
        if outcome.chainCount >= 2 {
            services.haptics.chainSwell(chain: outcome.chainCount)
        }
        services.audio.playMerge(tier: popTier)

        if let result = outcome.resultTier {
            services.missions.report(.merged(result: result))
            if outcome.isFirstDiscovery {
                runDiscoveries.append(result)
            }
        }
        return outcome
    }

    func bridgeDanger(anyPlantAboveLine: Bool, at time: TimeInterval) -> (isGameOver: Bool, progress: Double) {
        let over = engine.updateDanger(anyPlantAboveLine: anyPlantAboveLine, at: time)
        let progress = engine.dangerProgress(at: time)
        // Avoid spamming SwiftUI with identical per-frame updates.
        if abs(progress - dangerProgress) > 0.01 || (progress == 0) != (dangerProgress == 0) {
            dangerProgress = progress
        }
        if over { finishRun() }
        return (engine.isGameOver, progress)
    }
}
