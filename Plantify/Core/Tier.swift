import Foundation
import CoreGraphics

/// The 11-step Plantify merge chain. Raw values are ordered, contiguous,
/// and double as asset indices (`tier_00` … `tier_10`).
enum Tier: Int, CaseIterable, Codable, Identifiable, Comparable {
    case seed, sprout, clover, tulip, rose, sunflower,
         mushroom, pumpkin, watermelon, pine, greatOak

    var id: Int { rawValue }

    static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }

    /// The tier produced when two of `self` merge. `nil` at the top of the
    /// chain — two Great Oaks pop for a bonus instead.
    var next: Tier? { Tier(rawValue: rawValue + 1) }

    /// Only the smallest tiers can be dropped; the rest must be grown.
    var isDroppable: Bool { rawValue < GameFeel.droppableTierCount }

    /// Physics/display radius in scene points, exponential like Suika.
    var radius: CGFloat {
        GameFeel.baseRadius * pow(GameFeel.radiusGrowth, CGFloat(rawValue))
    }

    /// Base score for *creating* this tier (triangular numbers, Suika-style).
    var points: Int { (rawValue + 1) * (rawValue + 2) / 2 }

    var assetName: String { String(format: "tier_%02d", rawValue) }

    var displayName: String {
        switch self {
        case .seed: "Seed"
        case .sprout: "Sprout"
        case .clover: "Clover"
        case .tulip: "Tulip"
        case .rose: "Rose"
        case .sunflower: "Sunflower"
        case .mushroom: "Mushroom"
        case .pumpkin: "Pumpkin"
        case .watermelon: "Watermelon"
        case .pine: "Pine"
        case .greatOak: "Great Oak"
        }
    }

    /// Plantipedia flavor text.
    var lore: String {
        switch self {
        case .seed: "Every forest starts somewhere. Usually here."
        case .sprout: "Two seeds agreed on a direction: up."
        case .clover: "Carries a little luck. You will need it above the line."
        case .tulip: "Stands tall, blushes easily."
        case .rose: "Beautiful, and entirely aware of it."
        case .sunflower: "Tracks the sun. Judges your aim."
        case .mushroom: "Not technically a plant. Do not tell it."
        case .pumpkin: "Heavy enough to rearrange the whole box."
        case .watermelon: "98% water, 2% chaos."
        case .pine: "Smells like victory and a little like winter."
        case .greatOak: "The whole journey, ring by ring. Merge two for legend."
        }
    }

    /// Emoji safety-net used only if a texture is somehow missing from the
    /// bundle. Real pixel art always wins.
    var fallbackEmoji: String {
        switch self {
        case .seed: "🌰"
        case .sprout: "🌱"
        case .clover: "🍀"
        case .tulip: "🌷"
        case .rose: "🌹"
        case .sunflower: "🌻"
        case .mushroom: "🍄"
        case .pumpkin: "🎃"
        case .watermelon: "🍉"
        case .pine: "🌲"
        case .greatOak: "🌳"
        }
    }
}
