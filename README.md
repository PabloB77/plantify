# 🌱 Plantify

A cozy, Stardew-Valley-styled **Suika-like merge game** for iOS. Drop plants
into a wooden crate; matching plants fuse into the next, bigger plant. Chain
merges for multipliers, grow the Great Oak, keep your daily streak alive, and
fill out the Plantipedia.

Built with **SwiftUI + SpriteKit + SwiftData**, iOS 17+, portrait iPhone.

---

## Getting started

```bash
brew install xcodegen        # if you don't have it
cd Plantify
xcodegen generate
open Plantify.xcodeproj
```

Pick an iPhone simulator and hit **Run**. No third-party dependencies, no
signing required for the simulator. Unit tests live in the `PlantifyTests`
target (`Cmd-U`).

> **Note on signing for device builds:** Game Center requires a real bundle ID
> and the Game Center capability in App Store Connect. The code is fully
> defensive — without entitlements or network it silently no-ops and the game
> plays normally.

---

## Architecture

```
Plantify/
├── Core/          Tier.swift (the 11 plants) · GameFeel.swift (ALL tuning)
├── Engine/        Pure logic, no UIKit/SpriteKit — fully unit tested
│   ├── GameEngine.swift      scoring, chains, discoveries, danger timer
│   └── DropGenerator.swift   weighted drops + honeymoon curve, seeded RNG
├── Models/        SwiftData @Models (profile, discoveries, missions) + Theme
├── Services/      Persistence · Economy · Missions · Haptics · Audio
│                  GameCenter · Notifications · Store (tip jar)
├── App/           AppServices (composition root) · PlantifyApp (@main)
├── ViewModels/    GameViewModel — bridges the scene to engine + services
├── Scene/         GameScene.swift — SpriteKit physics, juice, particles
└── Views/         SwiftUI: Home · Game container/HUD · Greenhouse · Settings
                   PixelUI.swift — 9-slice pixel panels & buttons
```

**MVVM with a hard purity boundary.** `GameEngine` and `DropGenerator` import
only Foundation. The SpriteKit scene never touches game rules — it reports
contacts to the `GameSceneBridge` protocol (implemented by `GameViewModel`),
which consults the engine and tells services what happened. That's why the
entire rule set is unit-testable without a simulator.

**SwiftData with self-healing.** `PersistenceService.makeContainer` tries to
open the store; on failure it deletes the store files and retries, and as a
last resort falls back to an in-memory container. The app never crashes on a
bad migration.

**Dependency injection.** `AppServices.live()` wires everything once;
`AppServices.preview()` gives an in-memory variant for SwiftUI previews and
tests.

---

## Tuning the feel — `Core/GameFeel.swift`

Every gameplay/juice constant lives in **one file**. Highlights:

| Constant | What it does |
|---|---|
| `gravity`, `restitution`, `plantDensity` | overall physics weight |
| `baseRadius`, `radiusGrowth` | tier size curve (exponential) |
| `chainWindow` | seconds between merges that still count as a chain |
| `dangerSeconds`, `dangerLineRatio` | how forgiving the loss condition is |
| `honeymoonPhase1/2`, `*Weights` | early-run drop generosity curve |
| `spawnSquash`, `spawnOvershoot` | merge pop squash-and-stretch |
| `shakeBase`, `shakePerTier` | camera shake scaling |
| `hapticBaseIntensity`, `hapticIntensityPerTier` | merge haptic curve |
| `mergePitchStep` | per-tier pitch rise on merge sounds |
| `coinsPerScoreDivisor`, `xpPerMerge`, `freezeCost` | economy knobs |

Change a number, rerun, feel the difference. Nothing else needs touching.

---

## Art

**All artwork is original, generated programmatically** by
`Tools/generate_sprites.py` (Python + Pillow): 11 plant sprites drawn on a
32/48-px pixel grid with a warm, earthy, Stardew-inspired palette and chunky
outlines, then nearest-neighbor upscaled into `Assets.xcassets`. UI panels and
buttons are 9-sliced pixel art; the crate, soil, sky and farm backdrop are
generated tiles.

*Sourcing note:* per the original brief, CC0 packs were investigated first —
OpenGameArt's "Farming crops 16x16" (josehzz, CC0) was identified as a strong
candidate, but the build sandbox could not reach a verifiable mirror to
download and license-check the files. Everything shipped here is therefore
generated in-repo, **no attribution required**. To regenerate or restyle:

```bash
cd Tools && python3 generate_sprites.py
```

### Audio (optional drop-in)

The game is silent until you add files — `AudioService` no-ops gracefully.
Drop any of `drop`, `merge`, `gameover` (`.wav`, `.caf`, `.m4a`, or `.mp3`)
into the app bundle and they're picked up automatically. Merge sounds rise in
pitch with tier via `GameFeel.mergePitchStep`.

---

## Meta systems

- **Streak** — one play a day keeps it alive; a missed day auto-consumes a
  Streak Freeze if you own one. Every 7th day grants a freeze + coins.
- **Missions** — 3 deterministic dailies (seeded by the date, same for
  everyone) + a seasonal mission. Claim coins on the home screen.
- **Economy** — coins buy cosmetics (sky themes) and freezes only. No timers,
  no gates, no dark patterns. Restart is always instant.
- **Plantipedia** — Greenhouse screen; undiscovered tiers show as silhouettes.
- **Game Center** — leaderboard `plantify.highscores`, achievements
  `plantify.grow.tier_NN` per discovery.
- **Notifications** — strictly opt-in, max one gentle reminder per day (18:30).
- **Tip jar** — StoreKit 2, products `com.plantify.supporter.*`. Pure
  gratitude; unlocks only a badge.

---

## How to add a 12th tier (end-to-end)

Say you want **Golden Tree** after Great Oak:

1. **`Core/Tier.swift`** — add `case goldenTree` after `greatOak`, plus its
   `displayName`, `lore`, and `fallbackEmoji` entries. `next`, `points`,
   `radius`, and `assetName` (`tier_11`) all derive automatically. Decide
   whether `greatOak` should now merge into it (it will, automatically, since
   `next` returns the following case — remove the special oak-pop branch in
   `GameEngine.registerMerge` if you want oak→tree instead of the oak bonus).
2. **`Tools/generate_sprites.py`** — add a `draw_golden_tree(px)` function,
   register it in the tier list, rerun the script.
3. **`Assets.xcassets`** — create `tier_11.imageset` with the new PNG
   (copy any existing tier imageset's `Contents.json` and rename).
4. **`Scene/GameScene.swift`** — append one color to `tierColors` (particle
   tint).
5. Done. Physics radius, scoring, Plantipedia entry, missions eligibility,
   haptic/pitch curves, and the Game Center achievement
   (`plantify.grow.tier_11`) all key off the enum automatically. Register the
   new achievement ID in App Store Connect when you ship.

---

## Testing

- `GameEngineTests` — merge results, chain windows & multipliers, discovery
  bookkeeping, oak bonus, danger-line grace/recovery, reset semantics.
- `EconomyServiceTests` — streak math (incl. freezes & weekly rewards) with a
  controllable clock, spend/award, XP/levels, run settlement, themes.
- `DropGeneratorTests` — seeded determinism, honeymoon curve, droppability.
# plantify
