import Foundation
import CoreHaptics
import UIKit

protocol HapticsServicing: AnyObject {
    func prepare()
    func dropTap()
    func mergePop(tier: Tier)
    func chainSwell(chain: Int)
    func gameOverThud()
}

/// CoreHaptics pops that hit harder and *rounder* as tiers grow (intensity
/// climbs, sharpness falls), with a low rumble tail on big plants and a
/// swelling pattern for chains. Falls back to UIFeedbackGenerator when
/// CoreHaptics is unavailable (old devices, simulator).
final class HapticsService: HapticsServicing {

    private var engine: CHHapticEngine?
    private let lightFallback = UIImpactFeedbackGenerator(style: .light)
    private let mediumFallback = UIImpactFeedbackGenerator(style: .medium)
    private let heavyFallback = UIImpactFeedbackGenerator(style: .heavy)
    private let notifyFallback = UINotificationFeedbackGenerator()

    func prepare() {
        lightFallback.prepare()
        mediumFallback.prepare()
        heavyFallback.prepare()
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            engine.resetHandler = { [weak self] in try? self?.engine?.start() }
            engine.stoppedHandler = { _ in }
            try engine.start()
            self.engine = engine
        } catch {
            engine = nil
        }
    }

    func dropTap() {
        play(events: [transient(time: 0, intensity: 0.32, sharpness: 0.9)]) {
            self.lightFallback.impactOccurred(intensity: 0.5)
        }
    }

    func mergePop(tier: Tier) {
        let t = Float(tier.rawValue)
        let intensity = min(1, GameFeel.hapticBaseIntensity + GameFeel.hapticIntensityPerTier * t)
        let sharpness = max(0.05, GameFeel.hapticBaseSharpness + GameFeel.hapticSharpnessPerTier * t)
        var events = [transient(time: 0, intensity: intensity, sharpness: sharpness)]
        if tier >= GameFeel.hapticBigTierRumble {
            // Round decaying rumble under the pop for the big boys.
            events.append(continuous(time: 0.01,
                                     duration: 0.12 + 0.02 * Double(t),
                                     intensity: intensity * 0.55,
                                     sharpness: 0.12))
        }
        play(events: events) {
            switch tier.rawValue {
            case ..<4: self.lightFallback.impactOccurred(intensity: CGFloat(intensity))
            case ..<8: self.mediumFallback.impactOccurred(intensity: CGFloat(intensity))
            default: self.heavyFallback.impactOccurred(intensity: CGFloat(intensity))
            }
        }
    }

    func chainSwell(chain: Int) {
        guard chain >= 2 else { return }
        let steps = min(chain, 5)
        var events: [CHHapticEvent] = []
        for step in 0..<steps {
            let intensity = min(1, 0.35 + GameFeel.chainSwellStep * Float(step))
            events.append(transient(time: 0.05 * Double(step),
                                    intensity: intensity,
                                    sharpness: 0.5))
        }
        play(events: events) {
            self.mediumFallback.impactOccurred(intensity: min(1, 0.5 + 0.1 * CGFloat(chain)))
        }
    }

    func gameOverThud() {
        play(events: [
            transient(time: 0, intensity: 1.0, sharpness: 0.25),
            continuous(time: 0.02, duration: 0.35, intensity: 0.5, sharpness: 0.08),
        ]) {
            self.notifyFallback.notificationOccurred(.error)
        }
    }

    // MARK: Plumbing

    private func transient(time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: time)
    }

    private func continuous(time: TimeInterval, duration: TimeInterval,
                            intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: time, duration: duration)
    }

    private func play(events: [CHHapticEvent], fallback: @escaping () -> Void) {
        guard let engine else { fallback(); return }
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            fallback()
        }
    }
}

/// No-op implementation for tests/previews.
final class SilentHaptics: HapticsServicing {
    func prepare() {}
    func dropTap() {}
    func mergePop(tier: Tier) {}
    func chainSwell(chain: Int) {}
    func gameOverThud() {}
}
