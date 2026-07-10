import SwiftUI

struct WordBankView: View {
    @EnvironmentObject var store: WordStore
    @State private var searchText = ""
    @State private var filter: BankFilter = .all
    @State private var selectedWord: Word?
    @State private var showPaywall = false

    enum BankFilter: String, CaseIterable, Identifiable {
        case all = "Tümü"
        case learned = "Öğrenilen"
        case weak = "Zayıf"
        case mastered = "Ustalaşılan"
        var id: String { rawValue }
    }

    private var filteredWords: [Word] {
        var list = store.words
        switch filter {
        case .all: break
        case .learned: list = list.filter { store.progress(for: $0).isLearned }
        case .weak: list = list.filter { store.progress(for: $0).isWeak }
        case .mastered: list = list.filter { store.progress(for: $0).isMastered }
        }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            list = list.filter {
                $0.englishWord.localizedCaseInsensitiveContains(query) ||
                $0.turkishMeaning.localizedCaseInsensitiveContains(query)
            }
        }
        return list
    }

    var body: some View {
        ZStack {
            Theme.background
            VStack(spacing: 12) {
                Text("Kelime Bankası")
                    .font(Theme.font(24, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 20)

                // Search (EN or TR)
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.textSecondary)
                    TextField("İngilizce veya Türkçe ara…", text: $searchText)
                        .font(Theme.font(16, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .autocorrectionDisabled()
                }
                .padding(12)
                .cardStyle(cornerRadius: 14)
                .padding(.horizontal, 18)

                // Filter chips
                HStack(spacing: 8) {
                    ForEach(BankFilter.allCases) { f in
                        Button {
                            Haptics.selection()
                            filter = f
                        } label: {
                            Text(chipLabel(f))
                                .font(Theme.font(13, weight: .bold))
                                .foregroundStyle(filter == f ? Color(hex: 0x0F1222) : Theme.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(filter == f ? Theme.accent : Theme.card))
                        }
                    }
                }
                .padding(.horizontal, 18)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredWords) { word in
                            if store.isLocked(word) {
                                Button {
                                    Haptics.selection()
                                    showPaywall = true
                                } label: {
                                    lockedRow(word)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button {
                                    Haptics.selection()
                                    selectedWord = word
                                } label: {
                                    wordRow(word)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if filteredWords.isEmpty {
                            Text("Kelime bulunamadı")
                                .font(Theme.font(15))
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.top, 40)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .sheet(item: $selectedWord) { word in
            WordDetailSheet(word: word)
                .environmentObject(store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    private func chipLabel(_ f: BankFilter) -> String {
        switch f {
        case .all: return "Tümü (\(store.words.count))"
        case .learned: return "Öğrenilen (\(store.learnedCount))"
        case .weak: return "Zayıf (\(store.weakCount))"
        case .mastered: return "Ustalaşılan (\(store.masteredCount))"
        }
    }

    /// Premium words show the English word but blur the meaning — enough to
    /// see what's inside, not enough to study without subscribing.
    private func lockedRow(_ word: Word) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(word.englishWord)
                    .font(Theme.font(17, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary.opacity(0.75))
                Text(word.turkishMeaning)
                    .font(Theme.font(15, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .blur(radius: 5)
                    .accessibilityHidden(true)
            }
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.gold)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.card.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.gold.opacity(0.25))
                )
        )
    }

    private func wordRow(_ word: Word) -> some View {
        let progress = store.progress(for: word)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(word.englishWord)
                    .font(Theme.font(17, weight: .heavy))
                    .foregroundStyle(progress.isMastered ? Theme.gold : Theme.textPrimary)
                Text(word.partOfSpeech.shortLabel)
                    .font(Theme.font(10, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                Spacer()
                if progress.isWeak {
                    Text("⚠️ zayıf")
                        .font(Theme.font(11, weight: .bold))
                        .foregroundStyle(Theme.danger)
                }
                if progress.isMastered {
                    Text("🏅")
                }
            }
            Text(word.turkishMeaning)
                .font(Theme.font(15, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 8) {
                MasteryBarView(score: progress.masteryScore)
                Text(progress.band.title)
                    .font(Theme.font(11, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 62, alignment: .trailing)
                Image(systemName: "chevron.right")
                    .font(Theme.font(11, weight: .heavy))
                    .foregroundStyle(Theme.textSecondary.opacity(0.65))
            }
        }
        .padding(14)
        .cardStyle(cornerRadius: 16)
    }
}

private struct WordDetailSheet: View {
    @EnvironmentObject var store: WordStore
    let word: Word

    private var progress: WordProgress { store.progress(for: word) }

    var body: some View {
        ZStack {
            Theme.background
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    if hasRealExample {
                        exampleSection
                    }
                    metaGrid
                    if !word.synonyms.isEmpty {
                        chipSection(title: "Eş anlamlılar", symbol: "arrow.triangle.branch", tint: Theme.success, values: word.synonyms)
                    }
                    if !word.confusingWords.isEmpty {
                        chipSection(title: "Karışan kelimeler", symbol: "exclamationmark.triangle.fill", tint: Theme.orange, values: word.confusingWords)
                    }
                    masterySection
                }
                .padding(.horizontal, 18)
                .padding(.top, 22)
                .padding(.bottom, 28)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(word.englishWord)
                    .font(Theme.font(30, weight: .heavy))
                    .foregroundStyle(progress.isMastered ? Theme.gold : Theme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(word.partOfSpeech.shortLabel)
                    .font(Theme.font(11, weight: .heavy))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.accent.opacity(0.14)))
                Spacer()
            }
            Text(word.turkishMeaning)
                .font(Theme.font(20, weight: .bold))
                .foregroundStyle(Theme.textPrimary.opacity(0.9))
            Text(word.partOfSpeech.turkishName)
                .font(Theme.font(13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(16)
        .cardStyle(cornerRadius: 18)
    }

    private var exampleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Örnek cümle", symbol: "quote.opening", tint: Theme.accent)
            Text(word.exampleSentenceEN)
                .font(Theme.font(17, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Divider().overlay(Color.white.opacity(0.08))
            Text(word.exampleSentenceTR)
                .font(Theme.font(15, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .cardStyle(cornerRadius: 18)
    }

    private var hasRealExample: Bool {
        let sentence = word.exampleSentenceEN
        return !sentence.hasPrefix("In academic reading,")
            && !sentence.hasPrefix("In academic texts,")
            && !sentence.hasPrefix("The report explains how")
    }

    private var metaGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metricTile("YDS sıra", value: "#\(word.ydsFrequencyRank)", symbol: "number", tint: Theme.gold)
            metricTile("Zorluk", value: difficultyText, symbol: "gauge.with.dots.needle.67percent", tint: Theme.purple)
            metricTile("Kategori", value: categoryText, symbol: "folder.fill", tint: Theme.teal)
            metricTile("Ustalık", value: "\(progress.masteryScore)%", symbol: "chart.line.uptrend.xyaxis", tint: Theme.success)
        }
    }

    private var masterySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Öğrenme durumu", symbol: "sparkline", tint: Theme.success)
            HStack(spacing: 10) {
                MasteryBarView(score: progress.masteryScore)
                Text(progress.band.title)
                    .font(Theme.font(13, weight: .heavy))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 82, alignment: .trailing)
            }
            HStack(spacing: 8) {
                miniStat("Görüldü", "\(progress.timesSeen)")
                miniStat("Doğru", "\(progress.timesCorrect)")
                miniStat("Yanlış", "\(progress.timesWrong)")
            }
        }
        .padding(16)
        .cardStyle(cornerRadius: 18)
    }

    private func chipSection(title: String, symbol: String, tint: Color, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(title, symbol: symbol, tint: tint)
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(values, id: \.self) { value in
                    Text(value)
                        .font(Theme.font(13, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(tint.opacity(0.16)))
                        .overlay(Capsule().stroke(tint.opacity(0.32), lineWidth: 1))
                }
            }
        }
        .padding(16)
        .cardStyle(cornerRadius: 18)
    }

    private func sectionLabel(_ title: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(Theme.font(13, weight: .heavy))
                .foregroundStyle(tint)
            Text(title)
                .font(Theme.font(13, weight: .heavy))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func metricTile(_ title: String, value: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: symbol)
                .font(Theme.font(15, weight: .heavy))
                .foregroundStyle(tint)
            Text(value)
                .font(Theme.font(16, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(Theme.font(11, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .cardStyle(cornerRadius: 14)
    }

    private func miniStat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(Theme.font(15, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
            Text(title)
                .font(Theme.font(10, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.06)))
    }

    private var difficultyText: String {
        switch word.difficultyLevel {
        case .beginner: return "Kolay"
        case .intermediate: return "Orta"
        case .advanced: return "İleri"
        }
    }

    private var categoryText: String {
        word.category
            .split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        let rows = arrangedRows(maxWidth: maxWidth, subviews: subviews)
        let height = rows.reduce(CGFloat.zero) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * lineSpacing
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrangedRows(maxWidth: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private func arrangedRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentItems: [RowItem] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = currentItems.isEmpty ? size.width : currentWidth + spacing + size.width
            if nextWidth > maxWidth, !currentItems.isEmpty {
                rows.append(Row(items: currentItems, height: currentHeight))
                currentItems = [RowItem(index: index, size: size)]
                currentWidth = size.width
                currentHeight = size.height
            } else {
                currentItems.append(RowItem(index: index, size: size))
                currentWidth = nextWidth
                currentHeight = max(currentHeight, size.height)
            }
        }
        if !currentItems.isEmpty {
            rows.append(Row(items: currentItems, height: currentHeight))
        }
        return rows
    }

    private struct Row {
        let items: [RowItem]
        let height: CGFloat
    }

    private struct RowItem {
        let index: Int
        let size: CGSize
    }
}
