import Foundation
import SwiftData

/// Composition root: builds and owns every service, the SwiftData container
/// and the single `PlayerProfile`. Injected into the view tree as an
/// `@EnvironmentObject`, and into `GameViewModel` by reference, so nothing
/// reaches for singletons and everything can be swapped in tests/previews.
@MainActor
final class AppServices: ObservableObject {

    let container: ModelContainer
    let context: ModelContext
    let profile: PlayerProfile

    let haptics: HapticsServicing
    let audio: AudioServicing
    let gameCenter: GameCenterService
    let notifications: NotificationService
    let store: StoreService
    let economy: EconomyService
    let missions: MissionService

    init(container: ModelContainer,
         haptics: HapticsServicing,
         audio: AudioServicing) {
        self.container = container
        self.context = container.mainContext
        self.haptics = haptics
        self.audio = audio
        self.gameCenter = GameCenterService()
        self.notifications = NotificationService()
        self.store = StoreService()

        // Fetch-or-create the single player profile.
        let fetched = (try? context.fetch(FetchDescriptor<PlayerProfile>()))?.first
        if let fetched {
            profile = fetched
        } else {
            let fresh = PlayerProfile()
            context.insert(fresh)
            try? context.save()
            profile = fresh
        }

        economy = EconomyService(profile: profile)
        missions = MissionService(context: context)

        audio.isMuted = !profile.soundEnabled
        haptics.prepare()
    }

    /// Production wiring.
    static func live() -> AppServices {
        AppServices(container: PersistenceService.makeContainer(),
                    haptics: HapticsService(),
                    audio: AudioService())
    }

    /// In-memory wiring for previews.
    static func preview() -> AppServices {
        AppServices(container: PersistenceService.makeContainer(inMemory: true),
                    haptics: SilentHaptics(),
                    audio: AudioService())
    }

    var currentTheme: Theme { Theme.byID(profile.selectedThemeID) }
}
