import SpriteKit
import UIKit

// MARK: - Plant node

final class PlantNode: SKSpriteNode {
    let tier: Tier
    var isMerging = false
    var birthTime: TimeInterval = -1

    init(tier: Tier, texture: SKTexture) {
        self.tier = tier
        let side = tier.radius * 2
        super.init(texture: texture, color: .clear,
                   size: CGSize(width: side, height: side))
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) unused") }
}

// MARK: - Scene

/// The box. Owns physics, textures and juice; all *rules* are delegated to
/// the `GameSceneBridge` (the view model) so this file stays dumb and pretty.
final class GameScene: SKScene, SKPhysicsContactDelegate {

    weak var bridge: GameSceneBridge?
    var theme: Theme = .day { didSet { applyTheme() } }

    // MARK: Physics categories
    private let plantCategory: UInt32 = 1 << 0
    private let wallCategory: UInt32 = 1 << 1

    // MARK: State
    private var lastTime: TimeInterval = 0
    private var lastDropTime: TimeInterval = -10
    private var boardFrozen = false
    private var built = false
    private var aimX: CGFloat = 0

    // MARK: Nodes
    private var previewNode: SKSpriteNode?
    private var guideNode: SKShapeNode?
    private var dangerLineNode: SKShapeNode?
    private var overlayNode: SKSpriteNode?
    private let camNode = SKCameraNode()

    // MARK: Texture caches
    private var tierTextures: [Tier: SKTexture] = [:]
    private var coinTexture: SKTexture?

