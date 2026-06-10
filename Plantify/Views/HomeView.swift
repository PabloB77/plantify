import SwiftUI
import SwiftData

struct RootView: View {
    var body: some View {
        NavigationStack {
            HomeView()
        }
    }
}

// MARK: - Home

struct HomeView: View {
    @EnvironmentObject private var services: AppServices
    @State private var showGame = false
    @State private var missions: [MissionRecord] = []

    var body: some View {
        ZStack {
            FarmBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    titleBlock
                    statRow

                    Button("PLAY") { showGame = true }
                        .buttonStyle(PixelButtonStyle())
                        .scaleEffect(1.25)
                        .padding(.vertical, 14)

                    missionsPanel

                    HStack(spacing: 14) {
                        NavigationLink("Greenhouse") { GreenhouseView() }
                            .buttonStyle(PixelButtonStyle(prominent: false))
                        NavigationLink("Settings") { SettingsView() }
                            .buttonStyle(PixelButtonStyle(prominent: false))
                    }
                    .padding(.bottom, 28)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showGame, onDismiss: refresh) {
            GameContainerView(services: services)
        }
        .onAppear {
            services.gameCenter.authenticate()
            services.store.start()
            refresh()
        }
    }

    private func refresh() {
        missions = services.missions.currentMissions()
    }

    private var titleBlock: some View {
        VStack(spacing: 4) {
            Text("PLANTIFY")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: PixelPalette.ink, radius: 0, x: 0, y: 4)
            HStack(spacing: 6) {
                Text("Best: \(services.profile.bestScore)")
                if services.profile.isSupporter {
                    Text("· Supporter ♥")
                }
            }
            .font(.system(.subheadline, design: .rounded).weight(.bold))
            .foregroundStyle(.white.opacity(0.95))
            .shadow(color: PixelPalette.ink.opacity(0.8), radius: 0, x: 0, y: 2)
        }
        .padding(.top, 26)
    }

    private var statRow: some View {
        HStack(spacing: 10) {
            StatChip(icon: "icon_coin", value: "\(services.profile.coins)")
            StatChip(icon: "icon_flame", value: "\(services.profile.streak)")
            StatChip(icon: "icon_freeze", value: "\(services.profile.freezes)")
            StatChip(icon: "icon_coin", value: "Lv \(services.profile.level)")
        }
    }

    private var missionsPanel: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Today's Missions")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(PixelPalette.ink)
                if missions.isEmpty {
                    Text("Play a run to sprout some missions!")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(PixelPalette.ink.opacity(0.7))
                }
                ForEach(missions, id: \.key) { mission in
                    MissionRow(mission: mission) {
                        services.missions.claim(mission, economy: services.economy)
                        refresh()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Mission row

struct MissionRow: View {
    let mission: MissionRecord
    let onClaim: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(mission.title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(PixelPalette.ink)
                if mission.isSeasonal {
                    Text("SEASON")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(PixelPalette.leaf))
                        .foregroundStyle(.white)
                }
                Spacer()
                if mission.isClaimed {
                    Text("✓")
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                        .foregroundStyle(PixelPalette.leaf)
                } else if mission.isComplete {
                    Button("Claim +\(mission.rewardCoins)", action: onClaim)
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(PixelPalette.gold))
                        .foregroundStyle(PixelPalette.ink)
                } else {
                    HStack(spacing: 3) {
                        Image("icon_coin")
                            .resizable().interpolation(.none)
                            .frame(width: 14, height: 14)
                        Text("\(mission.rewardCoins)")
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(PixelPalette.ink.opacity(0.75))
                    }
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(PixelPalette.ink.opacity(0.15))
                    Capsule().fill(PixelPalette.leaf)
                        .frame(width: max(8, geo.size.width * mission.fractionDone))
                }
            }
            .frame(height: 8)
            Text("\(min(mission.progress, mission.target))/\(mission.target)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(PixelPalette.ink.opacity(0.6))
        }
    }
}

// MARK: - Farm backdrop

struct FarmBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            Image("bg_farm")
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fill)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .overlay(Color.black.opacity(0.10))
        }
        .ignoresSafeArea()
    }
}
