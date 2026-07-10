import SwiftUI
import Combine

/// Hosts one round of any game mode: instruction → gameplay → result.
/// All learning logic lives in `GameSession`; games only render and animate.
/// Also owns the arcade countdown: when the round timer hits zero, the round ends.
struct GameHostView: View {
    @EnvironmentObject var store: WordStore
    @Environment(\.dismiss) private var dismiss

    let mode: GameMode
    let kind: SessionKind

    @State private var session: GameSession?
    @State private var phase: Phase = .intro
    @State private var result: GameResult?

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum Phase { case intro, playing, result }

    var body: some View {
        // Word Circuit drives its own session/engine (multi-word-per-wave
        // scoring doesn't fit the shared "one word per question" GameSession
        // contract) — hand off to its dedicated host entirely.
        if mode == .wordInvaders {
            WordInvadersHostView(kind: kind)
        } else {
            sessionBasedBody
        }
    }

    private var sessionBasedBody: some View {
        ZStack {
            Theme.background

            if let session {
                switch phase {
                case .intro:
                    InstructionOverlay(mode: mode) {
                        Haptics.medium()
                        session.markQuestionShown()
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                            phase = .playing
                        }
                    }
                    // Zooms "into" the arena when the round starts.
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .scale(scale: 1.15).combined(with: .opacity)
                    ))
                case .playing:
                    gameView(session: session)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.94).combined(with: .opacity),
                            removal: .opacity
                        ))
                case .result:
                    if let result {
                        ResultView(
                            result: result,
                            onPlayAgain: { restart() },
                            onContinue: { dismiss() }
                        )
                        // Slides up over the arena like a score sheet.
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .onAppear {
            if session == nil { session = makeSession() }
            SoundManager.shared.playMusic(.arena)
            #if DEBUG
            // Debug hook: skip the intro splash when auto-started. Compiled
            // out of release builds entirely.
            if ProcessInfo.processInfo.environment["YDS_AUTOSTART"] != nil, phase == .intro {
                session?.markQuestionShown()
                phase = .playing
            }
            #endif
        }
        .onDisappear {
            SoundManager.shared.playMusic(.menu)
        }
        .onReceive(clock) { _ in
            guard phase == .playing, let session else { return }
            if session.tick() {
                Haptics.warning()
                finishRound()
            }
        }
    }

    @ViewBuilder
    private func gameView(session: GameSession) -> some View {
        switch mode {
        case .wordCannon:
            WordCannonView(session: session, onRoundEnd: finishRound)
        case .wordSlice:
            WordSliceView(session: session, onRoundEnd: finishRound)
        case .meaningFactory:
            MeaningFactoryView(session: session, onRoundEnd: finishRound)
        case .monsterBattle:
            MonsterBattleView(session: session, onRoundEnd: finishRound)
        case .wordHuntMirror:
            WordHuntMirrorView(session: session, onRoundEnd: finishRound)
        case .wordInvaders:
            EmptyView() // handled by WordInvadersHostView before reaching this switch
        }
    }

    private func makeSession() -> GameSession {
        switch mode {
        case .meaningFactory:
            return GameSession(mode: mode, kind: kind, store: store, questionCount: 12)

        case .monsterBattle:
            // 9 normal monsters + a 3-hit boss built from missed/confusing words.
            var words = store.sessionWords(count: 9, kind: kind)
            let bossWords = store.bossWords(count: 6).filter { !words.contains($0) }.prefix(3)
            words.append(contentsOf: bossWords)
            return GameSession(mode: mode, kind: kind, store: store, words: words)

        case .wordHuntMirror:
            // Long answers blow the shared letter grid up into unreadably
            // tiny cells (e.g. "psychological" forces a 13+ column grid).
            // Only words whose BOTH sides fit a 9-column grid — and contain
            // nothing but letters — play well as word-search targets.
            let fitsGrid: (Word) -> Bool = { candidate in
                let sides = [candidate.englishWord, candidate.turkishMeaning]
                    .map { $0.replacingOccurrences(of: " ", with: "") }
                return sides.allSatisfy { $0.count <= 9 && $0.allSatisfy(\.isLetter) }
            }
            var huntWords = store.sessionWords(count: 24, kind: kind).filter(fitsGrid)
            if huntWords.count < 8 {
                let extras = store.words
                    .filter { fitsGrid($0) && !huntWords.contains($0) }
                    .shuffled()
                    .prefix(8 - huntWords.count)
                huntWords.append(contentsOf: extras)
            }
            return GameSession(mode: mode, kind: kind, store: store, words: Array(huntWords.prefix(8)))

        case .wordCannon, .wordSlice:
            return GameSession(mode: mode, kind: kind, store: store, questionCount: 10)

        case .wordInvaders:
            fatalError("Word Circuit bypasses GameSession — handled by WordInvadersHostView")
        }
    }

    private func finishRound() {
        guard let session else { return }
        result = session.finish()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
            phase = .result
        }
    }

    private func restart() {
        result = nil
        session = makeSession()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
            phase = .intro
        }
    }
}
