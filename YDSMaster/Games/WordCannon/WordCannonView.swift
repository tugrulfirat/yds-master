import SwiftUI
import SpriteKit

struct WordCannonView: View {
    @ObservedObject var session: GameSession
    var onRoundEnd: () -> Void

    @State private var scene: WordCannonScene?
    @State private var reveal: (text: String, correct: Bool)?
    @State private var revealToken = UUID()
    @State private var xpFloat: Int?
    @State private var hintLetter: String?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ArenaBackground(mode: .wordCannon)

                if let scene {
                    SpriteView(scene: scene, options: [.allowsTransparency])
                        .ignoresSafeArea()
                }

                VStack(spacing: 0) {
                    GameHeaderView(session: session, accent: Theme.modeColor(.wordCannon)) {
                        onRoundEnd()
                    }
                    .padding(.top, 8)

                    if let hintLetter {
                        Text("Şununla başlıyor: “\(hintLetter)”")
                            .font(Theme.font(14, weight: .bold))
                            .foregroundStyle(Theme.gold)
                            .padding(.top, 4)
                            .allowsHitTesting(false)
                    }

                    Spacer()

                    // Reveal lives in the open grass area so it never covers
                    // the shields; it dismisses itself after a moment.
                    HStack {
                        if let reveal {
                            RevealTrayView(text: reveal.text, isCorrect: reveal.correct)
                        }
                        if let xpFloat {
                            FloatingXPView(amount: xpFloat).id(xpFloat)
                        }
                    }
                    .frame(height: 56)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: reveal?.text)
                    .allowsHitTesting(false)
                    .padding(.bottom, 4)

                    // Power-ups
                    HStack(spacing: 10) {
                        PowerUpButton(powerUp: .firstLetter, count: session.store.powerUpCount(.firstLetter)) {
                            if let letter = session.useFirstLetter() {
                                Haptics.selection()
                                hintLetter = letter
                            }
                        }
                        PowerUpButton(powerUp: .removeWrong, count: session.store.powerUpCount(.removeWrong)) {
                            if session.useRemoveWrong() != nil {
                                Haptics.selection()
                                reloadQuestion(removingOneWrong: true)
                            }
                        }
                        PowerUpButton(powerUp: .shield, count: session.store.powerUpCount(.shield)) {
                            if session.useShield() { Haptics.selection() }
                        }
                        Spacer()
                        Text("Nişan al ve bırak 🎯")
                            .font(Theme.font(11, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
            .onAppear {
                if scene == nil {
                    setupScene(size: geo.size)
                }
            }
        }
    }

    // MARK: Scene wiring

    private func setupScene(size: CGSize) {
        let newScene = WordCannonScene(size: size)
        newScene.scaleMode = .resizeFill
        newScene.movingShields = session.store.profile.startingDifficulty >= .intermediate
        newScene.onBallHitShield = { option in
            handleHit(option: option)
        }
        scene = newScene
        loadCurrentQuestion(into: newScene)
    }

    private func loadCurrentQuestion(into scene: WordCannonScene) {
        guard let question = session.current else { return }
        session.markQuestionShown()
        hintLetter = nil
        scene.comboLevel = session.combo
        // Every 5th shield row is a golden bonus (extra satisfying).
        let golden = (session.index + 1) % 5 == 0
        scene.loadQuestion(prompt: question.prompt, options: question.options, golden: golden)
    }

    private func reloadQuestion(removingOneWrong: Bool) {
        guard let scene, let question = session.current else { return }
        var options = question.options
        if removingOneWrong, let wrongIndex = options.firstIndex(where: { $0 != question.correctAnswer }) {
            options.remove(at: wrongIndex)
        }
        scene.loadQuestion(prompt: question.prompt, options: options, golden: false)
    }

    private func showReveal(_ text: String, correct: Bool) {
        reveal = (text, correct)
        let token = UUID()
        revealToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            if revealToken == token {
                withAnimation(.easeOut(duration: 0.3)) { reveal = nil }
            }
        }
    }

    private func handleHit(option: String) {
        guard let scene else { return }
        let feedback = session.submit(answer: option)

        switch feedback {
        case .correct(let gained, let revealText, _):
            SoundManager.shared.play(.explosion)
            Haptics.success()
            if session.combo >= 3 { SoundManager.shared.play(.comboUp) }
            showReveal(revealText, correct: true)
            xpFloat = gained
            scene.animateCorrectHit {
                if session.advance() {
                    loadCurrentQuestion(into: scene)
                } else {
                    onRoundEnd()
                }
            }
        case .wrong(_, let shieldUsed):
            // Don't reveal the pair — the player retries this word.
            SoundManager.shared.play(.bonk)
            Haptics.error()
            scene.animateWrongHit()
            if !shieldUsed, session.loseLife() <= 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { onRoundEnd() }
            }
        }
    }
}
