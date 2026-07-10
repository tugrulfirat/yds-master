import SwiftUI

// MARK: - Arcade HUD (Level • Score • Time, hearts, combo, progress)

struct GameHeaderView: View {
    @ObservedObject var session: GameSession
    var accent: Color
    /// Label shown under the combo counter (e.g. "SIRALAMA KOMBOSU" in the factory).
    var comboLabel: String = "KOMBO"
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // Level | Score | Time panels (mockup-style header)
            HStack(spacing: 10) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Theme.card))
                }
                hudPanel(title: "Seviye", value: "\(session.store.profile.level)", tint: Theme.textPrimary)
                hudPanel(title: "Skor", value: session.score.formatted(), tint: Theme.gold)
                hudPanel(title: "Süre", value: session.timeText,
                         tint: session.timeRemaining <= 10 ? Theme.danger : Theme.textPrimary)
            }

            HStack(spacing: 12) {
                // Hearts
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { i in
                        Text(i < session.lives ? "❤️" : "🖤").font(.system(size: 14))
                    }
                }

                ProgressView(value: session.progressFraction)
                    .tint(accent)
                    .scaleEffect(y: 2, anchor: .center)
                    .clipShape(Capsule())

                Text("\(min(session.index + 1, session.totalQuestions))/\(session.totalQuestions)")
                    .font(Theme.font(13, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
            }

            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    ComboMeterView(combo: session.combo)
                    if session.combo >= 2 {
                        Text(comboLabel)
                            .font(Theme.font(9, weight: .heavy))
                            .foregroundStyle(Theme.orange.opacity(0.8))
                    }
                }
                Spacer()
                if session.shieldActive {
                    Text("🛡️")
                        .font(.system(size: 18))
                        .transition(.scale)
                }
                Label("\(session.xpEarned) XP", systemImage: "bolt.fill")
                    .font(Theme.font(14, weight: .bold))
                    .foregroundStyle(Theme.gold)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
    }

    private func hudPanel(title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 1) {
            Text(title.turkishUppercased)
                .font(Theme.font(10, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(Theme.font(18, weight: .black))
                .foregroundStyle(tint)
                .shadow(color: .black.opacity(0.6), radius: 0, y: 1.5)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .arcadePanel(cornerRadius: 12)
    }
}

// MARK: - Combo meter

struct ComboMeterView: View {
    let combo: Int

    var body: some View {
        HStack(spacing: 4) {
            Text(combo >= 6 ? "⚡️" : "🔥")
                .font(.system(size: combo >= 3 ? 20 : 15))
                .opacity(combo >= 2 ? 1 : 0.35)
            Text("×\(combo)")
                .font(Theme.font(16, weight: .heavy))
                .foregroundStyle(combo >= 3 ? Theme.orange : Theme.textSecondary)
                .monospacedDigit()
        }
        .scaleEffect(combo >= 3 ? 1.1 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: combo)
    }
}

// MARK: - Reveal tray ("prevent = önlemek")

struct RevealTrayView: View {
    let text: String
    let isCorrect: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "arrow.uturn.left.circle.fill")
                .foregroundStyle(isCorrect ? Theme.success : Theme.orange)
            Text(text)
                .font(Theme.font(17, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Theme.card)
                .overlay(Capsule().stroke((isCorrect ? Theme.success : Theme.orange).opacity(0.6), lineWidth: 1.5))
                .shadow(color: (isCorrect ? Theme.success : Theme.orange).opacity(0.35), radius: 10)
        )
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
            removal: .opacity
        ))
    }
}

// MARK: - Floating XP text ("+15 XP")

struct FloatingXPView: View {
    let amount: Int
    @State private var lifted = false

    var body: some View {
        Text("+\(amount) XP")
            .font(Theme.font(18, weight: .heavy))
            .foregroundStyle(Theme.gold)
            .shadow(color: Theme.gold.opacity(0.6), radius: 6)
            .offset(y: lifted ? -60 : 0)
            .opacity(lifted ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.9)) { lifted = true }
            }
    }
}

// MARK: - Power-up button

