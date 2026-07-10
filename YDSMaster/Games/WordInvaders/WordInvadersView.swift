import SwiftUI

/// Word Circuit gameplay. The player draws one continuous route through every
/// target synonym-family word, then closes the circuit at the exit node.
struct WordInvadersView: View {
    @ObservedObject var session: WordInvadersSession
    var onRoundEnd: () -> Void

    @State private var puzzle: CircuitPuzzle?
    @State private var activePath: [CircuitCoordinate] = []
    @State private var wrongTiles: Set<CircuitCoordinate> = []
    @State private var shakingTile: CircuitCoordinate?
    @State private var locked = false
    @State private var isTracing = false

    @State private var reveal: String?
    @State private var correction: String?
    @State private var feedbackToken = UUID()
    @State private var xpFloat: (amount: Int, token: UUID)?
    @State private var screenFlash = false
    @State private var showWaveIntro = false

    private let gridSize = 6
    private let boardPadding: CGFloat = 10
    private let tileSpacing: CGFloat = 7

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ArenaBackground(mode: .wordInvaders)

                Rectangle()
                    .fill(Theme.danger.opacity(screenFlash ? 0.20 : 0))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    header
                        .padding(.top, 8)

                    if session.isBossWave {
                        bossBar
                            .padding(.top, 6)
                    }

                    targetMeaningCard
                        .padding(.top, 8)

                    feedbackArea
                        .frame(height: 48)
                        .padding(.top, 6)

                    Spacer(minLength: 10)

                    if let puzzle {
                        let side = min(geo.size.width - 28, 560)
                        circuitBoard(puzzle, side: side)
                            .frame(width: side, height: side)
                            .padding(.horizontal, 14)
                    }

                    Spacer(minLength: 12)

