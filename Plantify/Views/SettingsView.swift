import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject private var services: AppServices
    @State private var notifBusy = false
    @State private var thanked = false

    var body: some View {
        ZStack {
            FarmBackdrop()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    Text("Settings")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: PixelPalette.ink, radius: 0, x: 0, y: 3)
                        .padding(.top, 12)

                    soundPanel
                    notificationsPanel
                    freezePanel
                    themesPanel
                    gameCenterPanel
                    tipJarPanel
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .navigationBar)
        .onDisappear { try? services.context.save() }
    }

    // MARK: Sound

    private var soundPanel: some View {
        PixelPanel {
            Toggle(isOn: Binding(
                get: { services.profile.soundEnabled },
                set: { on in
                    services.profile.soundEnabled = on
                    services.audio.isMuted = !on
                })) {
                Text("Sound effects")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(PixelPalette.ink)
            }
            .tint(PixelPalette.leaf)
        }
    }

    // MARK: Notifications

    private var notificationsPanel: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: Binding(
                    get: { services.profile.notificationsEnabled },
                    set: { on in
                        if on {
                            notifBusy = true
                            Task {
                                let granted = await services.notifications.enableDailyReminder()
                                services.profile.notificationsEnabled = granted
                                notifBusy = false
                            }
                        } else {
                            services.notifications.disableDailyReminder()
                            services.profile.notificationsEnabled = false
                        }
                    })) {
                    Text("Daily reminder")
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                        .foregroundStyle(PixelPalette.ink)
                }
                .tint(PixelPalette.leaf)
                .disabled(notifBusy)
                Text("One gentle nudge at 6:30 pm. Never more.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(PixelPalette.ink.opacity(0.65))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Freezes

    private var freezePanel: some View {
        PixelPanel {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image("icon_freeze")
                            .resizable().interpolation(.none)
                            .frame(width: 20, height: 20)
                        Text("Streak freezes: \(services.profile.freezes)")
                            .font(.system(.headline, design: .rounded).weight(.heavy))
                            .foregroundStyle(PixelPalette.ink)
                    }
                    Text("Covers one missed day automatically.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(PixelPalette.ink.opacity(0.65))
                }
                Spacer()
                Button("Buy \(GameFeel.freezeCost)") {
                    services.economy.purchaseFreeze()
                    try? services.context.save()
                }
                .buttonStyle(PixelButtonStyle(prominent: false))
                .disabled(services.profile.coins < GameFeel.freezeCost)
                .opacity(services.profile.coins < GameFeel.freezeCost ? 0.55 : 1)
            }
        }
    }

    // MARK: Themes

    private var themesPanel: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: 10) {
                Text("Themes")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(PixelPalette.ink)
                Text("Cosmetic only — applies to your next run.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(PixelPalette.ink.opacity(0.65))
                ForEach(Theme.all) { theme in
                    themeRow(theme)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func themeRow(_ theme: Theme) -> some View {
        let owned = services.profile.ownedThemeIDs.contains(theme.id)
        let selected = services.profile.selectedThemeID == theme.id
        return HStack {
            Circle()
                .fill(Color(red: theme.skyOverlay.r,
                            green: theme.skyOverlay.g,
                            blue: theme.skyOverlay.b)
                    .opacity(max(0.25, theme.skyOverlay.a)))
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(PixelPalette.ink, lineWidth: 2))
            Text(theme.name)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(PixelPalette.ink)
            Spacer()
            if selected {
                Text("Equipped")
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(PixelPalette.leaf)
            } else if owned {
                Button("Select") {
                    services.economy.selectTheme(theme)
                    try? services.context.save()
                }
                .font(.system(.caption, design: .rounded).weight(.heavy))
                .foregroundStyle(PixelPalette.ink)
            } else {
                Button {
                    if services.economy.purchaseTheme(theme) {
                        services.economy.selectTheme(theme)
                        try? services.context.save()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image("icon_coin")
                            .resizable().interpolation(.none)
                            .frame(width: 14, height: 14)
                        Text("\(theme.cost)")
                            .font(.system(.caption, design: .rounded).weight(.heavy))
                    }
                }
                .foregroundStyle(services.profile.coins >= theme.cost
                                 ? PixelPalette.ink : PixelPalette.ink.opacity(0.4))
                .disabled(services.profile.coins < theme.cost)
            }
        }
    }

    // MARK: Game Center

    private var gameCenterPanel: some View {
        PixelPanel {
            HStack {
                Text("Game Center")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(PixelPalette.ink)
                Spacer()
                Text(services.gameCenter.isAuthenticated ? "Connected ✓" : "Not signed in")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(services.gameCenter.isAuthenticated
                                     ? PixelPalette.leaf : PixelPalette.ink.opacity(0.6))
            }
        }
    }

    // MARK: Tip jar

    private var tipJarPanel: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: 10) {
                Text("Supporter Tip Jar")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(PixelPalette.ink)
                Text("Tips change nothing in the game — pure gratitude, plus a tiny badge on the home screen.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(PixelPalette.ink.opacity(0.65))

                if services.store.products.isEmpty {
                    Text("Tips unavailable right now (App Store products not loaded).")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(PixelPalette.ink.opacity(0.5))
                } else {
                    ForEach(services.store.products, id: \.id) { product in
                        HStack {
                            Text(product.displayName.isEmpty ? product.id : product.displayName)
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(PixelPalette.ink)
                            Spacer()
                            Button(product.displayPrice) {
                                Task {
                                    if await services.store.purchase(product) {
                                        services.profile.isSupporter = true
                                        try? services.context.save()
                                        thanked = true
                                    }
                                }
                            }
                            .buttonStyle(PixelButtonStyle(prominent: false))
                        }
                    }
                }

                if thanked || services.profile.isSupporter {
                    Text("Thank you for keeping the greenhouse warm ♥")
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .foregroundStyle(PixelPalette.leaf)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
