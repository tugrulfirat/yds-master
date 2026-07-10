import SwiftUI

/// The dedicated progress dashboard: level & XP, learning funnel across
/// mastery bands, CEFR-level breakdown of the full word database, play
/// stats, and the badge collection. Opened by tapping the stats row on the
/// home screen.
struct ProgressDashboardView: View {
    @EnvironmentObject var store: WordStore

    var body: some View {
        ZStack {
            Theme.background
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    Text("İlerleme")
                        .font(Theme.font(24, weight: .heavy))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.top, 20)

                    levelCard
                    playStatsRow
                    masteryFunnelCard
                    cefrCard
                    badgesCard
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
    }

    // MARK: Level & XP

    private var xpIntoCurrentLevel: (current: Int, needed: Int) {
        var lvl = 1
        var remaining = store.profile.xp
        while remaining >= UserProfile.xpNeeded(forLevel: lvl) {
            remaining -= UserProfile.xpNeeded(forLevel: lvl)
            lvl += 1
        }
        return (remaining, UserProfile.xpNeeded(forLevel: lvl))
    }

    private var levelCard: some View {
        let xp = xpIntoCurrentLevel
        return VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Seviye \(store.profile.level)")
                    .font(Theme.font(26, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("\(store.profile.streak) gün")
                        .font(Theme.font(14, weight: .bold))
                }
                .foregroundStyle(Theme.orange)
            }
            progressBar(fraction: store.profile.levelProgress, tint: Theme.gold, height: 10)
            HStack {
                Text("\(xp.current) / \(xp.needed) XP")
                    .font(Theme.font(12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("Sonraki seviyeye \(xp.needed - xp.current) XP")
                    .font(Theme.font(12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(16)
        .arcadePanel(cornerRadius: 18, tint: Theme.gold)
    }

    // MARK: Play stats

    private var playStatsRow: some View {
        HStack(spacing: 10) {
            StatChipView(value: "\(store.profile.roundsPlayed)", label: "Oynanan Tur", symbol: "gamecontroller.fill", tint: Theme.accent)
            StatChipView(value: "×\(store.profile.bestCombo)", label: "En İyi Kombo", symbol: "bolt.fill", tint: Theme.orange)
            StatChipView(value: "\(store.masteredCount)", label: "Ustalaşılan", symbol: "medal.fill", tint: Theme.gold)
        }
    }

    // MARK: Mastery funnel

    private struct BandStat: Identifiable {
        let band: MasteryBand
        let count: Int
        var id: String { band.rawValue }
    }

    private var bandStats: [BandStat] {
        var counts: [MasteryBand: Int] = [:]
        for word in store.words {
            let p = store.progress(for: word)
            guard p.timesSeen > 0 else { continue }
            counts[p.band, default: 0] += 1
        }
        return MasteryBand.allCases.map { BandStat(band: $0, count: counts[$0] ?? 0) }
    }

    private func bandColor(_ band: MasteryBand) -> Color {
        switch band {
        case .new: return Theme.textSecondary
        case .familiar: return Theme.accent
        case .strong: return Theme.purple
        case .mastered: return Theme.gold
        }
    }

    private var masteryFunnelCard: some View {
        let stats = bandStats
        let seen = stats.reduce(0) { $0 + $1.count }
        let maxCount = max(1, stats.map(\.count).max() ?? 1)
        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Öğrenme Durumu", symbol: "chart.bar.fill")
            ForEach(stats) { stat in
                HStack(spacing: 10) {
                    Text(stat.band.title)
                        .font(Theme.font(13, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 86, alignment: .leading)
                    progressBar(
                        fraction: Double(stat.count) / Double(maxCount),
                        tint: bandColor(stat.band),
                        height: 8
                    )
                    Text("\(stat.count)")
                        .font(Theme.font(13, weight: .heavy))
                        .foregroundStyle(bandColor(stat.band))
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
            }
            Text("Henüz çalışılmadı: \(store.words.count - seen) kelime")
                .font(Theme.font(12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(16)
        .arcadePanel(cornerRadius: 18, tint: Theme.accent)
    }

    // MARK: CEFR breakdown

    private struct CEFRStat: Identifiable {
        let level: String
        let learned: Int
        let total: Int
        var id: String { level }
    }

    private var cefrStats: [CEFRStat] {
        let order = ["A1", "A2", "B1", "B2", "C1", "C2"]
        var learned: [String: Int] = [:]
        var total: [String: Int] = [:]
        var otherLearned = 0
        var otherTotal = 0

        for word in store.words {
            let bucket: String?
            if word.category.hasPrefix("cefr-") {
                let level = String(word.category.dropFirst(5)).uppercased()
                bucket = order.contains(level) ? level : nil
            } else {
                bucket = nil
            }
            let isLearned = store.progress(for: word).isLearned
            if let bucket {
                total[bucket, default: 0] += 1
                if isLearned { learned[bucket, default: 0] += 1 }
            } else {
                otherTotal += 1
                if isLearned { otherLearned += 1 }
            }
        }

        var stats = order.compactMap { level -> CEFRStat? in
            guard let t = total[level], t > 0 else { return nil }
            return CEFRStat(level: level, learned: learned[level] ?? 0, total: t)
        }
        if otherTotal > 0 {
            stats.append(CEFRStat(level: "Diğer", learned: otherLearned, total: otherTotal))
        }
        return stats
    }

    private var cefrCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Seviyeye Göre Kelimeler", symbol: "square.stack.3d.up.fill")
            ForEach(cefrStats) { stat in
                HStack(spacing: 10) {
                    Text(stat.level)
                        .font(Theme.font(13, weight: .heavy))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 44, alignment: .leading)
                    progressBar(
                        fraction: Double(stat.learned) / Double(max(1, stat.total)),
                        tint: Theme.teal,
                        height: 8
                    )
                    Text("\(stat.learned)/\(stat.total)")
                        .font(Theme.font(12, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .monospacedDigit()
                        .frame(width: 76, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .arcadePanel(cornerRadius: 18, tint: Theme.teal)
    }

    // MARK: Badges

    private func badgeSymbol(_ id: String) -> String {
        switch id {
        case "first-round": return "flag.checkered"
        case "streak-3": return "flame"
        case "streak-7": return "flame.fill"
        case "mastered-10": return "medal.fill"
        case "combo-8": return "bolt.fill"
        case "boss-slayer": return "trophy.fill"
        case "mission-complete": return "checkmark.seal.fill"
        default: return "star.fill"
        }
    }

    private var badgesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Rozetler", symbol: "rosette")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                ForEach(Badge.all) { badge in
                    let earned = store.profile.earnedBadgeIDs.contains(badge.id)
                    HStack(spacing: 10) {
                        Image(systemName: badgeSymbol(badge.id))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(earned ? Theme.gold : Theme.textSecondary.opacity(0.5))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle().fill((earned ? Theme.gold : Color.white).opacity(earned ? 0.16 : 0.05))
                            )
                        Text(badge.title)
                            .font(Theme.font(12, weight: .bold))
                            .foregroundStyle(earned ? Theme.textPrimary : Theme.textSecondary.opacity(0.6))
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.card.opacity(earned ? 1 : 0.55))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(earned ? Theme.gold.opacity(0.35) : Theme.cardBorder)
                            )
                    )
                }
            }
        }
        .padding(16)
        .arcadePanel(cornerRadius: 18, tint: Theme.gold)
    }

    // MARK: Shared pieces

    private func sectionTitle(_ text: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
            Text(text)
                .font(Theme.font(16, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
        }
    }

    private func progressBar(fraction: Double, tint: Color, height: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(tint)
                    .frame(width: geo.size.width * min(1, max(0, fraction)))
            }
        }
        .frame(height: height)
    }
}
