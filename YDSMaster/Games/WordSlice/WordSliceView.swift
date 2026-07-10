import SwiftUI
import SpriteKit

struct WordSliceView: View {
    @ObservedObject var session: GameSession
    var onRoundEnd: () -> Void

    @State private var scene: WordSliceScene?
    @State private var reveal: (text: String, correct: Bool)?
    @State private var xpFloat: Int?
    @State private var wrongFlash = false
    @State private var resolvingCorrect = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ArenaBackground(mode: .wordSlice)

                if let scene {
                    SpriteView(scene: scene, options: [.allowsTransparency])
                        .ignoresSafeArea()
                }

                // Wrong-slice / bomb screen flash
                Rectangle()
                    .fill(Theme.danger.opacity(wrongFlash ? 0.22 : 0))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    GameHeaderView(session: session, accent: Theme.modeColor(.wordSlice)) {
                        onRoundEnd()
                    }
                    .padding(.top, 8)

                    // Prompt: the meaning to hunt for
                    if let question = session.current {
                        VStack(spacing: 4) {
                            Text("Şunun kelimesini kes:")
                                .font(Theme.font(12, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                            Text(question.prompt)
                                .font(Theme.font(26, weight: .heavy))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .cardStyle(cornerRadius: 18)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                    }

                    HStack {
                        Spacer()
                        if let reveal {
                            RevealTrayView(text: reveal.text, isCorrect: reveal.correct)
                        }
                        if let xpFloat {
                            FloatingXPView(amount: xpFloat).id(xpFloat)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 60)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: reveal?.text)
                    .allowsHitTesting(false)

                    Spacer()

                    HStack(spacing: 10) {
                        PowerUpButton(powerUp: .slowMotion, count: session.store.powerUpCount(.slowMotion)) {
                            if session.useSlowMotion() {
                                Haptics.selection()
                                scene?.activateSlowMotion()
                            }
                        }
                        PowerUpButton(powerUp: .shield, count: session.store.powerUpCount(.shield)) {
                            if session.useShield() { Haptics.selection() }
                        }
                        Spacer()
                        Text("Bombaları kesme 💣")
                            .font(Theme.font(11, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
            .onAppear {
                if scene == nil { setupScene(size: geo.size) }
            }
        }
    }

    // MARK: Scene wiring

    private var speedFactor: Double {
        let difficultyBoost = Double(session.store.profile.startingDifficulty.rawValue - 1) * 0.2
        return 1.0 + Double(session.index) * 0.06 + difficultyBoost
    }

    private func setupScene(size: CGSize) {
        let newScene = WordSliceScene(size: size)
        newScene.scaleMode = .resizeFill
        newScene.onWordSliced = { word, node in
            handleSlice(word: word, node: node)
        }
        newScene.onBombSliced = { node in
            handleBomb(node: node)
        }
        scene = newScene
        startCurrentQuestion()
    }

    private func startCurrentQuestion() {
        guard let scene, let question = session.current else { return }
        session.markQuestionShown()
        resolvingCorrect = false
        scene.startQuestion(
            options: question.options,
            correct: question.correctAnswer,
            speedFactor: speedFactor,
            bombs: session.index >= 2, // bombs join once the player is warmed up
            displayMap: synonymDisplayMap(for: question)
        )
    }

    /// Some bubbles show "word + synonym" pairs (mockup style) — only for
    /// English answers, where synonym data applies.
    private func synonymDisplayMap(for question: Question) -> [String: String] {
        guard question.direction == .trToEn else { return [:] }
        var map: [String: String] = [:]
        for option in question.options {
            guard Bool.random(),
                  let word = session.store.words.first(where: { $0.englishWord == option }),
                  let synonym = word.synonyms.first
            else { continue }
            map[option] = "\(option)\n+ \(synonym)"
        }
        return map
    }

    private func handleSlice(word: String, node: SKNode) {
        guard let scene, !resolvingCorrect else { return }
        let feedback = session.submit(answer: word)

        switch feedback {
        case .correct(let gained, let revealText, _):
            resolvingCorrect = true
            SoundManager.shared.play(.slice)
            Haptics.success()
            reveal = (revealText, true)
            xpFloat = gained
            scene.animateCorrectSlice(node: node)
            scene.stopSpawning()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                if session.advance() {
                    startCurrentQuestion()
                } else {
                    onRoundEnd()
                }
            }

        case .wrong(_, let shieldUsed):
            // No reveal — the correct word will fly again on this question.
            SoundManager.shared.play(.bonk)
            Haptics.error()
            scene.animateWrongSlice(node: node)
            flashScreen()
            if !shieldUsed, session.loseLife() <= 0 {
                endEarly()
            }
        }
    }

    private func handleBomb(node: SKNode) {
        guard let scene, !resolvingCorrect else { return }
        SoundManager.shared.play(.bonk)
        Haptics.heavy()
        scene.animateBombExplosion(node: node)
        flashScreen()
        if session.penalizeBomb() <= 0 {
            endEarly()
        }
    }

    private func flashScreen() {
        withAnimation(.easeOut(duration: 0.1)) { wrongFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeIn(duration: 0.3)) { wrongFlash = false }
        }
    }

    private func endEarly() {
        scene?.stopSpawning()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { onRoundEnd() }
    }
}
