import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var store: WordStore

    @State private var page = 0
    @State private var goal = 20
    @State private var difficulty: DifficultyLevel = .beginner
    @State private var direction: DirectionPreference = .mixed

    private let goals = [10, 20, 30, 50]

    var body: some View {
        ZStack {
            Theme.background
            VStack(spacing: 0) {
                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(i <= page ? Theme.accent : Color.white.opacity(0.15))
                            .frame(width: i == page ? 28 : 10, height: 6)
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: page)
                    }
                }
                .padding(.top, 24)

                TabView(selection: $page) {
                    conceptPage.tag(0)
                    goalAndDifficultyPage.tag(1)
                    directionPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                Button(page < 2 ? "Devam Et" : "Oynamaya Başla") {
                    Haptics.medium()
                    if page < 2 {
                        withAnimation { page += 1 }
                    } else {
                        store.completeOnboarding(goal: goal, difficulty: difficulty, direction: direction)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: Page 1 — concept

    private var conceptPage: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("🎯⚔️🏭👾")
                .font(.system(size: 52))
            GameTitleText(text: "YDS Master", size: 42)
            Text("Hızlı ve keyifli kelime oyunlarıyla YDS kelime dağarcığını öğren.")
                .font(Theme.font(19, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            VStack(alignment: .leading, spacing: 14) {
                conceptRow("🎯", "Kelimeleri anlam hedeflerine fırlat")
                conceptRow("⚔️", "Doğru kelimeyi havada keserek yakala")
                conceptRow("🏭", "Kelimeleri fabrika bandında sırala")
                conceptRow("👾", "Kelime bilginle canavarları yen")
            }
            .padding(20)
            .cardStyle()
            .padding(.horizontal, 28)
            Spacer()
            Spacer()
        }
    }

    private func conceptRow(_ emoji: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text(emoji)
            Text(text)
                .font(Theme.font(15, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
        }
    }

    // MARK: Page 2 — goal & difficulty

    private var goalAndDifficultyPage: some View {
        VStack(spacing: 26) {
            Spacer()
            VStack(spacing: 8) {
                Text("Günlük hedef")
                    .font(Theme.font(26, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                Text("Günde kaç kelime öğrenmek istersin?")
                    .font(Theme.font(15))
                    .foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: 12) {
                ForEach(goals, id: \.self) { g in
                    selectableChip("\(g)", isSelected: goal == g) { goal = g }
                }
            }
            .padding(.horizontal, 28)

            VStack(spacing: 8) {
                Text("Başlangıç seviyesi")
                    .font(Theme.font(26, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(.top, 12)
            VStack(spacing: 10) {
                ForEach(DifficultyLevel.allCases, id: \.self) { level in
                    selectableRow(level.title, isSelected: difficulty == level) { difficulty = level }
                }
            }
            .padding(.horizontal, 28)
            Spacer()
            Spacer()
        }
    }

    // MARK: Page 3 — direction

    private var directionPage: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Nasıl oynamak istersin?")
                .font(Theme.font(26, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            VStack(spacing: 12) {
                ForEach(DirectionPreference.allCases) { pref in
                    Button {
                        Haptics.selection()
                        direction = pref
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pref.title)
                                .font(Theme.font(17, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                            Text(pref.subtitle)
                                .font(Theme.font(13))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Theme.card)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(direction == pref ? Theme.accent : Theme.cardBorder,
                                                lineWidth: direction == pref ? 2 : 1)
                                )
                        )
                    }
                }
            }
            .padding(.horizontal, 28)
            Spacer()
            Spacer()
        }
    }

    // MARK: Selection helpers

    private func selectableChip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Text(label)
                .font(Theme.font(20, weight: .heavy))
                .foregroundStyle(isSelected ? Color(hex: 0x0F1222) : Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isSelected ? Theme.accent : Theme.card)
                )
        }
    }

    private func selectableRow(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack {
                Text(label)
                    .font(Theme.font(17, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? Theme.accent : Theme.cardBorder, lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
    }
}
