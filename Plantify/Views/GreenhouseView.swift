import SwiftUI
import SwiftData

/// The Plantipedia: every tier in the chain, unlocked by growing it at least
/// once. Undiscovered plants show as darkened silhouettes with a "?".
struct GreenhouseView: View {
    @Query private var records: [DiscoveryRecord]

    private var discovered: Set<Tier> {
        Set(records.compactMap(\.tier)).union([.seed])
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            FarmBackdrop()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    Text("Plantipedia")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: PixelPalette.ink, radius: 0, x: 0, y: 3)
                        .padding(.top, 12)

                    Text("\(discovered.count)/\(Tier.allCases.count) grown")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(.white.opacity(0.92))
                        .shadow(color: PixelPalette.ink.opacity(0.8), radius: 0, x: 0, y: 2)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Tier.allCases) { tier in
                            PlantipediaTile(tier: tier,
                                            isDiscovered: discovered.contains(tier))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

struct PlantipediaTile: View {
    let tier: Tier
    let isDiscovered: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                TierSprite(tier: tier, side: 58, silhouette: !isDiscovered)
                if !isDiscovered {
                    Text("?")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            Text(isDiscovered ? tier.displayName : "???")
                .font(.system(.caption, design: .rounded).weight(.heavy))
                .foregroundStyle(PixelPalette.ink)
            Text(isDiscovered ? tier.lore : "Grow it to find out.")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(PixelPalette.ink.opacity(0.65))
                .multilineTextAlignment(.center)
                .frame(minHeight: 38, alignment: .top)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(PixelPalette.cream.opacity(isDiscovered ? 1 : 0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(PixelPalette.ink, lineWidth: 2.5)
        )
    }
}
