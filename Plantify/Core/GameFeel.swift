import Foundation
import CoreGraphics

/// Every game-feel tuning constant in one place. Twist these knobs, rebuild,
/// and the whole game changes character. Group order: physics → sizes →
/// rules → drop curve → juice → haptics → audio → economy → layout.
enum GameFeel {

    // MARK: Physics — weighty but readable
    static let gravity: CGFloat = -6.8          // dy; Suika-ish floaty weight
    static let restitution: CGFloat = 0.18      // low bounce = readable stacks
    static let friction: CGFloat = 0.45
    static let linearDamping: CGFloat = 0.30
    static let angularDamping: CGFloat = 0.55
    static let plantDensity: CGFloat = 1.15

    // MARK: Sizes
    static let baseRadius: CGFloat = 15         // seed radius (scene pts)
    static let radiusGrowth: CGFloat = 1.27     // exponential growth per tier
    static let droppableTierCount = 5           // seed…rose droppable

    // MARK: Core rules
    static let chainWindow: TimeInterval = 2.0  // merges inside this window chain
    static let dangerSeconds: TimeInterval = 2.0
    static let dangerIgnoreAge: TimeInterval = 0.6 // fresh drops cannot trigger danger
    static let dropCooldown: TimeInterval = 0.35

    // MARK: Drop generator honeymoon curve
    static let honeymoonPhase1 = 8              // drops 0..<8: seeds & sprouts
    static let honeymoonPhase2 = 20             // drops 8..<20: three tiers
    static let phase1Weights: [Double] = [0.70, 0.30]
    static let phase2Weights: [Double] = [0.45, 0.35, 0.20]
    static let steadyWeights: [Double] = [0.30, 0.26, 0.20, 0.14, 0.10]

    // MARK: Juice — squash, shake, particles, coin arcs
    static let spawnSquash: CGFloat = 0.62      // merge-born plants pop in from this
    static let spawnOvershoot: CGFloat = 1.16
    static let squashDuration: TimeInterval = 0.17
    static let dropStretch: CGFloat = 1.08
    static let shakeBase: CGFloat = 1.0         // pts of camera shake at tier 0
    static let shakePerTier: CGFloat = 1.1
    static let shakeDuration: TimeInterval = 0.20
    static let particleBase = 10
    static let particlePerTier = 5
    static let coinFlyTierThreshold = Tier.sunflower
    static let mergeFlashAlpha: CGFloat = 0.55

    // MARK: Haptics — pops hit harder & rounder as tiers grow
    static let hapticBaseIntensity: Float = 0.42
    static let hapticIntensityPerTier: Float = 0.055
    static let hapticBaseSharpness: Float = 0.72
    static let hapticSharpnessPerTier: Float = -0.055  // rounder when bigger
    static let hapticBigTierRumble = Tier.mushroom      // adds decay rumble from here
    static let chainSwellStep: Float = 0.12

    // MARK: Audio
    static let mergePitchStep: Float = 0.07     // playback-rate bump per tier

    // MARK: Economy & progression
    static let coinsPerScoreDivisor = 25        // run coins = score / this
    static let discoveryCoinBonus = 15
    static let xpPerMerge = 4
    static let xpPerScoreDivisor = 10
    static let freezeCost = 150
    static let day7FreezeReward = 1
    static let day7Coins = 60
    static let maxOakBonusMultiplier = 4        // two Great Oaks pop bonus

    // MARK: Box layout (fractions of scene size unless noted)
    static let boxSideInset: CGFloat = 12       // pts
    static let boxFloorY: CGFloat = 0.16
    static let boxWallTop: CGFloat = 0.80
    static let dangerLineRatio: CGFloat = 0.74
    static let dropYRatio: CGFloat = 0.875
    static let wallThickness: CGFloat = 14      // pts
}
