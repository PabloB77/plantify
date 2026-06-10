import Foundation
import AVFoundation

protocol AudioServicing: AnyObject {
    var isMuted: Bool { get set }
    func playDrop()
    func playMerge(tier: Tier)
    func playGameOver()
}

/// Bundle-driven sound effects with rising pitch on merges: playback rate
/// climbs `GameFeel.mergePitchStep` per tier, so a Great Oak sings a fifth
/// above a Sprout. **Silent no-op until audio files are added** — drop
/// `drop.wav`, `merge.wav`, `gameover.wav` (or .caf/.m4a) into the app
/// bundle and they light up automatically. Nothing crashes without them.
final class AudioService: AudioServicing {

    var isMuted = false

    private var mergePlayers: [AVAudioPlayer] = []
    private var nextMergePlayer = 0
    private var dropPlayer: AVAudioPlayer?
    private var gameOverPlayer: AVAudioPlayer?

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        dropPlayer = makePlayer(named: "drop")
        gameOverPlayer = makePlayer(named: "gameover")
        // Small pool so rapid chains can overlap.
        for _ in 0..<4 {
            if let player = makePlayer(named: "merge", enableRate: true) {
                mergePlayers.append(player)
            }
        }
    }

    private func makePlayer(named name: String, enableRate: Bool = false) -> AVAudioPlayer? {
        for ext in ["wav", "caf", "m4a", "mp3"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext),
               let player = try? AVAudioPlayer(contentsOf: url) {
                player.enableRate = enableRate
                player.prepareToPlay()
                return player
            }
        }
        return nil
    }

    func playDrop() {
        guard !isMuted, let dropPlayer else { return }
        dropPlayer.currentTime = 0
        dropPlayer.play()
    }

    func playMerge(tier: Tier) {
        guard !isMuted, !mergePlayers.isEmpty else { return }
        let player = mergePlayers[nextMergePlayer]
        nextMergePlayer = (nextMergePlayer + 1) % mergePlayers.count
        player.rate = 1.0 + GameFeel.mergePitchStep * Float(tier.rawValue)
        player.currentTime = 0
        player.play()
    }

    func playGameOver() {
        guard !isMuted, let gameOverPlayer else { return }
        gameOverPlayer.currentTime = 0
        gameOverPlayer.play()
    }
}
