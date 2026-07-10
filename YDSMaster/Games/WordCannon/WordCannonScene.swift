import SpriteKit

/// Word Cannon: the current word is loaded into a cannon at the bottom.
/// Meaning shields hang from a chain across the top — drag anywhere to aim
/// (live dotted trajectory), release to fire. Hit the right shield to shatter
/// it. Validation happens outside (GameSession).
final class WordCannonScene: SKScene, SKPhysicsContactDelegate {

    // MARK: Callbacks to SwiftUI

    /// Called when the fired ball hits a shield. Parameter is the shield's option text.
    var onBallHitShield: ((String) -> Void)?

    // MARK: Config

    var movingShields = false
    var comboLevel: Int = 0

    private enum Category {
        static let ball: UInt32 = 1 << 0
        static let shield: UInt32 = 1 << 1
        static let wall: UInt32 = 1 << 2
    }

    // MARK: State

    private var shieldNodes: [SKShapeNode] = []
    private var chainNode: SKNode?
    private var barrel: SKNode?
    private var ballNode: SKShapeNode?
    private var trajectoryNode: SKShapeNode?

    /// How the cannon is drawn, which determines pivot and rotation math.
    private enum CannonArtMode {
        case vector          // code-drawn, barrel points along the aim angle
        case fullImage       // single art image drawn at ~20°, whole cannon tilts
        case twoPart         // art carriage stays planted, up-pointing barrel swivels
    }

    private var cannonArtMode: CannonArtMode = .vector
    private var aiming = false
    private var aimAngle: CGFloat = .pi / 2
    private var resolving = false
    private var flying = false
    private var currentPrompt = ""

    private let ballRadius: CGFloat = 35
    private let barrelLength: CGFloat = 108
    private let fireSpeed: CGFloat = 1150
    /// Angle the single-image cannon art is drawn at (measured from the asset).
    private static let fullCannonArtAngle: CGFloat = 0.35

    // Cartoon cannon palette (mockup: blue body, orange wheels, dark outlines)
    private let cannonBlue = SKColor(red: 0.18, green: 0.47, blue: 0.86, alpha: 1)
    private let cannonBlueDark = SKColor(red: 0.10, green: 0.30, blue: 0.60, alpha: 1)
    private let cannonOrange = SKColor(red: 0.96, green: 0.55, blue: 0.14, alpha: 1)
    private let outline = SKColor(red: 0.05, green: 0.09, blue: 0.18, alpha: 1)

    private var cannonPosition: CGPoint {
        // Two-part mortar sits bottom-center so it swivels left/right
        // symmetrically toward all shields; other styles sit off-center.
        let xFraction: CGFloat = cannonArtMode == .twoPart ? 0.5 : 0.32
        return CGPoint(x: size.width * xFraction, y: 168)
    }

