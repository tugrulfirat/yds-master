import SwiftUI

struct ResultView: View {
    @EnvironmentObject var store: WordStore
    let result: GameResult
    var onPlayAgain: () -> Void
    var onContinue: () -> Void

    @State private var appeared = false

    private var headline: String {
        switch result.accuracy {
        case 0.9...: return "Muhteşem! 🌟"
        case 0.7..<0.9: return "Harika tur! 💪"
        case 0.5..<0.7: return "İyi çaba! 📈"
        default: return "Devam et! 🎯"
        }
    }

    var body: some View {
        ZStack {
            // Same arena as the round just played — one visual world.
            ArenaBackground(mode: result.mode)
            LinearGradient(
                colors: [.black.opacity(0.72), .black.opacity(0.6), .black.opacity(0.78)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    ModeIconView(mode: result.mode, size: 88)
                        .shadow(color: .black.opacity(0.5), radius: 10, y: 6)
                        .scaleEffect(appeared ? 1 : 0.3)
                    GameTitleText(text: headline, size: 32)

                    // Score + XP banner
                    VStack(spacing: 4) {
                        Text("Skor")
                            .font(Theme.font(13, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                        Text(result.score.formatted())
                            .font(Theme.font(44, weight: .heavy))
                            .foregroundStyle(Theme.textPrimary)
                            .monospacedDigit()
                        Text("+\(result.xpEarned + result.missionBonusXP) XP")
                            .font(Theme.font(24, weight: .heavy))
                            .foregroundStyle(Theme.gold)
                            .monospacedDigit()
                        if result.missionBonusXP > 0 {
                            Text("+\(result.missionBonusXP) görev bonusu dahil 🚀")
                                .font(Theme.font(13, weight: .bold))
                                .foregroundStyle(Theme.gold.opacity(0.8))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .cardStyle()

                    // Stats grid
                    HStack(spacing: 10) {
                        StatChipView(value: "\(result.correctCount)", label: "Doğru", symbol: "checkmark", tint: Theme.success)
                        StatChipView(value: "\(result.wrongCount)", label: "Yanlış", symbol: "xmark", tint: Theme.danger)
                        StatChipView(value: "×\(result.maxCombo)", label: "En İyi Kombo", symbol: "flame.fill", tint: Theme.orange)
                    }

                    if !result.newlyMasteredWords.isEmpty {
                        wordListCard(
                            title: "Yeni Ustalaşılan ✨",
                            tint: Theme.gold,
                            words: result.newlyMasteredWords
                        )
                    }

                    if !result.weakWords.isEmpty {
                        wordListCard(
                            title: "Tekrar Gerekiyor ⚠️",
                            tint: Theme.danger,
                            words: result.weakWords
                        )
                    }

                    wordListCard(
                        title: "Çalışılan Kelimeler (\(result.practicedWords.count))",
                        tint: Theme.accent,
                        words: result.practicedWords
                    )

                    VStack(spacing: 10) {
                        Button("Devam Et") {
                            Haptics.light()
                            onContinue()
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button("Tekrar Oyna") {
                            Haptics.medium()
                            onPlayAgain()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 28)
            }
        }
        .onAppear {
            SoundManager.shared.play(.victory)
            Haptics.success()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.1)) {
                appeared = true
            }
        }
    }

    private func wordListCard(title: String, tint: Color, words: [Word]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.font(15, weight: .heavy))
                .foregroundStyle(tint)
            ForEach(words) { word in
                HStack {
                    Text(word.englishWord)
                        .font(Theme.font(15, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("=")
                        .foregroundStyle(Theme.textSecondary)
                    Text(word.turkishMeaning)
                        .font(Theme.font(15, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("\(store.progress(for: word).masteryScore)")
                        .font(Theme.font(13, weight: .bold))
                        .foregroundStyle(tint)
                        .monospacedDigit()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle()
    }
}
