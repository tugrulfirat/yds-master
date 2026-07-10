import SwiftUI

/// A single letter-grid coordinate. File-scoped (not nested) so both the
/// view and its PreferenceKey below can reference it.
private struct GridCoordinate: Hashable {
    let row: Int
    let col: Int
}

/// Classic newspaper word search: ONE grid hides several words at once
/// (the current puzzle's chunk of session questions). The clue list shows
/// each word's other-language side; the player traces any hidden answer in
/// a straight line, in any order, forwards or backwards. Found words get a
/// marker stroke through the grid and their clue struck through — the grid
/// is only rebuilt when every word in it has been found, never per word.
struct WordHuntMirrorView: View {
    @ObservedObject var session: GameSession
    var onRoundEnd: () -> Void

    /// Words hidden per grid. Small enough to keep the grid readable,
    /// large enough to feel like a real puzzle.
    private static let puzzleCapacity = 4

    private struct PuzzleTarget: Identifiable {
        let wordID: Int
        let prompt: String
        /// Normalized (uppercased, spaces stripped) hidden answer.
        let answer: String
        var id: Int { wordID }
    }

    private struct PuzzleLayout {
        var letters: [[Character]]
        var size: Int
        /// wordID → the cells its answer occupies.
        var placements: [Int: [GridCoordinate]]
    }

    @State private var grid: [[Character]] = []
    @State private var gridSize: Int = 7
    @State private var targets: [PuzzleTarget] = []
    @State private var placements: [Int: [GridCoordinate]] = [:]
    @State private var foundWordIDs: Set<Int> = []
    @State private var foundPaths: [[GridCoordinate]] = []

    @State private var cellFrames: [GridCoordinate: CGRect] = [:]
    @State private var selectedPath: [GridCoordinate] = []
    @State private var pathDirection: (dr: Int, dc: Int)?
    @State private var resolving = false

    @State private var pathShakeTicks: CGFloat = 0
    @State private var pathIsWrong = false
    @State private var hintCoordinate: GridCoordinate?

    @State private var reveal: (text: String, correct: Bool)?
    @State private var revealToken = UUID()
    @State private var xpFloat: Int?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ArenaBackground(mode: .wordHuntMirror)

                VStack(spacing: 0) {
                    GameHeaderView(session: session, accent: Theme.modeColor(.wordHuntMirror)) {
                        onRoundEnd()
                    }
                    .padding(.top, 8)

                    clueList
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .allowsHitTesting(false)

                    HStack {
                        if let reveal {
                            RevealTrayView(text: reveal.text, isCorrect: reveal.correct)
                        }
                        if let xpFloat {
                            FloatingXPView(amount: xpFloat).id(xpFloat)
                        }
                    }
                    .frame(height: 44)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: reveal?.text)
                    .allowsHitTesting(false)

                    Spacer(minLength: 4)

                    // Grid is populated in onAppear; guard the very first
                    // render (same pattern Cannon/Slice use for their scene).
                    if !grid.isEmpty {
                        gridView(availableWidth: geo.size.width - 32)
                            .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 4)

                    HStack(spacing: 10) {
                        PowerUpButton(powerUp: .firstLetter, count: session.store.powerUpCount(.firstLetter)) {
                            useHint()
                        }
                        PowerUpButton(powerUp: .shield, count: session.store.powerUpCount(.shield)) {
                            if session.useShield() { Haptics.selection() }
                        }
                        Spacer()
                        Text("Sürükleyerek kelimeyi çiz")
                            .font(Theme.font(11, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
            .coordinateSpace(name: "wordhunt")
            .onAppear {
                if grid.isEmpty { loadNextPuzzle() }
            }
            .onPreferenceChange(GridCellFramePreferenceKey.self) { cellFrames = $0 }
        }
    }

    // MARK: Clue list

    private var clueList: some View {
        VStack(spacing: 8) {
            Text("Karşılıklarını ızgarada bul:")
                .font(Theme.font(12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
                ForEach(targets) { target in
                    let found = foundWordIDs.contains(target.wordID)
                    Text(target.prompt)
                        .font(Theme.font(14, weight: .bold))
                        .strikethrough(found, color: Theme.teal)
                        .foregroundStyle(found ? Theme.textSecondary : Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Theme.card.opacity(found ? 0.5 : 1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(found ? Theme.teal.opacity(0.4) : Theme.cardBorder)
                                )
                        )
                        .animation(.easeOut(duration: 0.25), value: found)
                }
            }
        }
    }

    // MARK: Grid rendering

    private func gridView(availableWidth: CGFloat) -> some View {
        let spacing: CGFloat = 5
        let cellSize = min(46, max(22, (availableWidth - spacing * CGFloat(gridSize - 1)) / CGFloat(gridSize)))

        return ZStack {
            VStack(spacing: spacing) {
                ForEach(0..<gridSize, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<gridSize, id: \.self) { col in
                            cellView(row: row, col: col, cellSize: cellSize)
                        }
                    }
                }
            }
            strikeOverlay(cellSize: cellSize, spacing: spacing)
                .allowsHitTesting(false)
        }
        .gesture(dragGesture)
    }