                    progressStrip
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                }

                if showWaveIntro {
                    waveIntroBanner
                        .allowsHitTesting(false)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
            .onAppear {
                if puzzle == nil {
                    beginWaveWithIntro()
                }
            }
        }
    }

    // MARK: HUD

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button(action: onRoundEnd) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Theme.card))
                }
                hudPanel(title: "Skor", value: "\(session.score)", tint: Theme.gold)
                hudPanel(title: "Kombo", value: "x\(session.combo)", tint: session.combo >= 3 ? Theme.orange : Theme.textPrimary)
                hudPanel(title: "Süre", value: session.timeText,
                         tint: session.timeRemaining <= 10 ? Theme.danger : Theme.textPrimary)
            }
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Text(i < session.lives ? "❤️" : "🖤").font(.system(size: 14))
                }
                if session.shieldActive {
                    Text("🛡️").font(.system(size: 16))
                }
                Spacer()
                Text("Dalga \(min(session.waveIndex + 1, session.totalWaves))/\(session.totalWaves)")
                    .font(Theme.font(12, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
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
                .font(Theme.font(17, weight: .black))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .arcadePanel(cornerRadius: 12)
    }

    private var bossBar: some View {
        VStack(spacing: 4) {
            Text("BOSS DEVRESİ")
                .font(Theme.font(11, weight: .heavy))
                .foregroundStyle(Theme.danger)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule()
                        .fill(session.bossHP > 0.5 ? Theme.success : session.bossHP > 0.2 ? Theme.orange : Theme.danger)
                        .frame(width: geo.size.width * max(0, session.bossHP))
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: session.bossHP)
                }
            }
            .frame(height: 10)
            .padding(.horizontal, 40)
        }
    }

    private var targetMeaningCard: some View {
        VStack(spacing: 4) {
            Text("Hedef anlam:")
                .font(Theme.font(12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            Text(session.currentWave.meaningFamilyTR)
                .font(Theme.font(24, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("Bağlanan: \(connectedWordCount)/\(session.currentWave.correctWords.count)")
                .font(Theme.font(12, weight: .bold))
                .foregroundStyle(Theme.indigo)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: connectedWordCount)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .cardStyle(cornerRadius: 16)
    }

    private var feedbackArea: some View {
        HStack {
            if let reveal {
                RevealTrayView(text: reveal, isCorrect: true)
            }
            if let correction {
                correctionCard(correction)
            }
            if let xpFloat {
                FloatingXPView(amount: xpFloat.amount).id(xpFloat.token)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: reveal)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: correction)
    }

    private func correctionCard(_ text: String) -> some View {
        let lines = text.split(separator: "\n", maxSplits: 1).map(String.init)
        return VStack(spacing: 2) {
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(Theme.font(14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Theme.card)
                .overlay(Capsule().stroke(Theme.danger.opacity(0.6), lineWidth: 1.5))
                .shadow(color: Theme.danger.opacity(0.3), radius: 8)
        )
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
            removal: .opacity
        ))
    }

    private var progressStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(session.currentWave.correctWords.map(\.en), id: \.self) { word in
                    let connected = isWordConnected(word)
                    Text(word)
                        .font(Theme.font(11, weight: .heavy))
                        .foregroundStyle(connected ? Theme.success : Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(connected ? Theme.success.opacity(0.16) : Theme.card.opacity(0.75))
                                .overlay(
                                    Capsule().stroke(
                                        connected ? Theme.success.opacity(0.55) : Theme.cardBorder,
                                        lineWidth: 1
                                    )
                                )
                        )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var connectedWordCount: Int {
        max(session.caughtThisWave.count, selectedCorrectWords.count)
    }

    private var selectedCorrectWords: Set<String> {
        guard let puzzle else { return [] }
        return Set(activePath.compactMap { coordinate in
            guard let word = puzzle.tile(at: coordinate)?.word,
                  session.currentWave.isCorrect(word) else { return nil }
            return word
        })
    }

    private func isWordConnected(_ word: String) -> Bool {
        session.caughtThisWave.contains(word) || selectedCorrectWords.contains(word)
    }

    // MARK: Circuit Board

    private func circuitBoard(_ puzzle: CircuitPuzzle, side: CGFloat) -> some View {
        let tileSize = (side - boardPadding * 2 - tileSpacing * CGFloat(gridSize - 1)) / CGFloat(gridSize)

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.22))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.cardBorder))

            CircuitTraceShape(
                coordinates: activePath,
                tileSize: tileSize,
                spacing: tileSpacing,
                padding: boardPadding
            )
            .stroke(
                LinearGradient(colors: [Theme.gold, Theme.success], startPoint: .leading, endPoint: .trailing),
                style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)
            )
            .shadow(color: Theme.gold.opacity(0.55), radius: 7)
            .opacity(activePath.count > 1 ? 1 : 0)

            ForEach(puzzle.orderedTiles) { tile in
                circuitTile(tile)
                    .frame(width: tileSize, height: tileSize)
                    .position(center(for: tile.coordinate, tileSize: tileSize))
            }
        }
        .frame(width: side, height: side)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    handleCircuitDrag(at: value.location, tileSize: tileSize)
                }
                .onEnded { _ in
                    finishCircuitTrace()
                }
        )
    }

    private func center(for coordinate: CircuitCoordinate, tileSize: CGFloat) -> CGPoint {
        CGPoint(
            x: boardPadding + CGFloat(coordinate.col) * (tileSize + tileSpacing) + tileSize / 2,
            y: boardPadding + CGFloat(coordinate.row) * (tileSize + tileSpacing) + tileSize / 2
        )
    }

    @ViewBuilder
    private func circuitTile(_ tile: CircuitTile) -> some View {
        if tile.isWall {
            wallTile
        } else {
            playableCircuitTile(tile)
        }
    }

    private var wallTile: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.black.opacity(0.34))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
            .opacity(0.72)
    }

    private func playableCircuitTile(_ tile: CircuitTile) -> some View {
        let coordinate = tile.coordinate
        let isCurrent = activePath.last == coordinate
        let isActive = activePath.contains(coordinate)
        let isWrong = wrongTiles.contains(coordinate)
        let isAvailable = canTrace(to: coordinate)

        return ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tileFill(tile: tile, isActive: isActive, isWrong: isWrong, isAvailable: isAvailable))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(tileBorder(tile: tile, isCurrent: isCurrent, isActive: isActive, isWrong: isWrong, isAvailable: isAvailable),
                                lineWidth: isCurrent ? 2.8 : 1.4)
                )

            VStack(spacing: 4) {
                if tile.isStart {
                    circuitNodeIcon(systemName: "bolt.circle.fill", color: Theme.gold)
                } else if tile.isExit {
                    circuitNodeIcon(
                        systemName: selectedCorrectWords == targetWords ? "checkmark.seal.fill" : "lock.circle.fill",
                        color: selectedCorrectWords == targetWords ? Theme.success : Theme.textSecondary
                    )
                }

                if let word = tile.word {
                    Text(word)
                        .font(Theme.font(word.count > 9 ? 11 : 12, weight: .heavy))
                        .foregroundStyle(tileTextColor(isActive: isActive, isWrong: isWrong, isAvailable: isAvailable))
                        .lineLimit(word.contains(" ") ? 2 : 1)
                        .minimumScaleFactor(0.42)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(5)
        }
        .opacity(isAvailable || isActive || isWrong || tile.isStart || tile.isExit ? 1 : 0.58)
        .scaleEffect(isCurrent ? 1.04 : 1)
        .offset(x: shakingTile == coordinate ? -6 : 0)
        .animation(.spring(response: 0.25, dampingFraction: 0.55), value: isCurrent)
        .animation(.linear(duration: 0.05).repeatCount(5, autoreverses: true), value: shakingTile)
    }

    private func circuitNodeIcon(systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .heavy))
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.65), radius: 6)
    }

    private func tileFill(tile: CircuitTile, isActive: Bool, isWrong: Bool, isAvailable: Bool) -> Color {
        if tile.isStart { return Theme.indigo.opacity(0.28) }
        if tile.isExit { return selectedCorrectWords == targetWords ? Theme.success.opacity(0.18) : Theme.card.opacity(0.46) }
        if isActive { return Theme.success.opacity(0.20) }
        if isWrong { return Theme.danger.opacity(0.24) }
        if isAvailable { return Theme.card.opacity(0.92) }
        return Theme.card.opacity(0.52)
    }

    private func tileBorder(tile: CircuitTile, isCurrent: Bool, isActive: Bool, isWrong: Bool, isAvailable: Bool) -> Color {
        if isCurrent { return Theme.gold.opacity(0.95) }
        if tile.isStart { return Theme.indigo.opacity(0.95) }
        if tile.isExit, selectedCorrectWords == targetWords { return Theme.success.opacity(0.75) }
        if isActive { return Theme.success.opacity(0.75) }
        if isWrong { return Theme.danger.opacity(0.75) }
        if isAvailable { return Theme.gold.opacity(0.50) }
        return Theme.cardBorder
    }

    private func tileTextColor(isActive: Bool, isWrong: Bool, isAvailable: Bool) -> Color {
        if isActive { return Theme.success }
        if isWrong { return Theme.danger }
        return isAvailable ? Theme.textPrimary : Theme.textSecondary
    }

    private var targetWords: Set<String> {
        Set(session.currentWave.correctWords.map(\.en))
    }

    private func canTrace(to coordinate: CircuitCoordinate) -> Bool {
        guard !locked,
              let puzzle,
              let tile = puzzle.tile(at: coordinate),
              !tile.isWall,
              !wrongTiles.contains(coordinate) else {
            return false
        }

        guard let current = activePath.last else {
            return coordinate == puzzle.start
        }

        if coordinate == current { return true }
        if activePath.dropLast().last == coordinate { return true }
        guard coordinate.isAdjacent(to: current), !activePath.contains(coordinate) else { return false }
        if tile.isExit { return selectedCorrectWords == targetWords }
        return true
    }

    private func coordinate(at point: CGPoint, tileSize: CGFloat) -> CircuitCoordinate? {
        let x = point.x - boardPadding
        let y = point.y - boardPadding
        guard x >= 0, y >= 0 else { return nil }

        let step = tileSize + tileSpacing
        let col = Int(x / step)
        let row = Int(y / step)
        guard (0..<gridSize).contains(row), (0..<gridSize).contains(col) else { return nil }

        let localX = x - CGFloat(col) * step
        let localY = y - CGFloat(row) * step
        guard localX <= tileSize, localY <= tileSize else { return nil }
        return CircuitCoordinate(row: row, col: col)
    }

    // MARK: Wave Lifecycle

    private func beginWaveWithIntro() {
        locked = true
        buildPuzzleForCurrentWave()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { showWaveIntro = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.25)) { showWaveIntro = false }
            locked = false
        }
    }

    private func buildPuzzleForCurrentWave() {
        let newPuzzle = CircuitPuzzle.make(for: session.currentWave, gridSize: gridSize)
        puzzle = newPuzzle
        activePath = [newPuzzle.start]
        wrongTiles = []
        shakingTile = nil
        reveal = nil
        correction = nil
        xpFloat = nil
        isTracing = false
    }

    private var waveIntroBanner: some View {
        VStack(spacing: 6) {
            Text(session.isBossWave ? "BOSS DEVRESİ" : "DALGA \(min(session.waveIndex + 1, session.totalWaves))")
                .font(Theme.font(14, weight: .heavy))
                .foregroundStyle(session.isBossWave ? Theme.danger : Theme.textSecondary)
            Text("Devre: \"\(session.currentWave.meaningFamilyTR)\"")
                .font(Theme.font(26, weight: .black))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .cardStyle(cornerRadius: 20)
        .padding(.horizontal, 32)
    }

    // MARK: Circuit Resolution

    private func handleCircuitDrag(at point: CGPoint, tileSize: CGFloat) {
        guard !locked, let puzzle, let coordinate = coordinate(at: point, tileSize: tileSize) else { return }

        if !isTracing {
            guard coordinate == puzzle.start else { return }
            isTracing = true
            activePath = [puzzle.start]
            Haptics.light()
            return
        }

        guard coordinate != activePath.last else { return }

        if activePath.dropLast().last == coordinate {
            activePath.removeLast()
            Haptics.selection()
            return
        }

        guard canTrace(to: coordinate), let tile = puzzle.tile(at: coordinate) else {
            breakCircuit(message: "Devre koptu\nBaştan çiz", costsLife: false, coordinate: coordinate)
            return
        }

        if let word = tile.word, !session.currentWave.isCorrect(word) {
            resolveWrongTile(tile, word: word)
            return
        }

        activePath.append(coordinate)
        Haptics.light()
    }

    private func finishCircuitTrace() {
        guard isTracing, let puzzle else { return }
        isTracing = false

        guard activePath.last == puzzle.finish, selectedCorrectWords == targetWords else {
            if activePath.count > 1 {
                breakCircuit(message: "Devre eksik\nTüm kelimeleri bağla", costsLife: false, coordinate: activePath.last)
            }
            return
        }

        completeCircuit()
    }

    private func completeCircuit() {
        guard let puzzle else { return }
        locked = true

        var totalXP = 0
        var finalReveal: String?
        var didCompleteWave = false

        let words = activePath.compactMap { coordinate -> String? in
            guard let word = puzzle.tile(at: coordinate)?.word,
                  session.currentWave.isCorrect(word) else { return nil }
            return word
        }

        for word in words {
            switch session.resolveShot(word: word) {
            case .correct(let revealText, let xpGained, let waveComplete):
                totalXP += xpGained
                finalReveal = revealText
                didCompleteWave = didCompleteWave || waveComplete
            case .wrong:
                break
            }
        }

        SoundManager.shared.play(.pop)
        Haptics.success()
        showFeedback(reveal: finalReveal ?? "Devre tamamlandı")
        if totalXP > 0 {
            xpFloat = (totalXP, UUID())
        }

        if didCompleteWave {
            completeWave()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                locked = false
            }
        }
    }

    private func resolveWrongTile(_ tile: CircuitTile, word: String) {
        locked = true
        isTracing = false
        wrongTiles.insert(tile.coordinate)
        shake(tile.coordinate)

        let result = session.resolveShot(word: word)
        switch result {
        case .correct:
            locked = false
        case .wrong(let correctionText, let livesRemaining):
            SoundManager.shared.play(.bonk)
            Haptics.error()
            showFeedback(correction: correctionText)
            flashScreen()
            activePath = [puzzle?.start].compactMap { $0 }

            if livesRemaining <= 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { onRoundEnd() }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    locked = false
                }
            }
        }
    }

    private func breakCircuit(message: String, costsLife: Bool, coordinate: CircuitCoordinate?) {
        locked = true
        isTracing = false
        if let coordinate {
            shake(coordinate)
        }
        Haptics.warning()
        SoundManager.shared.play(.bonk)
        if costsLife {
            flashScreen()
        }
        showFeedback(correction: message)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            activePath = [puzzle?.start].compactMap { $0 }
            locked = false
        }
    }

    private func completeWave() {
        locked = true
        if session.currentWave.isBoss {
            Haptics.heavy()
            session.store.earnBadge("boss-slayer")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            if session.advanceWave() {
                beginWaveWithIntro()
            } else {
                onRoundEnd()
            }
        }
    }

    private func shake(_ coordinate: CircuitCoordinate) {
        shakingTile = coordinate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            if shakingTile == coordinate {
                shakingTile = nil
            }
        }
    }

    private func flashScreen() {
        withAnimation(.easeOut(duration: 0.1)) { screenFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeIn(duration: 0.3)) { screenFlash = false }
        }
    }

    private func showFeedback(reveal newReveal: String? = nil, correction newCorrection: String? = nil) {
        reveal = newReveal
        correction = newCorrection
        let token = UUID()
        feedbackToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            guard feedbackToken == token else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                reveal = nil
                correction = nil
            }
        }
    }
}

