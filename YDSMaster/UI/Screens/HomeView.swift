import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: WordStore
    @EnvironmentObject var premium: PremiumStore
    @State private var launch: GameLaunch?
    @State private var showWordBank = false
    @State private var showProgress = false
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            Theme.background
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    headerBar
                    dailyMissionCard
                    statsRow
                    wordBankCard
                    modeGrid
                    secondaryButtons
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
        .fullScreenCover(item: $launch) { launch in
            GameHostView(mode: launch.mode, kind: launch.kind)
        }
        .sheet(isPresented: $showWordBank) { WordBankView() }
        .sheet(isPresented: $showProgress) { ProgressDashboardView() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .onAppear {
            store.refreshDailyMissionIfNeeded()
            SoundManager.shared.playMusic(.menu)
            #if DEBUG
            // Debug hook: SIMCTL_CHILD_YDS_AUTOSTART=<mode> jumps straight
            // into a round (used by automated visual checks). Compiled out
            // of release builds entirely.
            if launch == nil,
               let raw = ProcessInfo.processInfo.environment["YDS_AUTOSTART"],
               let mode = GameMode(rawValue: raw) {
                launch = GameLaunch(mode: mode, kind: .freePlay)
            }
            #endif
        }
    }

    // MARK: Header — streak, level, XP

    private var headerBar: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                GameTitleText(text: "YDS Master", size: 30)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("Seviye \(store.profile.level) • \(store.profile.xp) XP")
                    .font(Theme.font(13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            audioToggle(symbol: "music.note", enabled: store.profile.musicEnabled) {
                store.toggleMusic()
            }
            audioToggle(symbol: "speaker.wave.2.fill", enabled: store.profile.soundEnabled) {
                store.toggleSound()
            }
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.orange)
                Text("\(store.profile.streak)")
                    .font(Theme.font(20, weight: .heavy))
                    .foregroundStyle(Theme.orange)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .cardStyle(cornerRadius: 14)
        }
        .padding(.top, 8)
    }

    /// Compact music / sound-effect mute button. A diagonal slash overlay
    /// marks the muted state so both toggles read the same way.
    private func audioToggle(symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(enabled ? Theme.accent : Theme.textSecondary.opacity(0.45))
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.card))
                .overlay {
                    if !enabled {
                        Rectangle()
                            .fill(Theme.textSecondary.opacity(0.6))
                            .frame(width: 2, height: 22)
                            .rotationEffect(.degrees(45))
                    }
                }
        }
    }

    // MARK: Daily mission

    private var dailyMissionCard: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Günlük Görev")
                        .font(Theme.font(20, weight: .heavy))
                        .foregroundStyle(Theme.textPrimary)
                    Text(missionSubtitle)
                        .font(Theme.font(13))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if store.profile.dailyMission.isComplete {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Theme.success)
                }
            }

            // Mission step icons
            HStack(spacing: 10) {
                ForEach(DailyMissionState.steps) { step in
                    let done = store.profile.dailyMission.completedModes.contains(step)
                    VStack(spacing: 4) {
                        ModeIconView(mode: step, size: 34)
                            .frame(width: 52, height: 52)
                            .background(
                                Circle()
                                    .fill(done ? Theme.modeColor(step).opacity(0.25) : Color.white.opacity(0.06))
                                    .overlay(Circle().stroke(done ? Theme.modeColor(step) : Theme.cardBorder, lineWidth: 2))
                            )
                            .opacity(done ? 1 : 0.75)
                        Image(systemName: done ? "checkmark.circle.fill" : "circle.dotted")
                            .font(.system(size: 12))
                            .foregroundStyle(done ? Theme.success : Theme.textSecondary)
                    }
                    if step != DailyMissionState.steps.last {
                        Rectangle()
                            .fill(done ? Theme.success.opacity(0.5) : Color.white.opacity(0.1))
                            .frame(height: 2)
                    }
                }
            }

            if !store.profile.dailyMission.isComplete {
                Button {
                    Haptics.medium()
                    if let next = store.profile.dailyMission.nextStep {
                        launch = GameLaunch(mode: next, kind: .dailyMission)
                    }
                } label: {
                    Text("Bugünkü Göreve Başla")
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Text("Görev tamamlandı! +100 XP bonus kazandın")
                    .font(Theme.font(14, weight: .bold))
                    .foregroundStyle(Theme.gold)
            }
        }
        .padding(18)
        .arcadePanel(cornerRadius: 20, tint: Theme.accent)
    }

    private var missionSubtitle: String {
        let done = store.profile.dailyMission.completedModes.count
        let total = DailyMissionState.steps.count
        if done == 0 { return "Yeni kelimeler, tekrar ve bir boss savaşı seni bekliyor" }
        if done < total { return "\(done)/\(total) oyun tamamlandı — devam et!" }
        return "Bugünkü \(total) oyunun tamamı bitti"
    }

    // MARK: Stats

    /// Tapping the stats row opens the full progress dashboard.
    private var statsRow: some View {
        Button {
            Haptics.light()
            showProgress = true
        } label: {
            statChips
        }
        .buttonStyle(.plain)
    }

    private var statChips: some View {
        HStack(spacing: 10) {
            StatChipView(value: "\(store.learnedCount)", label: "Öğrenilen", symbol: "book.fill", tint: Theme.success)
            StatChipView(value: "\(store.weakCount)", label: "Zayıf Kelime", symbol: "exclamationmark.triangle.fill", tint: Theme.danger)
            StatChipView(value: "\(store.masteredCount)", label: "Ustalaşılan", symbol: "medal.fill", tint: Theme.gold)
            StatChipView(value: "\(Int(store.overallMastery * 100))%", label: "İlerleme", symbol: "chart.line.uptrend.xyaxis", tint: Theme.accent)
        }
    }

    // MARK: Word bank

    /// Kelime Bankası is the core reference for every word in the game, so it
    /// gets a full-width banner rather than being buried in the secondary list.
    private var wordBankCard: some View {
        Button {
            Haptics.light()
            showWordBank = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.accent.opacity(0.18)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kelime Bankası")
                        .font(Theme.font(17, weight: .heavy))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(store.words.count) kelime • tümünü ara ve incele")
                        .font(Theme.font(12, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(14)
            .arcadePanel(cornerRadius: 20, tint: Theme.accent)
        }
    }

    // MARK: Game modes

    private var modeGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
            ForEach(GameMode.allCases) { mode in
                Button {
                    Haptics.light()
                    launch = GameLaunch(mode: mode, kind: .freePlay)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        ModeIconView(mode: mode, size: 52)
                        Text(mode.title)
                            .font(Theme.font(16, weight: .heavy))
                            .foregroundStyle(Theme.textPrimary)
                            .multilineTextAlignment(.leading)
                        Text(mode.bestFor)
                            .font(Theme.font(11, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
                    .padding(14)
                    .arcadePanel(cornerRadius: 20, tint: Theme.modeColor(mode))
                    .shadow(color: Theme.modeColor(mode).opacity(0.25), radius: 8, y: 4)
                }
            }
        }
    }

    // MARK: Secondary

    private var secondaryButtons: some View {
        VStack(spacing: 10) {
            if !store.isPremium {
                Button {
                    Haptics.medium()
                    showPaywall = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.gold)
                            .frame(width: 24)
                        Text("Premium'a Geç")
                        Spacer()
                        Text("\(store.words.count.formatted()) kelimenin tamamı")
                            .font(Theme.font(12, weight: .semibold))
                            .foregroundStyle(Theme.gold)
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            Button {
                Haptics.light()
                launch = GameLaunch(mode: .monsterBattle, kind: .weakWords)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.danger)
                        .frame(width: 24)
                    Text("Zayıf Kelimeler")
                    Spacer()
                    Text("\(store.weakCount)")
                        .foregroundStyle(Theme.danger)
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(store.weakCount == 0)
            .opacity(store.weakCount == 0 ? 0.5 : 1)
        }
    }
}