    // MARK: Setup

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        physicsWorld.gravity = CGVector(dx: 0, dy: -3.0)
        physicsWorld.contactDelegate = self
        let border = SKPhysicsBody(edgeLoopFrom: CGRect(x: -60, y: -200, width: size.width + 120, height: size.height + 400))
        border.categoryBitMask = Category.wall
        border.friction = 0
        physicsBody = border
    }

    // MARK: Question lifecycle

    func loadQuestion(prompt: String, options: [String], golden: Bool) {
        resolving = false
        flying = false
        aiming = false
        currentPrompt = prompt
        removeAllChildren()
        shieldNodes = []

        buildChainAndShields(options: options, golden: golden)
        buildCannon()
        loadBall()
    }

    private func buildChainAndShields(options: [String], golden: Bool) {
        let chain = SKNode()
        let chainY = size.height * 0.80

        // Chain of oval links across the screen
        let linkColor = SKColor(red: 0.52, green: 0.56, blue: 0.66, alpha: 0.9)
        var linkX: CGFloat = -20
        var linkIndex = 0
        while linkX < size.width + 20 {
            let vertical = linkIndex.isMultiple(of: 2)
            let link = SKShapeNode(ellipseOf: vertical ? CGSize(width: 9, height: 16) : CGSize(width: 16, height: 9))
            link.strokeColor = linkColor
            link.lineWidth = 3
            link.position = CGPoint(x: linkX, y: chainY)
            chain.addChild(link)
            linkX += 12
            linkIndex += 1
        }

        let count = options.count
        let spacing = size.width / CGFloat(count + 1)
        for (i, option) in options.enumerated() {
            let x = spacing * CGFloat(i + 1)

            // Hanger: two small links down to the shield
            for j in 0..<2 {
                let link = SKShapeNode(ellipseOf: CGSize(width: 8, height: 14))
                link.strokeColor = linkColor
                link.lineWidth = 3
                link.position = CGPoint(x: x, y: chainY - 10 - CGFloat(j) * 12)
                chain.addChild(link)
            }

            let shield = makeShield(text: option, golden: golden)
            shield.position = CGPoint(x: x, y: chainY - 26 - shieldSize.height / 2)
            chain.addChild(shield)
            shieldNodes.append(shield)

            // Drop-in entrance
            shield.setScale(0.1)
            shield.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.06 * Double(i)),
                SKAction.scale(to: 1.08, duration: 0.16),
                SKAction.scale(to: 1.0, duration: 0.1),
            ]))
        }

        addChild(chain)
        chainNode = chain

        if movingShields {
            let range = size.width * 0.06
            let sway = SKAction.sequence([
                SKAction.moveBy(x: range, y: 0, duration: 1.4),
                SKAction.moveBy(x: -2 * range, y: 0, duration: 2.8),
                SKAction.moveBy(x: range, y: 0, duration: 1.4),
            ])
            sway.timingMode = .easeInEaseOut
            chain.run(SKAction.repeatForever(sway), withKey: "sway")
        }
    }

    private var shieldSize: CGSize { CGSize(width: 106, height: 96) }

    /// Heater-shield outline: flat top, tapering to a point at the bottom.
    private func makeShield(text: String, golden: Bool) -> SKShapeNode {
        let w = shieldSize.width, h = shieldSize.height
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -w / 2, y: h / 2))
        path.addLine(to: CGPoint(x: w / 2, y: h / 2))
        path.addLine(to: CGPoint(x: w / 2, y: h / 8))
        path.addQuadCurve(to: CGPoint(x: 0, y: -h / 2), control: CGPoint(x: w / 2, y: -h / 4))
        path.addQuadCurve(to: CGPoint(x: -w / 2, y: h / 8), control: CGPoint(x: -w / 2, y: -h / 4))
        path.closeSubpath()

        let shield = SKShapeNode(path: path)
        shield.name = "shield"
        shield.userData = NSMutableDictionary(dictionary: ["option": text])

        if let art = GameAssets.texture(golden ? "shield_gold" : "shield") {
            // User-provided shield art; the shape only carries physics + label.
            shield.fillColor = .clear
            shield.strokeColor = .clear
            let sprite = SKSpriteNode(texture: art)
            let aspect = art.size().height / max(art.size().width, 1)
            sprite.size = CGSize(width: w + 12, height: (w + 12) * aspect)
            shield.addChild(sprite)
        } else {
            shield.fillColor = golden
                ? SKColor(red: 0.62, green: 0.47, blue: 0.13, alpha: 1)
                : SKColor(red: 0.33, green: 0.37, blue: 0.46, alpha: 1)
            shield.strokeColor = golden
                ? SKColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 1)
                : SKColor(red: 0.10, green: 0.12, blue: 0.18, alpha: 1)
            shield.lineWidth = 4
            shield.glowWidth = golden ? 6 : 0

            // Beveled inner face (lighter steel inset)
            var insetTransform = CGAffineTransform(scaleX: 0.86, y: 0.84)
            if let insetPath = path.copy(using: &insetTransform) {
                let inner = SKShapeNode(path: insetPath)
                inner.fillColor = golden
                    ? SKColor(red: 0.78, green: 0.61, blue: 0.20, alpha: 1)
                    : SKColor(red: 0.45, green: 0.50, blue: 0.60, alpha: 1)
                inner.strokeColor = .clear
                inner.position = CGPoint(x: 0, y: 3)
                shield.addChild(inner)
            }

            // Rivets along the top edge
            for rx in [-w / 2 + 12, 0, w / 2 - 12] {
                let rivet = SKShapeNode(circleOfRadius: 3.2)
                rivet.fillColor = SKColor(red: 0.16, green: 0.18, blue: 0.25, alpha: 1)
                rivet.strokeColor = .clear
                rivet.position = CGPoint(x: rx, y: h / 2 - 9)
                rivet.zPosition = 2
                shield.addChild(rivet)
            }
        }

        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = LabelFitter.fontSize(
            for: text, maxWidth: w - 34, base: 15, min: 9
        )
        // Dark text on the bright metal art; white on the dark vector shields.
        label.fontColor = GameAssets.has(golden ? "shield_gold" : "shield")
            ? SKColor(red: 0.08, green: 0.10, blue: 0.16, alpha: 1)
            : .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.numberOfLines = 3
        // Generously larger than the fitter's word cap — only wraps BETWEEN
        // words for multi-word meanings, never mid-word.
        label.preferredMaxLayoutWidth = w - 14
        label.lineBreakMode = .byWordWrapping
        label.position = CGPoint(x: 0, y: 8)
        label.zPosition = 3
        shield.addChild(label)

        let body = SKPhysicsBody(rectangleOf: CGSize(width: w, height: h))
        body.isDynamic = false
        body.categoryBitMask = Category.shield
        body.contactTestBitMask = Category.ball
        shield.physicsBody = body
        return shield
    }

    /// Cartoon cannon like the mockup: fat tapered barrel with a muzzle rim,
    /// round blue body with a gloss, orange spoked wheel, and a lit fuse.
    /// If `cannon_barrel` + `cannon_body` assets exist, they are used instead.
    private func buildCannon() {
        if buildCannonFromAssets() { return }
        buildVectorCannon()
    }

    /// User-art cannon. Two options:
    /// - `cannon_barrel` (drawn pointing STRAIGHT UP) + `cannon_body` (front-facing
    ///   carriage that never rotates): realistic mortar — only the barrel swivels.
    /// - single `cannon` image (drawn aiming ~20° up-right): the whole cannon tilts.
    private func buildCannonFromAssets() -> Bool {
        if let barrelTexture = GameAssets.texture("cannon_barrel"),
           let bodyTexture = GameAssets.texture("cannon_body") {
            cannonArtMode = .twoPart

            // Barrel: drawn vertical, pivots around its breech (bottom).
            let barrelNode = SKNode()
            barrelNode.position = cannonPosition
            barrelNode.zRotation = aimAngle - .pi / 2
            barrelNode.zPosition = 5
            let barrelSprite = SKSpriteNode(texture: barrelTexture)
            let widthOverHeight = barrelTexture.size().width / max(barrelTexture.size().height, 1)
            let spriteHeight = barrelLength + 46
            barrelSprite.size = CGSize(width: spriteHeight * widthOverHeight, height: spriteHeight)
            barrelSprite.anchorPoint = CGPoint(x: 0.5, y: 0.12)
            barrelNode.addChild(barrelSprite)
            addChild(barrelNode)
            barrel = barrelNode

            // Carriage: planted, wheels level, its U-cradle front covers the
            // barrel's breech (cradle sits ~25% from the art's top edge).
            let bodySprite = SKSpriteNode(texture: bodyTexture)
            let bodyAspect = bodyTexture.size().height / max(bodyTexture.size().width, 1)
            let bodyWidth: CGFloat = 172
            let bodyHeight = bodyWidth * bodyAspect
            bodySprite.size = CGSize(width: bodyWidth, height: bodyHeight)
            bodySprite.position = CGPoint(
                x: cannonPosition.x,
                y: cannonPosition.y - bodyHeight * 0.25
            )
            bodySprite.zPosition = 6
            addChild(bodySprite)
            return true
        }

        if let full = GameAssets.texture("cannon") {
            cannonArtMode = .fullImage
            let node = SKNode()
            node.position = cannonPosition
            node.zRotation = aimAngle - Self.fullCannonArtAngle
            node.zPosition = 5
            let sprite = SKSpriteNode(texture: full)
            let aspect = full.size().height / max(full.size().width, 1)
            sprite.size = CGSize(width: 150, height: 150 * aspect)
            sprite.anchorPoint = CGPoint(x: 0.42, y: 0.32) // pivot near the wheel
            node.addChild(sprite)
            addChild(node)
            barrel = node
            return true
        }

        cannonArtMode = .vector
        return false
    }

    private func buildVectorCannon() {
        // --- Barrel (rotates to aim; drawn pointing along +x) ---
        let barrelNode = SKNode()
        barrelNode.position = cannonPosition
        barrelNode.zRotation = aimAngle
        barrelNode.zPosition = 5

        let tube = CGMutablePath()
        tube.move(to: CGPoint(x: 4, y: -18))
        tube.addLine(to: CGPoint(x: barrelLength - 14, y: -23))
        tube.addQuadCurve(to: CGPoint(x: barrelLength - 14, y: 23), control: CGPoint(x: barrelLength - 6, y: 0))
        tube.addLine(to: CGPoint(x: 4, y: 18))
        tube.closeSubpath()
        let tubeNode = SKShapeNode(path: tube)
        tubeNode.fillColor = cannonBlue
        tubeNode.strokeColor = outline
        tubeNode.lineWidth = 3.5
        tubeNode.lineJoin = .round
        barrelNode.addChild(tubeNode)

        // Muzzle rim
        let rim = SKShapeNode(rectOf: CGSize(width: 16, height: 56), cornerRadius: 8)
        rim.fillColor = cannonBlueDark
        rim.strokeColor = outline
        rim.lineWidth = 3.5
        rim.position = CGPoint(x: barrelLength - 8, y: 0)
        barrelNode.addChild(rim)

        // Gloss stripe along the top of the tube
        let gloss = SKShapeNode(rectOf: CGSize(width: barrelLength - 34, height: 6), cornerRadius: 3)
        gloss.fillColor = SKColor.white.withAlphaComponent(0.35)
        gloss.strokeColor = .clear
        gloss.position = CGPoint(x: (barrelLength - 20) / 2, y: 9)
        barrelNode.addChild(gloss)

        addChild(barrelNode)
        barrel = barrelNode

        // --- Body (covers the barrel's back) ---
        let body = SKShapeNode(circleOfRadius: 38)
        body.fillColor = cannonBlue
        body.strokeColor = outline
        body.lineWidth = 3.5
        body.position = cannonPosition
        body.zPosition = 6
        addChild(body)

        let bodyGloss = SKShapeNode(circleOfRadius: 10)
        bodyGloss.fillColor = SKColor.white.withAlphaComponent(0.3)
        bodyGloss.strokeColor = .clear
        bodyGloss.position = CGPoint(x: -9, y: 11)
        body.addChild(bodyGloss)

        // Orange band across the body
        let band = SKShapeNode(rectOf: CGSize(width: 72, height: 13), cornerRadius: 6)
        band.fillColor = cannonOrange
        band.strokeColor = outline
        band.lineWidth = 2.5
        band.position = CGPoint(x: 0, y: -8)
        body.addChild(band)

        // --- Wheel (front, with spokes and hub) ---
        let wheel = SKShapeNode(circleOfRadius: 27)
        wheel.fillColor = cannonOrange
        wheel.strokeColor = outline
        wheel.lineWidth = 3.5
        wheel.position = CGPoint(x: cannonPosition.x + 8, y: cannonPosition.y - 38)
        wheel.zPosition = 7
        addChild(wheel)

        for i in 0..<3 {
            let spoke = SKShapeNode(rectOf: CGSize(width: 48, height: 5), cornerRadius: 2.5)
            spoke.fillColor = outline.withAlphaComponent(0.85)
            spoke.strokeColor = .clear
            spoke.zRotation = CGFloat(i) * .pi / 3
            wheel.addChild(spoke)
        }
        let hub = SKShapeNode(circleOfRadius: 8)
        hub.fillColor = cannonBlueDark
        hub.strokeColor = outline
        hub.lineWidth = 2
        hub.zPosition = 1
        wheel.addChild(hub)

        // --- Fuse with a pulsing spark at the back ---
        let fuse = CGMutablePath()
        let back = CGPoint(x: cannonPosition.x - 40, y: cannonPosition.y + 18)
        fuse.move(to: back)
        fuse.addQuadCurve(
            to: CGPoint(x: back.x - 14, y: back.y + 18),
            control: CGPoint(x: back.x - 16, y: back.y + 2)
        )
        let fuseNode = SKShapeNode(path: fuse)
        fuseNode.strokeColor = SKColor(red: 0.55, green: 0.42, blue: 0.28, alpha: 1)
        fuseNode.lineWidth = 4
        fuseNode.lineCap = .round
        fuseNode.zPosition = 6
        addChild(fuseNode)

        let spark = SKShapeNode(circleOfRadius: 6)
        spark.fillColor = SKColor(red: 0.99, green: 0.82, blue: 0.25, alpha: 1)
        spark.strokeColor = SKColor(red: 0.96, green: 0.55, blue: 0.14, alpha: 1)
        spark.lineWidth = 2
        spark.glowWidth = 6
        spark.position = CGPoint(x: back.x - 15, y: back.y + 20)
        spark.zPosition = 7
        addChild(spark)
        spark.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.4, duration: 0.35),
            SKAction.scale(to: 0.8, duration: 0.35),
        ])))
    }

    private func loadBall() {
        let ball = SKShapeNode(circleOfRadius: ballRadius)
        ball.position = muzzlePoint()
        ball.zPosition = 8
        ball.name = "ball"

        if let art = GameAssets.texture("word_ball") {
            // User-provided ball art; the shape only carries physics + label.
            ball.fillColor = .clear
            ball.strokeColor = .clear
            let sprite = SKSpriteNode(texture: art)
            sprite.size = CGSize(width: ballRadius * 2.2, height: ballRadius * 2.2)
            if comboLevel >= 3 { sprite.color = .orange; sprite.colorBlendFactor = 0.4 }
            ball.addChild(sprite)
        } else {
            // Mockup-style pale word ball; turns fiery at combo ×3
            ball.fillColor = comboLevel >= 3
                ? SKColor(red: 0.98, green: 0.57, blue: 0.24, alpha: 1)
                : SKColor(red: 0.99, green: 0.93, blue: 0.72, alpha: 1)
            ball.strokeColor = comboLevel >= 3
                ? SKColor(red: 0.99, green: 0.82, blue: 0.25, alpha: 1)
                : SKColor(red: 0.96, green: 0.55, blue: 0.14, alpha: 1)
            ball.lineWidth = 3
            ball.glowWidth = comboLevel >= 3 ? 8 : 2

            let gloss = SKShapeNode(circleOfRadius: ballRadius * 0.28)
            gloss.fillColor = SKColor.white.withAlphaComponent(0.55)
            gloss.strokeColor = .clear
            gloss.position = CGPoint(x: -ballRadius * 0.34, y: ballRadius * 0.38)
            ball.addChild(gloss)
        }

        let label = SKLabelNode(text: currentPrompt)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = LabelFitter.fontSize(
            for: currentPrompt, maxWidth: ballRadius * 1.5, base: 14, min: 8
        )
        label.fontColor = SKColor(red: 0.45, green: 0.15, blue: 0.10, alpha: 1)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.numberOfLines = 2
        label.preferredMaxLayoutWidth = ballRadius * 1.95
        ball.addChild(label)

        addChild(ball)
        ballNode = ball
        ball.setScale(0.1)
        ball.run(SKAction.sequence([
            SKAction.scale(to: 1.12, duration: 0.16),
            SKAction.scale(to: 1.0, duration: 0.1),
        ]))
    }

    private func muzzlePoint() -> CGPoint {
        CGPoint(
            x: cannonPosition.x + cos(aimAngle) * (barrelLength + 6),
            y: cannonPosition.y + sin(aimAngle) * (barrelLength + 6)
        )
    }

    // MARK: Aiming & firing

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !resolving, !flying, let touch = touches.first else { return }
        aiming = true
        updateAim(to: touch.location(in: self))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard aiming, let touch = touches.first else { return }
        updateAim(to: touch.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard aiming else { return }
        aiming = false
        clearTrajectory()
        fire()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        aiming = false
        clearTrajectory()
    }

    private func updateAim(to point: CGPoint) {
        let dx = point.x - cannonPosition.x
        let dy = point.y - cannonPosition.y
        guard dx != 0 || dy != 0 else { return }
        var angle = atan2(dy, dx)
        // Keep the barrel pointing upward-ish (two-part mortar swings a
        // narrower, more believable arc around vertical).
        switch cannonArtMode {
        case .twoPart:
            angle = min(max(angle, .pi * 0.22), .pi * 0.78)
        default:
            angle = min(max(angle, .pi * 0.10), .pi * 0.85)
        }
        aimAngle = angle
        switch cannonArtMode {
        case .vector: barrel?.zRotation = angle
        case .fullImage: barrel?.zRotation = angle - Self.fullCannonArtAngle
        case .twoPart: barrel?.zRotation = angle - .pi / 2
        }
        ballNode?.position = muzzlePoint()
        updateTrajectoryPreview()
    }

    private func fire() {
        guard let ball = ballNode, !flying else { return }
        flying = true
        let body = SKPhysicsBody(circleOfRadius: ballRadius)
        body.categoryBitMask = Category.ball
        body.contactTestBitMask = Category.shield
        body.collisionBitMask = Category.wall | Category.shield
        body.restitution = 0.5
        body.linearDamping = 0.05
        body.velocity = CGVector(dx: cos(aimAngle) * fireSpeed, dy: sin(aimAngle) * fireSpeed)
        ball.physicsBody = body

        // Recoil + muzzle flash
        barrel?.run(SKAction.sequence([
            SKAction.moveBy(x: -cos(aimAngle) * 10, y: -sin(aimAngle) * 10, duration: 0.06),
            SKAction.moveBy(x: cos(aimAngle) * 10, y: sin(aimAngle) * 10, duration: 0.12),
        ]))
        let flash = SKShapeNode(circleOfRadius: 16)
        flash.fillColor = SKColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 0.9)
        flash.strokeColor = .clear
        flash.position = muzzlePoint()
        addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.group([SKAction.scale(to: 2, duration: 0.15), SKAction.fadeOut(withDuration: 0.15)]),
            SKAction.removeFromParent(),
        ]))

        SoundManager.shared.play(.cannonFire)
        Haptics.medium()
    }

    // MARK: Trajectory preview

    private func updateTrajectoryPreview() {
        clearTrajectory()
        let origin = muzzlePoint()
        let v = CGVector(dx: cos(aimAngle) * fireSpeed, dy: sin(aimAngle) * fireSpeed)
        let g = physicsWorld.gravity

        let path = CGMutablePath()
        path.move(to: origin)
        for step in 1...16 {
            let t = CGFloat(step) * 0.045
            let x = origin.x + v.dx * t
            let y = origin.y + v.dy * t + 0.5 * g.dy * 150 * t * t
            path.addLine(to: CGPoint(x: x, y: y))
        }
        let node = SKShapeNode(path: path.copy(dashingWithPhase: 0, lengths: [5, 9]))
        node.strokeColor = SKColor.white.withAlphaComponent(0.4)
        node.lineWidth = 2
        node.zPosition = 1
        addChild(node)
        trajectoryNode = node
    }

    private func clearTrajectory() {
        trajectoryNode?.removeFromParent()
        trajectoryNode = nil
    }

    // MARK: Contact

    func didBegin(_ contact: SKPhysicsContact) {
        guard !resolving else { return }
        let nodes = [contact.bodyA.node, contact.bodyB.node].compactMap { $0 }
        guard nodes.contains(where: { $0.name == "ball" }),
              let shield = nodes.first(where: { $0.name == "shield" }) as? SKShapeNode,
              let option = shield.userData?["option"] as? String
        else { return }
        resolving = true
        lastHitShield = shield
        onBallHitShield?(option)
    }

    private weak var lastHitShield: SKShapeNode?

    // MARK: Resolution animations (driven by the SwiftUI layer)

    func animateCorrectHit(completion: @escaping () -> Void) {
        guard let shield = lastHitShield else { completion(); return }
        ballNode?.physicsBody = nil
        ballNode?.removeFromParent()
        chainNode?.removeAction(forKey: "sway")

        // Shield shatters into shards
        for _ in 0..<12 {
            let shard = SKShapeNode(rectOf: CGSize(width: CGFloat.random(in: 6...14), height: CGFloat.random(in: 6...14)), cornerRadius: 2)
            shard.fillColor = shield.strokeColor
            shard.strokeColor = .clear
            shard.position = shield.parent?.convert(shield.position, to: self) ?? shield.position
            shard.zPosition = 20
            addChild(shard)
            let body = SKPhysicsBody(rectangleOf: CGSize(width: 8, height: 8))
            body.categoryBitMask = 0
            body.collisionBitMask = 0
            body.velocity = CGVector(dx: CGFloat.random(in: -260...260), dy: CGFloat.random(in: 60...380))
            body.angularVelocity = CGFloat.random(in: -8...8)
            shard.physicsBody = body
            shard.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.7), SKAction.removeFromParent()]))
        }

        let burst = SKShapeNode(circleOfRadius: 40)
        burst.position = shield.parent?.convert(shield.position, to: self) ?? shield.position
        burst.strokeColor = SKColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 1)
        burst.lineWidth = 4
        burst.glowWidth = 8
        burst.zPosition = 20
        addChild(burst)
        burst.run(SKAction.group([
            SKAction.scale(to: 2.4, duration: 0.35),
            SKAction.fadeOut(withDuration: 0.35),
        ]))

        shield.removeFromParent()
        for other in shieldNodes where other !== shield {
            other.run(SKAction.fadeOut(withDuration: 0.3))
        }

        run(SKAction.sequence([SKAction.wait(forDuration: 0.75), SKAction.run(completion)]))
    }

    func animateWrongHit() {
        // Shield clangs and shakes; ball drops away and reloads.
        if let shield = lastHitShield {
            let shake = SKAction.sequence([
                SKAction.moveBy(x: 8, y: 0, duration: 0.05),
                SKAction.moveBy(x: -16, y: 0, duration: 0.08),
                SKAction.moveBy(x: 12, y: 0, duration: 0.07),
                SKAction.moveBy(x: -4, y: 0, duration: 0.05),
            ])
            shield.run(shake)
        }
        if let ball = ballNode {
            ball.physicsBody?.velocity = CGVector(dx: CGFloat.random(in: -160...160), dy: -380)
            ball.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.4),
                SKAction.fadeOut(withDuration: 0.2),
                SKAction.removeFromParent(),
            ]))
        }
        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.65),
            SKAction.run { [weak self] in
                guard let self else { return }
                self.flying = false
                self.resolving = false
                self.loadBall()
            },
        ]))
    }

    // MARK: Frame update — recover lost balls

    override func update(_ currentTime: TimeInterval) {
        guard flying, !resolving, let ball = ballNode else { return }
        if ball.position.y < -80 || ball.position.y > size.height + 160 {
            ball.removeFromParent()
            flying = false
            loadBall()
        }
    }
}

// MARK: - Geometry helpers

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(other.x - x, other.y - y)
    }
}

extension CGVector {
    func capped(maxMagnitude: CGFloat) -> CGVector {
        let magnitude = hypot(dx, dy)
        guard magnitude > maxMagnitude, magnitude > 0 else { return self }
        let scale = maxMagnitude / magnitude
        return CGVector(dx: dx * scale, dy: dy * scale)
    }
}
