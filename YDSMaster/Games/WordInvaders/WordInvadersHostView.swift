import SwiftUI

/// Hosts one Word Circuit round: instruction → gameplay → result. Mirrors
/// `GameHostView`'s phase/transition structure but drives its own
/// `WordInvadersSession` instead of the shared `GameSession`, since this
/// mode's multi-word-per-wave scoring doesn't fit that shared engine.
struct WordInvadersHostView: View {
    @EnvironmentObject var store: WordStore
    @Environment(\.dismiss) private var dismiss

    let kind: SessionKind

    @State private var session: WordInvadersSession?
    @State private var phase: Phase = .intro
    @State private var result: GameResult?

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum Phase { case intro, playing, result }

    var body: some View {
        ZStack {
            Theme.background

            if let session {
                switch phase {
                case .intro:
                    InstructionOverlay(mode: .wordInvaders) {
                        Haptics.medium()
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                            phase = .playing
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .scale(scale: 1.15).combined(with: .opacity)
                    ))
                case .playing:
                    WordInvadersView(session: session, onRoundEnd: finishRound)
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
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .onAppear {
            if session == nil { session = WordInvadersSession(store: store, kind: kind) }
            SoundManager.shared.playMusic(.arena)
            #if DEBUG
            // Debug hook: skip the intro splash when auto-started. Compiled
            // out of release builds entirely.
            if ProcessInfo.processInfo.environment["YDS_AUTOSTART"] != nil, phase == .intro {
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

    private func finishRound() {
        guard let session else { return }
        result = session.finish()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
            phase = .result
        }
    }

    private func restart() {
        result = nil
        session = WordInvadersSession(store: store, kind: kind)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
            phase = .intro
        }
    }
}
