import Foundation

/// Injectable uniform random source so drop sequences are fully testable.
protocol RandomSource {
    /// Uniform value in [0, 1).
    mutating func nextUniform() -> Double
}

/// Deterministic SplitMix64 — tiny, fast, well distributed game RNG.
struct SeededRandomSource: RandomSource {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func nextUniform() -> Double {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z ^= z >> 31
        return Double(z >> 11) * (1.0 / 9007199254740992.0)
    }
}

struct SystemRandomSource: RandomSource {
    mutating func nextUniform() -> Double { Double.random(in: 0..<1) }
}

/// Decides which plant the player is handed next. Early drops are gentle
/// (the "honeymoon" curve) and difficulty widens as the run matures.
struct DropGenerator {
    private var rng: RandomSource
    private(set) var dropsIssued = 0

    init(rng: RandomSource = SystemRandomSource()) {
        self.rng = rng
    }

    /// Weight table over the droppable tiers for the i-th drop of a run.
    static func weights(forDropIndex index: Int) -> [Double] {
        if index < GameFeel.honeymoonPhase1 { return GameFeel.phase1Weights }
        if index < GameFeel.honeymoonPhase2 { return GameFeel.phase2Weights }
        return GameFeel.steadyWeights
    }

    mutating func nextTier() -> Tier {
        let weights = Self.weights(forDropIndex: dropsIssued)
        dropsIssued += 1
        let total = weights.reduce(0, +)
        var roll = rng.nextUniform() * total
        for (index, weight) in weights.enumerated() {
            roll -= weight
            if roll < 0 { return Tier(rawValue: index) ?? .seed }
        }
        return Tier(rawValue: weights.count - 1) ?? .seed
    }

    mutating func reset() { dropsIssued = 0 }
}
