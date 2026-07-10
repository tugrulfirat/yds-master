import SwiftUI

struct GameSelectView: View {
    @EnvironmentObject var store: WordStore
    var onPlay: (GameMode) -> Void

    var body: some View {
        ZStack {
            Theme.background
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    Text("Oyununu Seç")
                        .font(Theme.font(26, weight: .heavy))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.top, 24)

                    ForEach(GameMode.allCases) { mode in
                        gameCard(mode)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func gameCard(_ mode: GameMode) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ModeIconView(mode: mode, size: 44)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(Theme.modeColor(mode).opacity(0.18)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.title)
                        .font(Theme.font(19, weight: .heavy))
                        .foregroundStyle(Theme.textPrimary)
                    Text(mode.difficultyLabel)
                        .font(Theme.font(12, weight: .semibold))
                        .foregroundStyle(Theme.modeColor(mode))
                }
                Spacer()
            }

            Text(mode.shortDescription)
                .font(Theme.font(14))
                .foregroundStyle(Theme.textSecondary)

            HStack {
                Label(mode.bestFor, systemImage: "target")
                    .font(Theme.font(12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Button {
                    Haptics.medium()
                    onPlay(mode)
                } label: {
                    Text("Oyna")
                        .font(Theme.font(15, weight: .bold))
                        .foregroundStyle(Color(hex: 0x0F1222))
                        .padding(.horizontal, 26)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Theme.modeColor(mode)))
                }
            }
        }
        .padding(16)
        .cardStyle()
    }
}