    private static let sparkTexture: SKTexture = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }()

    /// Particle tint per tier — warm Stardew-ish swatches.
    private static let tierColors: [SKColor] = [
        SKColor(red: 0.72, green: 0.52, blue: 0.30, alpha: 1), // seed
        SKColor(red: 0.45, green: 0.75, blue: 0.36, alpha: 1), // sprout
        SKColor(red: 0.33, green: 0.66, blue: 0.33, alpha: 1), // clover
        SKColor(red: 0.95, green: 0.45, blue: 0.55, alpha: 1), // tulip
        SKColor(red: 0.88, green: 0.25, blue: 0.32, alpha: 1), // rose
        SKColor(red: 0.99, green: 0.80, blue: 0.25, alpha: 1), // sunflower
        SKColor(red: 0.85, green: 0.40, blue: 0.30, alpha: 1), // mushroom
        SKColor(red: 0.96, green: 0.58, blue: 0.18, alpha: 1), // pumpkin
        SKColor(red: 0.36, green: 0.72, blue: 0.40, alpha: 1), // watermelon
        SKColor(red: 0.20, green: 0.48, blue: 0.32, alpha: 1), // pine
        SKColor(red: 0.55, green: 0.78, blue: 0.35, alpha: 1), // great oak
    ]

    // MARK: Layout

    private var innerLeft: CGFloat { GameFeel.boxSideInset + GameFeel.wallThickness }
    private var innerRight: CGFloat { size.width - innerLeft }
    private var floorTopY: CGFloat { size.height * GameFeel.boxFloorY }
    private var wallTopY: CGFloat { size.height * GameFeel.boxWallTop }
    private var dangerY: CGFloat { size.height * GameFeel.dangerLineRatio }
    private var dropY: CGFloat { size.height * GameFeel.dropYRatio }

    // MARK: Lifecycle

    override func didMove(to view: SKView) {
        guard !built else { return }
        built = true

        physicsWorld.gravity = CGVector(dx: 0, dy: GameFeel.gravity)
        physicsWorld.contactDelegate = self
        backgroundColor = SKColor(red: 0.49, green: 0.75, blue: 0.93, alpha: 1)

        camNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(camNode)
        camera = camNode

        aimX = size.width / 2
        buildBackground()
        buildCrate()
        buildDangerLine()
        buildPreview()
        applyTheme()
    }

    // MARK: Construction

    private func buildBackground() {
        let texture = envTexture(named: "bg_farm",
                                 fallback: SKColor(red: 0.49, green: 0.75, blue: 0.93, alpha: 1))
        let bg = SKSpriteNode(texture: texture)
        // Slightly oversized so camera shake never exposes the void.
        let scale = max(size.width / max(texture.size().width, 1),
                        size.height / max(texture.size().height, 1)) * 1.12
        bg.size = CGSize(width: texture.size().width * scale,
                         height: texture.size().height * scale)
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.zPosition = -100
        addChild(bg)

        let overlay = SKSpriteNode(color: .clear,
                                   size: CGSize(width: size.width * 1.3,
                                                height: size.height * 1.3))
        overlay.position = bg.position
        overlay.zPosition = -90
        addChild(overlay)
        overlayNode = overlay
    }

    private func buildCrate() {
        let crateTexture = envTexture(named: "crate_tile",
                                      fallback: SKColor(red: 0.55, green: 0.36, blue: 0.20, alpha: 1))
        let soilTexture = envTexture(named: "soil_tile",
                                     fallback: SKColor(red: 0.42, green: 0.27, blue: 0.16, alpha: 1))
        let tile = GameFeel.wallThickness

        // Walls: columns of crate tiles.
        for x in [GameFeel.boxSideInset + tile / 2, size.width - GameFeel.boxSideInset - tile / 2] {
            var y = floorTopY - tile / 2
            while y < wallTopY {
                let sprite = SKSpriteNode(texture: crateTexture,
                                          size: CGSize(width: tile, height: tile))
                sprite.position = CGPoint(x: x, y: y + tile / 2)
                sprite.zPosition = 10
                addChild(sprite)
                y += tile
            }
        }

        // Floor: a soil row sitting on a crate row, then solid fill below.
        let floorTile: CGFloat = 22
        var x = GameFeel.boxSideInset + floorTile / 2
        while x < size.width - GameFeel.boxSideInset {
            let soil = SKSpriteNode(texture: soilTexture,
                                    size: CGSize(width: floorTile, height: floorTile))
            soil.position = CGPoint(x: x, y: floorTopY - floorTile / 2)
            soil.zPosition = 10
            addChild(soil)

            let crate = SKSpriteNode(texture: crateTexture,
                                     size: CGSize(width: floorTile, height: floorTile))
            crate.position = CGPoint(x: x, y: floorTopY - floorTile * 1.5)
            crate.zPosition = 10
            addChild(crate)
            x += floorTile
        }

        let fillHeight = max(0, floorTopY - floorTile * 2)
        if fillHeight > 0 {
            let fill = SKSpriteNode(color: SKColor(red: 0.24, green: 0.15, blue: 0.09, alpha: 1),
                                    size: CGSize(width: size.width * 1.3, height: fillHeight + 40))
            fill.position = CGPoint(x: size.width / 2, y: (fillHeight + 40) / 2 - 40)
            fill.zPosition = 9
            addChild(fill)
        }

        // Physics: floor + two tall walls (extended above the visible crate
        // so plants cannot escape sideways while airborne).
        //
        // NOTE: This must be a single edge-chain body. `SKPhysicsBody(bodies:)`
        // only supports volume-based children; compounding edge bodies yields
        // a body with no collision geometry, and plants fall through the crate.
        let containerPath = CGMutablePath()
        containerPath.move(to: CGPoint(x: innerLeft, y: size.height + 200))
        containerPath.addLine(to: CGPoint(x: innerLeft, y: floorTopY))
        containerPath.addLine(to: CGPoint(x: innerRight, y: floorTopY))
        containerPath.addLine(to: CGPoint(x: innerRight, y: size.height + 200))
        let body = SKPhysicsBody(edgeChainFrom: containerPath)
        body.friction = GameFeel.friction
        body.restitution = 0.05
        body.categoryBitMask = wallCategory
        body.collisionBitMask = plantCategory
        physicsBody = body
    }

    private func buildDangerLine() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: innerLeft, y: dangerY))
        path.addLine(to: CGPoint(x: innerRight, y: dangerY))
        let dashed = path.copy(dashingWithPhase: 0, lengths: [10, 8])
        let line = SKShapeNode(path: dashed)
        line.strokeColor = SKColor(red: 0.86, green: 0.28, blue: 0.22, alpha: 1)
        line.lineWidth = 3
        line.lineCap = .square
        line.alpha = 0.35
        line.zPosition = 50
        addChild(line)
        dangerLineNode = line
    }

    private func buildPreview() {
        let tier = currentHeldTier()
        let preview = SKSpriteNode(texture: texture(for: tier),
                                   size: CGSize(width: tier.radius * 2, height: tier.radius * 2))
        preview.position = CGPoint(x: clampX(aimX, radius: tier.radius), y: dropY)
        preview.zPosition = 40
        preview.alpha = 0.95
        addChild(preview)
        previewNode = preview

        let guide = SKShapeNode()
        guide.strokeColor = SKColor(white: 1, alpha: 0.45)
        guide.lineWidth = 2
        guide.zPosition = 39
        addChild(guide)
        guideNode = guide
        layoutAim()
    }

    private func applyTheme() {
        guard let overlayNode else { return }
        let c = theme.skyOverlay
        overlayNode.color = SKColor(red: c.r, green: c.g, blue: c.b, alpha: 1)
        overlayNode.alpha = c.a
        overlayNode.blendMode = .alpha
    }

    // MARK: Textures

    /// Pixel texture for a tier, cached, nearest-filtered. Falls back to a
    /// rendered emoji ONLY if the asset is somehow missing from the bundle.
    private func texture(for tier: Tier) -> SKTexture {
        if let cached = tierTextures[tier] { return cached }
        let texture: SKTexture
        if UIImage(named: tier.assetName) != nil {
            texture = SKTexture(imageNamed: tier.assetName)
        } else {
            texture = SKTexture(image: Self.emojiImage(tier.fallbackEmoji))
        }
        texture.filteringMode = .nearest
        tierTextures[tier] = texture
        return texture
    }

    private func envTexture(named name: String, fallback color: SKColor) -> SKTexture {
        let texture: SKTexture
        if UIImage(named: name) != nil {
            texture = SKTexture(imageNamed: name)
        } else {
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
            let image = renderer.image { ctx in
                color.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
            }
            texture = SKTexture(image: image)
        }
        texture.filteringMode = .nearest
        return texture
    }

    private static func emojiImage(_ emoji: String, side: CGFloat = 128) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { _ in
            let attributed = NSAttributedString(
                string: emoji,
                attributes: [.font: UIFont.systemFont(ofSize: side * 0.78)])
            let bounds = attributed.boundingRect(
                with: CGSize(width: side, height: side),
                options: .usesLineFragmentOrigin, context: nil)
            attributed.draw(at: CGPoint(x: (side - bounds.width) / 2,
                                        y: (side - bounds.height) / 2))
        }
    }

    // MARK: Plants

    private func makePlant(tier: Tier) -> PlantNode {
        let node = PlantNode(tier: tier, texture: texture(for: tier))
        node.zPosition = 20
        return node
    }

    private func attachPhysics(_ node: PlantNode) {
        let body = SKPhysicsBody(circleOfRadius: node.tier.radius * 0.96)
        body.restitution = GameFeel.restitution
        body.friction = GameFeel.friction
        body.linearDamping = GameFeel.linearDamping
        body.angularDamping = GameFeel.angularDamping
        body.density = GameFeel.plantDensity
        body.allowsRotation = true
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = plantCategory
        body.contactTestBitMask = plantCategory
        body.collisionBitMask = plantCategory | wallCategory
        node.physicsBody = body
    }

    private func clampX(_ x: CGFloat, radius: CGFloat) -> CGFloat {
        min(max(x, innerLeft + radius + 2), innerRight - radius - 2)
    }

    private func currentHeldTier() -> Tier {
        guard let bridge else { return .seed }
        return MainActor.assumeIsolated { bridge.bridgeHeldTier() }
    }

    // MARK: Aiming & dropping

    private func layoutAim() {
        guard let previewNode, let guideNode else { return }
        let radius = previewNode.size.width / 2
        let x = clampX(aimX, radius: radius)
        previewNode.position = CGPoint(x: x, y: dropY)

        let path = CGMutablePath()
        path.move(to: CGPoint(x: x, y: dropY - radius - 4))
        path.addLine(to: CGPoint(x: x, y: floorTopY + 4))
        guideNode.path = path.copy(dashingWithPhase: 0, lengths: [6, 8])
    }

    private func refreshPreview() {
        guard let previewNode else { return }
        let tier = currentHeldTier()
        previewNode.texture = texture(for: tier)
        previewNode.size = CGSize(width: tier.radius * 2, height: tier.radius * 2)
        layoutAim()
        previewNode.setScale(0.7)
        previewNode.run(.scale(to: 1, duration: 0.12))
    }

    private func drop() {
        guard !boardFrozen, let bridge else { return }
        guard lastTime - lastDropTime >= GameFeel.dropCooldown else { return }
        lastDropTime = lastTime

        let tier = MainActor.assumeIsolated { bridge.bridgeConsumeDrop() }
        let node = makePlant(tier: tier)
        node.position = CGPoint(x: clampX(aimX, radius: tier.radius), y: dropY)
        node.birthTime = lastTime
        attachPhysics(node)
        // A whisper of stretch on release.
        node.xScale = 2 - GameFeel.dropStretch
        node.yScale = GameFeel.dropStretch
        node.run(.scale(to: 1, duration: 0.12))
        addChild(node)

        MainActor.assumeIsolated { bridge.bridgeDidDrop(tier: tier) }
        refreshPreview()
    }

    // MARK: Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, !boardFrozen else { return }
        aimX = touch.location(in: self).x
        layoutAim()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, !boardFrozen else { return }
        aimX = touch.location(in: self).x
        layoutAim()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        aimX = touch.location(in: self).x
        layoutAim()
        drop()
    }

    // MARK: Contact → merge

    func didBegin(_ contact: SKPhysicsContact) {
        guard !boardFrozen, let bridge else { return }
        guard let a = contact.bodyA.node as? PlantNode,
              let b = contact.bodyB.node as? PlantNode,
              a.tier == b.tier,
              !a.isMerging, !b.isMerging,
              a.parent != nil, b.parent != nil else { return }

        a.isMerging = true
        b.isMerging = true
        a.physicsBody = nil
        b.physicsBody = nil

        let mid = CGPoint(x: (a.position.x + b.position.x) / 2,
                          y: (a.position.y + b.position.y) / 2)
        let sourceTier = a.tier
        let outcome = MainActor.assumeIsolated {
            bridge.bridgeMerge(of: sourceTier, at: self.lastTime)
        }

        let vanish = SKAction.sequence([
            .group([.scale(to: 0.2, duration: 0.07), .fadeOut(withDuration: 0.07)]),
            .removeFromParent(),
        ])
        a.run(vanish)
        b.run(vanish)

        celebrate(outcome: outcome, sourceTier: sourceTier, at: mid)
    }

    private func celebrate(outcome: GameEngine.MergeOutcome,
                           sourceTier: Tier,
                           at mid: CGPoint) {
        let juiceTier = outcome.resultTier ?? sourceTier

        if let result = outcome.resultTier {
            let node = makePlant(tier: result)
            let safeMid = CGPoint(x: clampX(mid.x, radius: result.radius),
                                  y: max(mid.y, floorTopY + result.radius + 1))
            node.position = safeMid
            node.birthTime = lastTime
            attachPhysics(node)
            node.setScale(GameFeel.spawnSquash)
            let pop = SKAction.scale(to: GameFeel.spawnOvershoot,
                                     duration: GameFeel.squashDuration * 0.6)
            pop.timingMode = .easeOut
            let settle = SKAction.scale(to: 1.0,
                                        duration: GameFeel.squashDuration * 0.4)
            settle.timingMode = .easeIn
            node.run(.sequence([pop, settle]))
            addChild(node)
        }

        burst(at: mid, tier: juiceTier, doubled: outcome.resultTier == nil)
        flashRing(at: mid, tier: juiceTier)
        shake(forTier: juiceTier)
        floatScore(outcome.pointsAwarded, chain: outcome.chainCount, at: mid)
        if juiceTier >= GameFeel.coinFlyTierThreshold {
            coinFly(from: mid, tier: juiceTier)
        }
    }

    // MARK: Juice

    private func burst(at point: CGPoint, tier: Tier, doubled: Bool) {
        let emitter = SKEmitterNode()
        emitter.particleTexture = Self.sparkTexture
        var count = GameFeel.particleBase + GameFeel.particlePerTier * tier.rawValue
        if doubled { count *= 3 }   // two Great Oaks deserve fireworks
        emitter.numParticlesToEmit = count
        emitter.particleBirthRate = 800
        emitter.particleLifetime = 0.55
        emitter.particleLifetimeRange = 0.25
        emitter.particleSpeed = 80 + 12 * CGFloat(tier.rawValue)
        emitter.particleSpeedRange = 60
        emitter.emissionAngleRange = .pi * 2
        emitter.particleAlpha = 1
        emitter.particleAlphaSpeed = -1.8
        emitter.particleScale = 2.2
        emitter.particleScaleRange = 1.0
        emitter.particleScaleSpeed = -1.6
        emitter.yAcceleration = -180
        emitter.particleColor = Self.tierColors[min(tier.rawValue, Self.tierColors.count - 1)]
        emitter.particleColorBlendFactor = 1
        emitter.position = point
        emitter.zPosition = 30
        addChild(emitter)
        emitter.run(.sequence([.wait(forDuration: 1.0), .removeFromParent()]))
    }

    private func flashRing(at point: CGPoint, tier: Tier) {
        let ring = SKShapeNode(circleOfRadius: tier.radius)
        ring.strokeColor = .white
        ring.lineWidth = 4
        ring.fillColor = .clear
        ring.alpha = GameFeel.mergeFlashAlpha
        ring.position = point
        ring.zPosition = 35
        addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 1.9, duration: 0.22), .fadeOut(withDuration: 0.22)]),
            .removeFromParent(),
        ]))
    }

    private func shake(forTier tier: Tier) {
        let amplitude = GameFeel.shakeBase + GameFeel.shakePerTier * CGFloat(tier.rawValue)
        var actions: [SKAction] = []
        var remaining = amplitude
        let steps = 5
        let stepDuration = GameFeel.shakeDuration / Double(steps * 2)
        for _ in 0..<steps {
            let dx = CGFloat.random(in: -remaining...remaining)
            let dy = CGFloat.random(in: -remaining...remaining)
            actions.append(.moveBy(x: dx, y: dy, duration: stepDuration))
            actions.append(.moveBy(x: -dx, y: -dy, duration: stepDuration))
            remaining *= 0.6
        }
        camNode.removeAction(forKey: "shake")
        camNode.run(.sequence(actions), withKey: "shake")
    }

    private func floatScore(_ points: Int, chain: Int, at point: CGPoint) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = chain >= 2 ? "+\(points) ×\(chain)" : "+\(points)"
        label.fontSize = chain >= 2 ? 22 : 17
        label.fontColor = chain >= 2
            ? SKColor(red: 1.0, green: 0.85, blue: 0.30, alpha: 1)
            : .white
        label.position = CGPoint(x: point.x, y: point.y + 18)
        label.zPosition = 55
        label.setScale(0.4)
        addChild(label)
        let rise = SKAction.moveBy(x: 0, y: 46, duration: 0.7)
        rise.timingMode = .easeOut
        label.run(.group([rise,
                          .scale(to: 1, duration: 0.12),
                          .sequence([.wait(forDuration: 0.4),
                                     .fadeOut(withDuration: 0.3)])]))
        label.run(.sequence([.wait(forDuration: 0.75), .removeFromParent()]))
    }

    private func coinFly(from point: CGPoint, tier: Tier) {
        if coinTexture == nil {
            coinTexture = envTexture(named: "icon_coin",
                                     fallback: SKColor(red: 0.98, green: 0.80, blue: 0.20, alpha: 1))
        }
        guard let coinTexture else { return }
        let target = CGPoint(x: 48, y: size.height - 70)
        let count = 3 + tier.rawValue / 3
        for index in 0..<count {
            let coin = SKSpriteNode(texture: coinTexture,
                                    size: CGSize(width: 22, height: 22))
            coin.position = point
            coin.zPosition = 60
            addChild(coin)
            let scatter = SKAction.moveBy(x: .random(in: -55...55),
                                          y: .random(in: 24...74),
                                          duration: 0.18)
            scatter.timingMode = .easeOut
            let swoop = SKAction.move(to: target, duration: 0.4)
            swoop.timingMode = .easeIn
            coin.run(.sequence([
                .wait(forDuration: 0.045 * Double(index)),
                scatter,
                swoop,
                .group([.scale(to: 0.4, duration: 0.1), .fadeOut(withDuration: 0.1)]),
                .removeFromParent(),
            ]))
        }
    }

    // MARK: Frame update — danger line

    override func update(_ currentTime: TimeInterval) {
        lastTime = currentTime
        guard built, !boardFrozen, let bridge else { return }

        var anyAbove = false
        for case let plant as PlantNode in children {
            guard plant.physicsBody != nil, !plant.isMerging else { continue }
            guard plant.birthTime >= 0,
                  currentTime - plant.birthTime > GameFeel.dangerIgnoreAge else { continue }
            if plant.position.y + plant.tier.radius > dangerY {
                anyAbove = true
                break
            }
        }

        let result = MainActor.assumeIsolated {
            bridge.bridgeDanger(anyPlantAboveLine: anyAbove, at: currentTime)
        }
        updateDangerVisual(progress: result.progress)
        if result.isGameOver { freezeBoard() }
    }

    private func updateDangerVisual(progress: Double) {
        guard let dangerLineNode else { return }
        dangerLineNode.alpha = 0.35 + 0.65 * progress
        dangerLineNode.lineWidth = 3 + 3 * progress
    }

    private func freezeBoard() {
        guard !boardFrozen else { return }
        boardFrozen = true
        physicsWorld.speed = 0
        previewNode?.isHidden = true
        guideNode?.isHidden = true
        shake(forTier: .greatOak)
    }

    // MARK: Restart

    func resetBoard() {
        for case let plant as PlantNode in children {
            plant.removeAllActions()
            plant.removeFromParent()
        }
        physicsWorld.speed = 1
        boardFrozen = false
        lastDropTime = -10
        previewNode?.isHidden = false
        guideNode?.isHidden = false
        updateDangerVisual(progress: 0)
        refreshPreview()
    }
}