struct PowerUpButton: View {
    let powerUp: PowerUp
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(powerUp.emoji).font(.system(size: 20))
                Text("\(count)")
                    .font(Theme.font(11, weight: .bold))
                    .foregroundStyle(count > 0 ? Theme.textPrimary : Theme.textSecondary)
            }
            .frame(width: 48, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.cardBorder))
            )
            .opacity(count > 0 ? 1 : 0.4)
        }
        .disabled(count == 0)
    }
}

// MARK: - Mode icon (uses the game art; emoji fallback)

struct ModeIconView: View {
    let mode: GameMode
    var size: CGFloat = 40

    private var artName: String {
        switch mode {
        case .wordCannon: return "cannon"
        case .wordSlice: return "word_ball"
        case .meaningFactory: return "crate"
        case .monsterBattle: return "golem"
        case .wordHuntMirror: return "magnifier_tile"
        case .wordInvaders: return "word_circuit"
        }
    }

    private var fallbackSymbol: String {
        switch mode {
        case .wordCannon: return "scope"
        case .wordSlice: return "scissors"
        case .meaningFactory: return "shippingbox.fill"
        case .monsterBattle: return "shield.lefthalf.filled"
        case .wordHuntMirror: return "magnifyingglass"
        case .wordInvaders: return "memorychip.fill"
        }
    }

    var body: some View {
        Group {
            if let art = GameAssets.image(artName) {
                art.resizable().scaledToFit()
            } else {
                Image(systemName: fallbackSymbol)
                    .font(.system(size: size * 0.44, weight: .bold))
                    .foregroundStyle(Theme.modeColor(mode))
                    .frame(width: size, height: size)
                    .background(Circle().fill(Theme.modeColor(mode).opacity(0.14)))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Instruction overlay (shown before each round)

/// Splash screen with the same arena + hero art as the game itself,
/// so menus and gameplay feel like one world.
struct InstructionOverlay: View {
    let mode: GameMode
    let onStart: () -> Void
    @State private var bob = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            ArenaBackground(mode: mode)
            LinearGradient(
                colors: [.black.opacity(0.55), .black.opacity(0.25), .black.opacity(0.65)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer()

                // Floating hero object from the game
                ModeIconView(mode: mode, size: 170)
                    .shadow(color: .black.opacity(0.5), radius: 14, y: 10)
                    .offset(y: bob ? -9 : 9)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: bob)
                    .scaleEffect(appeared ? 1 : 0.3)

                GameTitleText(text: mode.title, size: 38)

                Text(mode.instruction)
                    .font(Theme.font(17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .shadow(color: .black.opacity(0.7), radius: 3, y: 2)

                Spacer()

                Button("Başla") { onStart() }
                    .buttonStyle(PrimaryButtonStyle(color: Theme.modeColor(mode)))
                    .padding(.horizontal, 44)
                    .padding(.bottom, 46)
            }
        }
        .onAppear {
            bob = true
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.05)) {
                appeared = true
            }
        }
    }
}

// MARK: - Stat chip (home screen)

struct StatChipView: View {
    let value: String
    let label: String
    let symbol: String
    var tint: Color = Theme.accent

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(Circle().fill(tint.opacity(0.14)))
            Text(value)
                .font(Theme.font(19, weight: .heavy))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(Theme.font(10, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 2)
        .arcadePanel(cornerRadius: 16, tint: tint)
    }
}

// MARK: - Shake effect (classic SwiftUI horizontal-oscillation shake)

/// Apply with `.modifier(ShakeEffect(animatableData: ticks))`, then bump
/// `ticks` by 1 inside `withAnimation(.linear(duration: 0.4))` to trigger.
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amount * sin(animatableData * .pi * CGFloat(shakesPerUnit))
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

// MARK: - Mastery bar

struct MasteryBarView: View {
    let score: Int

    var color: Color {
        switch MasteryBand(score: score) {
        case .new: return Theme.textSecondary
        case .familiar: return Theme.accent
        case .strong: return Theme.purple
        case .mastered: return Theme.gold
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(score) / 100)
            }
        }
        .frame(height: 6)
    }
}
