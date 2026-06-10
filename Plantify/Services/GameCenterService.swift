import Foundation
import GameKit
import UIKit

/// Defensive Game Center wrapper: every call is a no-op until authentication
/// succeeds, so the game runs fine without entitlements, network or a signed
/// build. Leaderboard/achievement IDs must match App Store Connect.
@MainActor
final class GameCenterService: ObservableObject {

    static let leaderboardID = "plantify.highscores"
    static func achievementID(for tier: Tier) -> String {
        "plantify.grow.\(tier.assetName)"
    }

    @Published private(set) var isAuthenticated = false

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                if let viewController,
                   let root = UIApplication.shared.connectedScenes
                       .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
                       .first?.rootViewController {
                    root.present(viewController, animated: true)
                    return
                }
                self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated && error == nil
            }
        }
    }

    func submit(score: Int) {
        guard isAuthenticated else { return }
        Task {
            try? await GKLeaderboard.submitScore(
                score, context: 0, player: GKLocalPlayer.local,
                leaderboardIDs: [Self.leaderboardID])
        }
    }

    func reportDiscovery(of tier: Tier) {
        guard isAuthenticated else { return }
        let achievement = GKAchievement(identifier: Self.achievementID(for: tier))
        achievement.percentComplete = 100
        achievement.showsCompletionBanner = true
        GKAchievement.report([achievement]) { _ in }
    }
}