    /// Newspaper-style marker strokes across every found word.
    private func strikeOverlay(cellSize: CGFloat, spacing: CGFloat) -> some View {
        func center(_ coord: GridCoordinate) -> CGPoint {
            CGPoint(
                x: CGFloat(coord.col) * (cellSize + spacing) + cellSize / 2,
                y: CGFloat(coord.row) * (cellSize + spacing) + cellSize / 2
            )
        }
        let side = cellSize * CGFloat(gridSize) + spacing * CGFloat(gridSize - 1)
        return Canvas { context, _ in
            for path in foundPaths {
                guard let first = path.first, let last = path.last else { continue }
                var line = Path()
                line.move(to: center(first))
                line.addLine(to: center(last))
                context.stroke(
                    line,
                    with: .color(Theme.teal.opacity(0.42)),
                    style: StrokeStyle(lineWidth: cellSize * 0.52, lineCap: .round)
                )
            }
        }
        .frame(width: side, height: side)
    }

    private func cellView(row: Int, col: Int, cellSize: CGFloat) -> some View {
        let coord = GridCoordinate(row: row, col: col)
        let isSelected = selectedPath.contains(coord)
        let isHint = hintCoordinate == coord

        return Text(String(grid[row][col]))
            .font(.system(size: cellSize * 0.42, weight: .heavy, design: .rounded))
            .foregroundStyle(isSelected ? Color(hex: 0x0F1222) : Theme.textPrimary)
            .frame(width: cellSize, height: cellSize)
            .background(
                RoundedRectangle(cornerRadius: cellSize * 0.22, style: .continuous)
                    .fill(isSelected ? (pathIsWrong ? Theme.danger : Theme.teal) : Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: cellSize * 0.22, style: .continuous)
                            .stroke(isHint ? Theme.gold : Theme.cardBorder, lineWidth: isHint ? 2 : 1)
                    )
            )
            .modifier(ShakeEffect(animatableData: isSelected ? pathShakeTicks : 0))
            .background(
                GeometryReader { g in
                    Color.clear.preference(
                        key: GridCellFramePreferenceKey.self,
                        value: [coord: g.frame(in: .named("wordhunt"))]
                    )
                }
            )
    }

    // MARK: Drag tracing

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("wordhunt"))
            .onChanged { value in handleDrag(at: value.location) }
            .onEnded { _ in handleDragEnd() }
    }

    private func handleDrag(at location: CGPoint) {
        guard !resolving else { return }
        guard let coord = cellFrames.first(where: { $0.value.contains(location) })?.key else { return }

        if selectedPath.isEmpty {
            selectedPath = [coord]
            pathIsWrong = false
            return
        }

        guard !selectedPath.contains(coord) else { return }

        if selectedPath.count == 1 {
            let dr = coord.row - selectedPath[0].row
            let dc = coord.col - selectedPath[0].col
            guard (abs(dr) == 1 && dc == 0) || (dr == 0 && abs(dc) == 1) else { return }
            pathDirection = (dr, dc)
            selectedPath.append(coord)
        } else {
            guard let dir = pathDirection, let last = selectedPath.last else { return }
            let expected = GridCoordinate(row: last.row + dir.dr, col: last.col + dir.dc)
            guard coord == expected else { return }
            selectedPath.append(coord)
        }
    }

    /// Release resolves the trace: matching any unfound answer (forwards or
    /// backwards) marks it found; anything else just shakes and clears —
    /// mis-traces cost time, not hearts, exactly like on paper.
    private func handleDragEnd() {
        guard !resolving else { return }
        defer {
            if !resolving {
                selectedPath = []
                pathDirection = nil
            }
        }
        guard selectedPath.count >= 2 else { return }

        let traced = String(selectedPath.map { grid[$0.row][$0.col] })
        let reversed = String(traced.reversed())
        if let match = targets.first(where: {
            !foundWordIDs.contains($0.wordID) && ($0.answer == traced || $0.answer == reversed)
        }) {
            handleFound(match)
        } else {
            SoundManager.shared.play(.bonk)
            Haptics.light()
            pathIsWrong = true
            withAnimation(.linear(duration: 0.35)) { pathShakeTicks += 1 }
            let path = selectedPath
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if selectedPath == path {
                    selectedPath = []
                    pathDirection = nil
                    pathIsWrong = false
                }
            }
        }
    }

    // MARK: Resolution

    private func handleFound(_ target: PuzzleTarget) {
        SoundManager.shared.play(.explosion)
        Haptics.success()

        session.bringToFront(wordID: target.wordID)
        let feedback = session.submitJudged(correct: true)
        session.advance()

        foundWordIDs.insert(target.wordID)
        foundPaths.append(selectedPath)
        if hintCoordinate != nil, placements[target.wordID]?.first == hintCoordinate {
            hintCoordinate = nil
        }
        selectedPath = []
        pathDirection = nil

        if case .correct(let gained, let revealText, _) = feedback {
            showReveal(revealText, correct: true)
            xpFloat = gained
        }

        if foundWordIDs.count == targets.count {
            resolving = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if session.isFinished {
                    onRoundEnd()
                } else {
                    loadNextPuzzle()
                }
            }
        }
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

    // MARK: Hint — marks the first letter of one unfound word in gold

    private func useHint() {
        guard let current = session.current,
              let start = placements[current.word.id]?.first,
              session.useFirstLetter() != nil
        else { return }
        Haptics.selection()
        hintCoordinate = start
    }

    // MARK: Puzzle lifecycle

    private func loadNextPuzzle() {
        let remaining = Array(session.questions[session.index...].prefix(Self.puzzleCapacity))
        guard !remaining.isEmpty else {
            onRoundEnd()
            return
        }
        session.markQuestionShown()

        var newTargets: [PuzzleTarget] = []
        var anyTurkish = false
        for question in remaining {
            let isTurkishTarget = question.direction == .enToTr
            anyTurkish = anyTurkish || isTurkishTarget
            let raw = question.correctAnswer.replacingOccurrences(of: " ", with: "")
            let normalized = isTurkishTarget ? raw.turkishUppercased : raw.uppercased()
            newTargets.append(PuzzleTarget(wordID: question.word.id, prompt: question.prompt, answer: normalized))
        }

        let layout = Self.buildPuzzle(
            targets: newTargets.map { (wordID: $0.wordID, text: $0.answer) },
            turkishPool: anyTurkish
        )
        targets = newTargets
        grid = layout.letters
        gridSize = layout.size
        placements = layout.placements
        foundWordIDs = []
        foundPaths = []
        selectedPath = []
        pathDirection = nil
        pathIsWrong = false
        hintCoordinate = nil
        resolving = false
    }

    /// Places every answer in one shared grid (horizontal or vertical,
    /// overlaps allowed where letters agree), growing the grid until all
    /// fit, then fills the gaps with random letters.
    private static func buildPuzzle(
        targets: [(wordID: Int, text: String)],
        turkishPool: Bool
    ) -> PuzzleLayout {
        let longest = targets.map { $0.text.count }.max() ?? 7
        var size = max(7, longest)

        while true {
            var grid = [[Character]](repeating: [Character](repeating: " ", count: size), count: size)
            var placements: [Int: [GridCoordinate]] = [:]
            var allPlaced = true

            for target in targets.sorted(by: { $0.text.count > $1.text.count }) {
                let letters = Array(target.text)
                var placed = false
                for _ in 0..<250 {
                    let horizontal = Bool.random()
                    let dr = horizontal ? 0 : 1
                    let dc = horizontal ? 1 : 0
                    let maxRow = size - (horizontal ? 1 : letters.count)
                    let maxCol = size - (horizontal ? letters.count : 1)
                    guard maxRow >= 0, maxCol >= 0 else { break }
                    let r0 = Int.random(in: 0...maxRow)
                    let c0 = Int.random(in: 0...maxCol)

                    var fits = true
                    for (i, ch) in letters.enumerated() {
                        let cell = grid[r0 + dr * i][c0 + dc * i]
                        if cell != " " && cell != ch { fits = false; break }
                    }
                    guard fits else { continue }

                    var path: [GridCoordinate] = []
                    for (i, ch) in letters.enumerated() {
                        grid[r0 + dr * i][c0 + dc * i] = ch
                        path.append(GridCoordinate(row: r0 + dr * i, col: c0 + dc * i))
                    }
                    placements[target.wordID] = path
                    placed = true
                    break
                }
                if !placed { allPlaced = false; break }
            }

            if allPlaced {
                let pool = Array(turkishPool ? "ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ" : "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
                for r in 0..<size {
                    for c in 0..<size where grid[r][c] == " " {
                        grid[r][c] = pool.randomElement()!
                    }
                }
                return PuzzleLayout(letters: grid, size: size, placements: placements)
            }
            size += 1
        }
    }
}

// MARK: - Grid cell frame collection

private struct GridCellFramePreferenceKey: PreferenceKey {
    static var defaultValue: [GridCoordinate: CGRect] { [:] }
    static func reduce(value: inout [GridCoordinate: CGRect], nextValue: () -> [GridCoordinate: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}