private struct CircuitTraceShape: Shape {
    let coordinates: [CircuitCoordinate]
    let tileSize: CGFloat
    let spacing: CGFloat
    let padding: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = coordinates.first else { return path }

        path.move(to: center(for: first))
        for coordinate in coordinates.dropFirst() {
            path.addLine(to: center(for: coordinate))
        }
        return path
    }

    private func center(for coordinate: CircuitCoordinate) -> CGPoint {
        CGPoint(
            x: padding + CGFloat(coordinate.col) * (tileSize + spacing) + tileSize / 2,
            y: padding + CGFloat(coordinate.row) * (tileSize + spacing) + tileSize / 2
        )
    }
}

private struct CircuitPuzzle {
    let gridSize: Int
    let start: CircuitCoordinate
    let finish: CircuitCoordinate
    let tiles: [CircuitCoordinate: CircuitTile]

    var orderedTiles: [CircuitTile] {
        tiles.values.sorted {
            if $0.coordinate.row == $1.coordinate.row {
                return $0.coordinate.col < $1.coordinate.col
            }
            return $0.coordinate.row < $1.coordinate.row
        }
    }

    func tile(at coordinate: CircuitCoordinate) -> CircuitTile? {
        tiles[coordinate]
    }

    static func make(for wave: SynonymCluster, gridSize: Int) -> CircuitPuzzle {
        let start = CircuitCoordinate(row: gridSize - 1, col: max(0, gridSize / 2 - 1))
        let route = validatedRoute(correctCount: wave.correctWords.count, gridSize: gridSize, start: start)
        let correctCoordinates = Array(route.prefix(wave.correctWords.count))
        let finish = route[wave.correctWords.count]
        let correctWords = wave.correctWords.map(\.en).shuffled()
        let wrongWords = wave.wrongWords.map(\.en).shuffled()
        let occupied = Set([start, finish] + correctCoordinates)
        let decoyTarget = wrongWords.isEmpty ? 0 : min(10, max(7, correctWords.count + 4))
        let decoySet = decoyCoordinates(
            around: [start] + route,
            excluding: occupied,
            gridSize: gridSize,
            targetCount: decoyTarget
        )

        var tiles: [CircuitCoordinate: CircuitTile] = [:]
        var decoyIndex = 0

        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let coordinate = CircuitCoordinate(row: row, col: col)
                if coordinate == start {
                    tiles[coordinate] = CircuitTile(coordinate: coordinate, kind: .start)
                } else if coordinate == finish {
                    tiles[coordinate] = CircuitTile(coordinate: coordinate, kind: .finish)
                } else if let pathIndex = correctCoordinates.firstIndex(of: coordinate), !correctWords.isEmpty {
                    tiles[coordinate] = CircuitTile(coordinate: coordinate, kind: .word(correctWords[pathIndex % correctWords.count]))
                } else if decoySet.contains(coordinate), !wrongWords.isEmpty {
                    tiles[coordinate] = CircuitTile(coordinate: coordinate, kind: .word(wrongWords[decoyIndex % wrongWords.count]))
                    decoyIndex += 1
                } else {
                    tiles[coordinate] = CircuitTile(coordinate: coordinate, kind: .wall)
                }
            }
        }

        return CircuitPuzzle(gridSize: gridSize, start: start, finish: finish, tiles: tiles)
    }

    private static func validatedRoute(correctCount: Int, gridSize: Int, start: CircuitCoordinate) -> [CircuitCoordinate] {
        let candidates = routeCandidates(gridSize: gridSize)
            .shuffled()
            .filter { route in
                route.count > correctCount
                    && route.first?.isAdjacent(to: start) == true
                    && Set(route).count == route.count
                    && route.allSatisfy { $0.isInside(gridSize: gridSize) }
                    && zip(route, route.dropFirst()).allSatisfy { pair in
                        pair.0.isAdjacent(to: pair.1)
                    }
            }

        if let route = candidates.first {
            return Array(route.prefix(correctCount + 1))
        }

        return [
            CircuitCoordinate(row: gridSize - 2, col: start.col),
            CircuitCoordinate(row: gridSize - 3, col: start.col),
            CircuitCoordinate(row: gridSize - 3, col: start.col + 1),
            CircuitCoordinate(row: gridSize - 4, col: start.col + 1),
            CircuitCoordinate(row: gridSize - 4, col: start.col + 2),
            CircuitCoordinate(row: gridSize - 5, col: start.col + 2),
        ]
    }

    private static func routeCandidates(gridSize: Int) -> [[CircuitCoordinate]] {
        let bottom = gridSize - 1
        return [
            [
                CircuitCoordinate(row: bottom - 1, col: 2),
                CircuitCoordinate(row: bottom - 2, col: 2),
                CircuitCoordinate(row: bottom - 2, col: 1),
                CircuitCoordinate(row: bottom - 3, col: 1),
                CircuitCoordinate(row: bottom - 3, col: 0),
                CircuitCoordinate(row: bottom - 4, col: 0),
            ],
            [
                CircuitCoordinate(row: bottom, col: 3),
                CircuitCoordinate(row: bottom - 1, col: 3),
                CircuitCoordinate(row: bottom - 2, col: 3),
                CircuitCoordinate(row: bottom - 2, col: 4),
                CircuitCoordinate(row: bottom - 3, col: 4),
                CircuitCoordinate(row: bottom - 3, col: 5),
            ],
            [
                CircuitCoordinate(row: bottom, col: 1),
                CircuitCoordinate(row: bottom - 1, col: 1),
                CircuitCoordinate(row: bottom - 1, col: 0),
                CircuitCoordinate(row: bottom - 2, col: 0),
                CircuitCoordinate(row: bottom - 3, col: 0),
                CircuitCoordinate(row: bottom - 3, col: 1),
            ],
            [
                CircuitCoordinate(row: bottom - 1, col: 2),
                CircuitCoordinate(row: bottom - 1, col: 3),
                CircuitCoordinate(row: bottom - 2, col: 3),
                CircuitCoordinate(row: bottom - 3, col: 3),
                CircuitCoordinate(row: bottom - 3, col: 4),
                CircuitCoordinate(row: bottom - 4, col: 4),
            ],
            [
                CircuitCoordinate(row: bottom, col: 3),
                CircuitCoordinate(row: bottom, col: 4),
                CircuitCoordinate(row: bottom - 1, col: 4),
                CircuitCoordinate(row: bottom - 1, col: 5),
                CircuitCoordinate(row: bottom - 2, col: 5),
                CircuitCoordinate(row: bottom - 3, col: 5),
            ],
            [
                CircuitCoordinate(row: bottom - 1, col: 2),
                CircuitCoordinate(row: bottom - 2, col: 2),
                CircuitCoordinate(row: bottom - 2, col: 3),
                CircuitCoordinate(row: bottom - 3, col: 3),
                CircuitCoordinate(row: bottom - 4, col: 3),
                CircuitCoordinate(row: bottom - 4, col: 4),
            ],
            [
                CircuitCoordinate(row: bottom, col: 1),
                CircuitCoordinate(row: bottom - 1, col: 1),
                CircuitCoordinate(row: bottom - 2, col: 1),
                CircuitCoordinate(row: bottom - 2, col: 2),
                CircuitCoordinate(row: bottom - 3, col: 2),
                CircuitCoordinate(row: bottom - 4, col: 2),
            ],
            [
                CircuitCoordinate(row: bottom - 1, col: 2),
                CircuitCoordinate(row: bottom - 1, col: 1),
                CircuitCoordinate(row: bottom - 2, col: 1),
                CircuitCoordinate(row: bottom - 3, col: 1),
                CircuitCoordinate(row: bottom - 3, col: 2),
                CircuitCoordinate(row: bottom - 4, col: 2),
            ],
        ]
    }

    private static func decoyCoordinates(
        around route: [CircuitCoordinate],
        excluding excluded: Set<CircuitCoordinate>,
        gridSize: Int,
        targetCount: Int
    ) -> Set<CircuitCoordinate> {
        guard targetCount > 0 else { return [] }

        let candidates = Set(route.flatMap { coordinate in
            coordinate.neighbors(in: gridSize).filter { !excluded.contains($0) }
        })
        return Set(candidates.shuffled().prefix(targetCount))
    }
}

