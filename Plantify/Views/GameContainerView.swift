import SwiftUI
import SpriteKit

struct GameContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: GameViewModel

    init(services: AppServices) {
        _vm = StateObject(wrappedValue: GameViewModel(services: services))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                SpriteView(scene: vm.scene(for: geo.size),
                           preferredFramesPerSecond: 60)
                    .ignoresSafeArea()

                VStack(spacing: 6) {
                    hudTop
                    if vm.dangerProgress > 0 && !vm.isGameOver {
                        dangerMeter
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if vm.isGameOver {
                    GameOverOverlay(vm: vm) { dismiss() }
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.8), value: vm.isGameOver)
        }
        .ignoresSafeArea()
        .statusBarHidden()
    }

    // MARK: HUD

    private var hudTop: some View {
        HStack(alignment: .top) {
            Button {
                dismiss()
            } label: {
                Text("✕")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(PixelPalette.ink)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(PixelPalette.cream))
                    .overlay(Circle().stroke(PixelPalette.ink, lineWidth: 2.5))
            }

            Spacer()

            VStack(spacing: 2) {
                Text("\(vm.score)")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: PixelPalette.ink, radius: 0, x: 0, y: 3)
                    .contentTransition(.numericText(value: Double(vm.score)))
                    .animation(.snappy(duration: 0.25), value: vm.score)
                if vm.chain >= 2 && !vm.isGameOver {
                    Text("CHAIN ×\(vm.chain)")
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .foregroundStyle(PixelPalette.gold)
                        .shadow(color: PixelPalette.ink, radius: 0, x: 0, y: 2)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.bouncy(duration: 0.25), value: vm.chain)

            Spacer()

            VStack(spacing: 3) {
                Text("NEXT")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(PixelPalette.ink.opacity(0.7))
                TierSprite(tier: vm.upNext, side: 30)
            }
            .frame(width: 52, height: 60)
            .background(RoundedRectangle(cornerRadius: 10).fill(PixelPalette.cream))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(PixelPalette.ink, lineWidth: 2.5))
            .animation(.bouncy(duration: 0.2), value: vm.upNext)
        }
        .padding(.top, 36)
    }

    private var dangerMeter: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(PixelPalette.ink.opacity(0.35))
                Capsule().fill(PixelPalette.danger)
                    .frame(width: max(6, geo.size.width * vm.dangerProgress))
            }
        }
        .frame(height: 7)
        .padding(.horizontal, 36)
        .transition(.opacity)
    }
}

// MARK: - Game over

struct GameOverOverlay: View {
    @ObservedObject var vm: GameViewModel
    let goHome: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            PixelPanel {
                VStack(spacing: 12) {
                    Text("Run Over")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(PixelPalette.ink)

                    Text("\(vm.score)")
                        .font(.system(size: 46, weight: .heavy, design: .rounded))
                        .foregroundStyle(PixelPalette.leaf)

                    if let reward = vm.reward {
                        VStack(spacing: 5) {
                            if reward.isNewBest {
                                Text("★ NEW BEST! ★")
                                    .font(.system(.headline, design: .rounded).weight(.heavy))
                                    .foregroundStyle(PixelPalette.gold)
                            }
                            HStack(spacing: 14) {
                                rewardChip(icon: "icon_coin", text: "+\(reward.coins)")
                                rewardChip(icon: "icon_flame", text: "\(reward.streak.streak) day\(reward.streak.streak == 1 ? "" : "s")")
                            }
                            if reward.streak.usedFreeze {
                                Text("A streak freeze melted to save you ❄")
                                    .font(.system(.caption, design: .rounded).weight(.bold))
                                    .foregroundStyle(PixelPalette.ink.opacity(0.7))
                            }
                            if reward.streak.earnedWeeklyReward {
                                Text("Week complete! +\(GameFeel.day7Coins) coins, +\(GameFeel.day7FreezeReward) freeze")
                                    .font(.system(.caption, design: .rounded).weight(.bold))
                                    .foregroundStyle(PixelPalette.leaf)
                            }
                            if reward.leveledUp {
                                Text("LEVEL UP!")
                                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                                    .foregroundStyle(PixelPalette.gold)
                            }
                        }
                    }

                    if !vm.runDiscoveries.isEmpty {
                        VStack(spacing: 6) {
                            Text("New in the Plantipedia")
                                .font(.system(.caption, design: .rounded).weight(.heavy))
                                .foregroundStyle(PixelPalette.ink.opacity(0.75))
                            HStack(spacing: 10) {
                                ForEach(vm.runDiscoveries) { tier in
                                    VStack(spacing: 2) {
                                        TierSprite(tier: tier, side: 36)
                                        Text(tier.displayName)
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundStyle(PixelPalette.ink)
                                    }
                                }
                            }
                        }
                    }

                    HStack(spacing: 14) {
                        Button("Replay") { vm.restart() }
                            .buttonStyle(PixelButtonStyle())
                        Button("Home") { goHome() }
                            .buttonStyle(PixelButtonStyle(prominent: false))
                    }
                    .padding(.top, 6)
                }
                .frame(maxWidth: 290)
            }
            .padding(28)
        }
    }

    private func rewardChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(icon)
                .resizable().interpolation(.none)
                .frame(width: 18, height: 18)
            Text(text)
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundStyle(PixelPalette.ink)
        }
    }
}
