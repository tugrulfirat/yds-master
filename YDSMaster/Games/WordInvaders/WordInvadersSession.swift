import Foundation

/// Result of resolving one selected word tile.
enum ShotResult {
    /// `waveComplete` is true when this was the last correct word needed.
    case correct(reveal: String, xpGained: Int, waveComplete: Bool)
    /// `correction` is the two-line "provide ≠ önlemek / provide = sağlamak" text.
    /// `livesRemaining` lets the caller know immediately if the round is over.
    case wrong(correction: String, livesRemaining: Int)
}

/// Owns one Word Circuit round: waves of synonym-family circuit puzzles, boss wave,
/// scoring, and real progress updates for any selected word that also exists in
/// the main word bank. Deliberately independent of `GameSession` — that
/// engine assumes one `Word` per question, which doesn't fit a mode where
/// several distinct words are each individually correct or wrong per wave.
final class WordInvadersSession: ObservableObject {

    let store: WordStore
    let kind: SessionKind
    let waves: [SynonymCluster]

    @Published private(set) var waveIndex = 0
    @Published private(set) var score = 0
    @Published private(set) var xpEarned = 0
    @Published private(set) var combo = 0
    @Published private(set) var maxCombo = 0
    @Published private(set) var lives = 3
    @Published private(set) var shieldActive = false
    @Published private(set) var timeRemaining = 130
    @Published private(set) var caughtThisWave: [String] = []
    @Published private(set) var bossHP: CGFloat = 1.0
    @Published private(set) var correctCount = 0
    @Published private(set) var wrongCount = 0

    private var remainingCorrect: Set<String> = []
    private var wrongInWave = false
    private var practicedIDs: Set<Int> = []
    private var weakIDs: Set<Int> = []
    private var masteredBeforeIDs: Set<Int> = []
    private var finished = false

    var currentWave: SynonymCluster { waves[min(waveIndex, waves.count - 1)] }
    var isBossWave: Bool { currentWave.isBoss }
    var totalWaves: Int { waves.count }
    var isFinished: Bool { waveIndex >= waves.count }

    init(store: WordStore, kind: SessionKind = .freePlay) {
        self.store = store
        self.kind = kind
        self.waves = SynonymCluster.samplePlaylist()
        remainingCorrect = Set(waves[0].correctWords.map(\.en))
        let touchedWords = waves.flatMap { $0.allWords.map(\.en) }
        masteredBeforeIDs = Set(
            store.words.filter { word in touchedWords.contains { $0.caseInsensitiveCompare(word.englishWord) == .orderedSame } }
                .filter { store.progress(for: $0).isMastered }
                .map(\.id)
        )
    }

    // MARK: Timer & lives

    @discardableResult
    func tick() -> Bool {
        guard timeRemaining > 0 else { return true }
        timeRemaining -= 1
        return timeRemaining <= 0
    }

    var timeText: String {
        String(format: "%d:%02d", timeRemaining / 60, timeRemaining % 60)
    }

    func useShield() -> Bool {
        guard !shieldActive, store.consumePowerUp(.shield) else { return false }
        shieldActive = true
        return true
    }

    func useSlowMotion() -> Bool {
        store.consumePowerUp(.slowMotion)
    }

    func useMagnet() -> Bool {
        store.consumePowerUp(.magnet)
    }

    // MARK: Tile resolution

    private func matchingStoreWord(_ englishWord: String) -> Word? {
        store.words.first { $0.englishWord.caseInsensitiveCompare(englishWord) == .orderedSame }
    }

    @discardableResult
    func resolveShot(word: String) -> ShotResult {
        let wave = currentWave
        let gloss = wave.turkishGloss(for: word)

        if wave.isCorrect(word) {
            guard remainingCorrect.contains(word) else {
                // Already collected this word earlier in the wave; don't
                // re-score or re-register mastery for it.
                return .correct(reveal: "\(word) = \(gloss)", xpGained: 0, waveComplete: remainingCorrect.isEmpty)
            }
            combo += 1
            maxCombo = max(maxCombo, combo)
            correctCount += 1
            var gained = 100 + min(combo, 5) * 25
            let xp = 8 + min(combo, 5) * 2

            if let storeWord = matchingStoreWord(word) {
                store.registerCorrect(word: storeWord, firstTry: true)
                practicedIDs.insert(storeWord.id)
            }

            remainingCorrect.remove(word)
            caughtThisWave.append(word)

            if isBossWave {
                let totalBossWords = CGFloat(wave.correctWords.count)
                bossHP = max(0, CGFloat(remainingCorrect.count) / totalBossWords)
            }

            let waveComplete = remainingCorrect.isEmpty
            if waveComplete && !wrongInWave {
                gained += 300 // perfect cluster bonus
                if isBossWave { gained += 500 } // boss defeated bonus
            }
            score += gained
            xpEarned += xp

            return .correct(reveal: "\(word) = \(gloss)", xpGained: xp, waveComplete: waveComplete)
        } else {
            wrongCount += 1
            wrongInWave = true
            if let storeWord = matchingStoreWord(word) {
                store.registerWrong(word: storeWord)
                weakIDs.insert(storeWord.id)
                practicedIDs.insert(storeWord.id)
            }

            var remaining = lives
            if shieldActive {
                shieldActive = false
            } else {
                combo = 0
                score = max(0, score - 50)
                remaining = loseLife()
            }
            let correction = "\(word) ≠ \(wave.meaningFamilyTR)\n\(word) = \(gloss)"
            return .wrong(correction: correction, livesRemaining: remaining)
        }
    }

    /// Removes one heart. Returns the remaining count.
    @discardableResult
    private func loseLife() -> Int {
        if lives > 0 { lives -= 1 }
        return lives
    }

    // MARK: Wave transitions

    @discardableResult
    func advanceWave() -> Bool {
        waveIndex += 1
        guard waveIndex < waves.count else { return false }
        remainingCorrect = Set(currentWave.correctWords.map(\.en))
        caughtThisWave = []
        wrongInWave = false
        bossHP = 1.0
        return true
    }

    // MARK: Finish

    func finish() -> GameResult {
        let practiced = store.words.filter { practicedIDs.contains($0.id) }
        let newlyMastered = practiced.filter {
            store.progress(for: $0).isMastered && !masteredBeforeIDs.contains($0.id)
        }
        let weak = store.words.filter { weakIDs.contains($0.id) && store.progress(for: $0).isWeak }

        var result = GameResult(
            mode: .wordInvaders,
            kind: kind,
            totalQuestions: waves.count,
            correctCount: correctCount,
            wrongCount: wrongCount,
            xpEarned: xpEarned,
            score: score,
            maxCombo: maxCombo,
            practicedWords: practiced,
            newlyMasteredWords: newlyMastered,
            weakWords: weak
        )

        if !finished {
            finished = true
            result.missionBonusXP = store.completeRound(result: result)
        }
        return result
    }
}