private struct CircuitTile: Identifiable {
    let coordinate: CircuitCoordinate
    let kind: Kind

    enum Kind {
        case wall
        case start
        case finish
        case word(String)
    }

    var id: CircuitCoordinate { coordinate }
    var isWall: Bool { if case .wall = kind { return true } else { return false } }
    var isStart: Bool { if case .start = kind { return true } else { return false } }
    var isExit: Bool { if case .finish = kind { return true } else { return false } }
    var word: String? {
        if case .word(let word) = kind { return word }
        return nil
    }
}

private struct CircuitCoordinate: Hashable {
    let row: Int
    let col: Int

    func isAdjacent(to other: CircuitCoordinate) -> Bool {
        abs(row - other.row) + abs(col - other.col) == 1
    }

    func isInside(gridSize: Int) -> Bool {
        (0..<gridSize).contains(row) && (0..<gridSize).contains(col)
    }

    func neighbors(in gridSize: Int) -> [CircuitCoordinate] {
        [
            CircuitCoordinate(row: row - 1, col: col),
            CircuitCoordinate(row: row + 1, col: col),
            CircuitCoordinate(row: row, col: col - 1),
            CircuitCoordinate(row: row, col: col + 1),
        ].filter { $0.isInside(gridSize: gridSize) }
    }
}
