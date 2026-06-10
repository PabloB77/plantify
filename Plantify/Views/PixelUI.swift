import SwiftUI

// MARK: - Pixel panel (9-slice stretched wooden panel art)

struct PixelPanel<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(
                Image("panel")
                    .resizable(capInsets: EdgeInsets(top: 18, leading: 18,
                                                     bottom: 18, trailing: 18),
                               resizingMode: .stretch)
                    .interpolation(.none)
            )
    }
}

// MARK: - Pixel button

struct PixelButtonStyle: ButtonStyle {
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.heavy))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.45), radius: 0, x: 0, y: 2)
            .padding(.horizontal, prominent ? 26 : 16)
            .padding(.vertical, prominent ? 14 : 9)
            .background(
                Image("button")
                    .resizable(capInsets: EdgeInsets(top: 12, leading: 12,
                                                     bottom: 12, trailing: 12),
                               resizingMode: .stretch)
                    .interpolation(.none)
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.55),
                       value: configuration.isPressed)
    }
}

// MARK: - Stat chip (coins / streak / freezes)

struct StatChip: View {
    let icon: String        // imageset name
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(icon)
                .resizable()
                .interpolation(.none)
                .frame(width: 20, height: 20)
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundStyle(Color(red: 0.27, green: 0.16, blue: 0.07))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color(red: 0.96, green: 0.93, blue: 0.84))
        )
        .overlay(
            Capsule().stroke(Color(red: 0.27, green: 0.16, blue: 0.07), lineWidth: 2.5)
        )
    }
}

// MARK: - Pixel sprite image helper

struct TierSprite: View {
    let tier: Tier
    var side: CGFloat = 44
    var silhouette = false

    var body: some View {
        Image(tier.assetName)
            .resizable()
            .interpolation(.none)
            .colorMultiply(silhouette ? Color.black.opacity(0.92) : .white)
            .opacity(silhouette ? 0.55 : 1)
            .frame(width: side, height: side)
    }
}

// MARK: - Shared palette

enum PixelPalette {
    static let ink = Color(red: 0.27, green: 0.16, blue: 0.07)
    static let cream = Color(red: 0.96, green: 0.93, blue: 0.84)
    static let danger = Color(red: 0.86, green: 0.28, blue: 0.22)
    static let gold = Color(red: 0.98, green: 0.78, blue: 0.22)
    static let leaf = Color(red: 0.30, green: 0.58, blue: 0.30)
}
