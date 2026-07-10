import SpriteKit

/// Fruit-Ninja-style scene: word bubbles are tossed up through the screen,
/// the player swipes to slice. Bombs must NOT be sliced. The scene reports
/// what was sliced; validation happens outside (GameSession).
final class WordSliceScene: SKScene {

    // MARK: Callbacks

    var onWordSliced: ((String, SKNode) -> Void)?
    var onBombSliced: ((SKNode) -> Void)?

    // MARK: Question state

    private var options: [String] = []
    private var correctWord: String = ""
    /// Optional richer bubble text per option (e.g. "alleviate\n+ ease").
    private var displayMap: [String: String] = [:]
    private var bombsEnabled = false
    private var spawnInterval: TimeInterval = 1.15
    private var paused_ = false

    // MARK: Slice trail

    private var trailPoints: [CGPoint] = []
    private var trailNode: SKShapeNode?
    private var slicedThisSwipe = Set<ObjectIdentifier>()

    private let bubbleColors: [SKColor] = [
        SKColor(red: 0.13, green: 0.83, blue: 0.93, alpha: 1),
        SKColor(red: 0.55, green: 0.36, blue: 0.96, alpha: 1),
        SKColor(red: 0.98, green: 0.57, blue: 0.24, alpha: 1),
        SKColor(red: 0.20, green: 0.83, blue: 0.60, alpha: 1),
        SKColor(red: 0.96, green: 0.40, blue: 0.65, alpha: 1),
    ]

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        physicsWorld.gravity = CGVector(dx: 0, dy: -5.5)
    }

    // MARK: Question lifecycle

    func startQuestion(
        options: [String],
        correct: String,
        speedFactor: Double,
        bombs: Bool,
        displayMap: [String: String]
    ) {
        self.options = options
        self.correctWord = correct
        self.displayMap = displayMap
        self.bombsEnabled = bombs
        self.spawnInterval = max(0.6, 1.15 / speedFactor)
        paused_ = false
        physicsWorld.speed = 1

        removeAction(forKey: "spawner")
        for child in children where child.name == "capsule" || child.name == "bomb" {
            child.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.2), SKAction.removeFromParent()]))
        }

        let spawn = SKAction.sequence([
            SKAction.run { [weak self] in self?.spawnNext() },
            SKAction.wait(forDuration: spawnInterval, withRange: 0.4),
        ])
        run(SKAction.repeatForever(spawn), withKey: "spawner")
    }

    func stopSpawning() {
        paused_ = true
        removeAction(forKey: "spawner")
    }

    /// Slow-motion power-up: words drift for a few seconds.
    func activateSlowMotion(duration: TimeInterval = 4) {
        physicsWorld.speed = 0.35
        run(SKAction.sequence([
            SKAction.wait(forDuration: duration),
            SKAction.run { [weak self] in self?.physicsWorld.speed = 1 },
        ]))
    }

    // MARK: Spawning

    private func spawnNext() {
        guard !paused_, !options.isEmpty else { return }

        // Occasional bomb trap
        if bombsEnabled && Double.random(in: 0...1) < 0.13 {
            toss(makeBomb())
            return
        }

        let correctOnScreen = children.contains {
            $0.name == "capsule" && ($0.userData?["word"] as? String) == correctWord
        }
        let word: String
        if !correctOnScreen && Double.random(in: 0...1) < 0.45 {
            word = correctWord
        } else {
            word = options.randomElement() ?? correctWord
        }
        toss(makeBubble(word: word))
    }

    private enum Category {
        static let bubble: UInt32 = 1 << 0
    }

    private func toss(_ node: SKShapeNode) {
        // Avoid spawning on top of a bubble that's still near the bottom.
        let candidates = Array(stride(from: size.width * 0.15, through: size.width * 0.85, by: size.width * 0.1))
        let lowNodeXs = children
            .filter { ($0.name == "capsule" || $0.name == "bomb") && $0.position.y < size.height * 0.3 }
            .map { $0.position.x }
        func clearance(_ candidateX: CGFloat) -> CGFloat {
            lowNodeXs.map { abs($0 - candidateX) }.min() ?? .infinity
        }
        let x = candidates.max { clearance($0) < clearance($1) }
            ?? CGFloat.random(in: size.width * 0.15...size.width * 0.85)

        node.position = CGPoint(x: x, y: -60)
        addChild(node)

        // Match the physics radius to the node's actual drawn size (bubbles
        // vary in size to fit longer words).
        let physicsRadius = node.frame.width / 2
        let body = SKPhysicsBody(circleOfRadius: physicsRadius)
        // Bubbles gently collide with each other so they never render stacked.
        body.categoryBitMask = Category.bubble
        body.collisionBitMask = Category.bubble
        body.contactTestBitMask = 0
        body.restitution = 0.4
        body.linearDamping = 0
        body.allowsRotation = true
        // Launch speed to reach the target apex: v = √(2·g·h),
        // with SpriteKit gravity in point units (5.5 m/s² × 150 pt/m).
        let targetHeight = CGFloat.random(in: 0.55...0.85) * size.height
        let gravityPoints: CGFloat = 5.5 * 150
        let vy = sqrt(2 * gravityPoints * (targetHeight + 80))
        let centerPull = (size.width / 2 - x) / size.width
        body.velocity = CGVector(dx: centerPull * 260 + CGFloat.random(in: -60...60), dy: vy)
        // Gentle wobble only — words must stay readable in flight.
        body.angularVelocity = CGFloat.random(in: -0.4...0.4)
        node.physicsBody = body
    }

    private func makeBubble(word: String) -> SKShapeNode {
        let display = displayMap[word] ?? word
        let label = SKLabelNode(text: display)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = LabelFitter.fontSize(
            for: display, maxWidth: 78, base: 16, min: 10
        )
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.numberOfLines = 3
        // Generously larger than the fitter's word cap — only wraps BETWEEN
        // words for multi-word/synonym-pair text, never mid-word.
        label.preferredMaxLayoutWidth = 96
        label.lineBreakMode = .byWordWrapping

        // Size the bubble to the text's actual rendered box (width AND
        // height, since multi-word text wraps to 2+ lines).
        let radius = max(44, min(62, max(label.frame.width, label.frame.height) / 2 + 18))
        let bubble = SKShapeNode(circleOfRadius: radius)
        let color = bubbleColors.randomElement()!
        bubble.fillColor = color.withAlphaComponent(0.9)
        bubble.strokeColor = SKColor.white.withAlphaComponent(0.55)
        bubble.lineWidth = 2
        bubble.glowWidth = 4
        bubble.name = "capsule"
        bubble.userData = NSMutableDictionary(dictionary: ["word": word])

        // Glossy highlight
        let gloss = SKShapeNode(circleOfRadius: radius * 0.26)
        gloss.fillColor = SKColor.white.withAlphaComponent(0.28)
        gloss.strokeColor = .clear
        gloss.position = CGPoint(x: -radius * 0.36, y: radius * 0.4)
        bubble.addChild(gloss)

        bubble.addChild(label)
        return bubble
    }

    private func makeBomb() -> SKShapeNode {
        let bomb = SKShapeNode(circleOfRadius: 40)
        bomb.name = "bomb"

        if let art = GameAssets.texture("bomb") {
            bomb.fillColor = .clear
            bomb.strokeColor = .clear
            let sprite = SKSpriteNode(texture: art)
            let aspect = art.size().height / max(art.size().width, 1)
            sprite.size = CGSize(width: 84, height: 84 * aspect)
            bomb.addChild(sprite)
        } else {
            bomb.fillColor = SKColor(red: 0.09, green: 0.09, blue: 0.13, alpha: 0.98)
            bomb.strokeColor = SKColor(red: 0.97, green: 0.44, blue: 0.44, alpha: 0.9)
            bomb.lineWidth = 2.5
            bomb.glowWidth = 5
            let label = SKLabelNode(text: "💣")
            label.fontSize = 34
            label.verticalAlignmentMode = .center
            bomb.addChild(label)
        }
        return bomb
    }

    // MARK: Slice gesture

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        trailPoints = [touch.location(in: self)]
        slicedThisSwipe = []
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        trailPoints.append(location)
        if trailPoints.count > 10 { trailPoints.removeFirst() }
        updateTrail()

        guard !paused_ else { return }
        for node in nodes(at: location) where node.name == "capsule" || node.name == "bomb" {
            let nodeID = ObjectIdentifier(node)
            guard !slicedThisSwipe.contains(nodeID) else { continue }
            slicedThisSwipe.insert(nodeID)
            if node.name == "bomb" {
                onBombSliced?(node)
            } else if let word = node.userData?["word"] as? String {
                onWordSliced?(word, node)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        fadeTrail()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        fadeTrail()
    }

    private func updateTrail() {
        trailNode?.removeFromParent()
        guard trailPoints.count > 1 else { return }
        let path = CGMutablePath()
        path.move(to: trailPoints[0])
        for point in trailPoints.dropFirst() { path.addLine(to: point) }
        let node = SKShapeNode(path: path)
        node.strokeColor = SKColor(red: 0.13, green: 0.83, blue: 0.93, alpha: 0.85)
        node.lineWidth = 5
        node.lineCap = .round
        node.glowWidth = 6
        node.zPosition = 50
        addChild(node)
        trailNode = node
    }

    private func fadeTrail() {
        trailPoints = []
        trailNode?.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.15), SKAction.removeFromParent()]))
        trailNode = nil
    }

    // MARK: Resolution animations

    func animateCorrectSlice(node: SKNode) {
        guard let bubble = node as? SKShapeNode else { return }
        bubble.physicsBody = nil
        bubble.name = "sliced"

        // Split into two halves flying apart
        for side in [-1.0, 1.0] {
            let half = SKShapeNode(circleOfRadius: 26)
            half.fillColor = bubble.fillColor
            half.strokeColor = bubble.strokeColor
            half.position = bubble.position
            addChild(half)
            let body = SKPhysicsBody(circleOfRadius: 20)
            body.categoryBitMask = 0
            body.collisionBitMask = 0
            body.velocity = CGVector(dx: side * CGFloat.random(in: 140...240), dy: CGFloat.random(in: 120...260))
            body.angularVelocity = side * 4
            half.physicsBody = body
            half.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.6), SKAction.removeFromParent()]))
        }

        for _ in 0..<10 {
            let spark = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...5))
            spark.fillColor = SKColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 1)
            spark.strokeColor = .clear
            spark.position = bubble.position
            addChild(spark)
            let angle = CGFloat.random(in: 0...(2 * .pi))
            spark.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: cos(angle) * 90, y: sin(angle) * 90, duration: 0.4),
                    SKAction.fadeOut(withDuration: 0.4),
                ]),
                SKAction.removeFromParent(),
            ]))
        }
        bubble.removeFromParent()
    }

    func animateWrongSlice(node: SKNode) {
        guard let bubble = node as? SKShapeNode else { return }
        bubble.fillColor = SKColor(red: 0.97, green: 0.44, blue: 0.44, alpha: 0.95)
        bubble.physicsBody?.velocity = CGVector(dx: CGFloat.random(in: -220...220), dy: 380)
        bubble.physicsBody?.angularVelocity = 6
        bubble.name = "sliced"
        bubble.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent(),
        ]))
    }

    func animateBombExplosion(node: SKNode) {
        let position = node.position
        node.removeFromParent()
        for _ in 0..<16 {
            let piece = SKShapeNode(circleOfRadius: CGFloat.random(in: 3...7))
            piece.fillColor = SKColor(red: 0.97, green: 0.44, blue: 0.24, alpha: 1)
            piece.strokeColor = .clear
            piece.position = position
            addChild(piece)
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 80...200)
            piece.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 0.45),
                    SKAction.fadeOut(withDuration: 0.45),
                ]),
                SKAction.removeFromParent(),
            ]))
        }
        let ring = SKShapeNode(circleOfRadius: 30)
        ring.position = position
        ring.strokeColor = SKColor(red: 0.97, green: 0.44, blue: 0.24, alpha: 1)
        ring.lineWidth = 5
        ring.glowWidth = 10
        addChild(ring)
        ring.run(SKAction.sequence([
            SKAction.group([SKAction.scale(to: 3, duration: 0.4), SKAction.fadeOut(withDuration: 0.4)]),
            SKAction.removeFromParent(),
        ]))
    }

    // MARK: Cleanup fallen nodes

    override func update(_ currentTime: TimeInterval) {
        for child in children where child.name == "capsule" || child.name == "bomb" {
            if child.position.y < -100 && (child.physicsBody?.velocity.dy ?? 0) < 0 {
                child.removeFromParent()
            }
        }
    }
}
