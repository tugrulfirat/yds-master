import Foundation
import Combine

/// Shared round logic used by all four game modes.
///
/// A session owns the question queue, validates answers, awards XP and combo,
/// updates word progress via the store, and produces the final `GameResult`.
/// Game screens only render and animate — they never duplicate learning logic.
final class GameSession: ObservableObject {

    let mode: GameMode
    let kind: SessionKind
    let store: WordStore

    @Published private(set) var questions: [Question] = []
    @Published private(set) var index: Int = 0
    @Published private(set) var combo: Int = 0
    @Published private(set) var maxCombo: Int = 0
    @Published private(set) var xpEarned: Int = 0
    @Published private(set) var score: Int = 0
    @Published private(set) var lives: Int = 3
    @Published private(set) var timeRemaining: Int = 0
    @Published private(set) var correctCount: Int = 0
    @Published private(set) var wrongCount: Int = 0
    @Published private(set) var lastReveal: String?
    @Published private(set) var revealHistory: [String] = []
    @Published private(set) var shieldActive: Bool = false

    private var wrongOnCurrentQuestion = false
    private var questionShownAt = Date()
    private var wrongWordIDs = Set<Int>()
    private var masteredBefore = Set<Int>()
    private var finished = false

    /// Number of answer options per question, tuned by user difficulty.
    static func optionCount(for difficulty: DifficultyLevel) -> Int {
        switch difficulty {
        case .beginner: return 3
        case .intermediate: return 4
        case .advanced: return 5
        }
    }

    /// - Parameter forcedDirection: when set, every question uses this exact
    ///   direction instead of the user's mixed/random preference. Synonym
    ///   Storm needs this because its English synonym data only supports
    ///   showing the Turkish meaning as the anchor.
    init(
        mode: GameMode,
        kind: SessionKind = .freePlay,
        store: WordStore,
        questionCount: Int = 10,
        words: [Word]? = nil,
        forcedDirection: Direction? = nil
    ) {
        self.mode = mode
        self.kind = kind
        self.store = store

        let sessionWords = words ?? store.sessionWords(count: questionCount, kind: kind)
        let optionCount = Self.optionCount(for: store.profile.startingDifficulty)
        self.questions = sessionWords.enumerated().map { i, word in
            // Meaning Factory: every 4th crate is a "sort by part of speech" interlude.
            if mode == .meaningFactory && i % 4 == 3 {
                return store.engine.makePartOfSpeechQuestion(for: word, optionCount: optionCount)
            }
            return store.engine.makeQuestion(
                for: word,
                direction: forcedDirection ?? store.profile.directionPreference.resolvedDirection(),
                optionCount: optionCount,
                pool: store.words
            )
        }
        self.masteredBefore = Set(sessionWords.filter { store.progress(for: $0).isMastered }.map(\.id))
        self.questionShownAt = Date()
        self.timeRemaining = mode.roundDuration
    }

    // MARK: - Round timer & lives

    /// Advances the countdown by one second. Returns true when time has run out.
    @discardableResult
    func tick() -> Bool {
        guard timeRemaining > 0 else { return true }
        timeRemaining -= 1
        return timeRemaining <= 0
    }

    var timeText: String {
        String(format: "%d:%02d", timeRemaining / 60, timeRemaining % 60)
    }

    /// Removes one heart. Returns the remaining count.
    @discardableResult
    func loseLife() -> Int {
        if lives > 0 { lives -= 1 }
        return lives
    }

    /// Slicing a bomb: combo breaks (unless shielded) and a heart is lost.
    /// No word progress is touched. Returns remaining lives.
    func penalizeBomb() -> Int {
        if shieldActive {
            shieldActive = false
        } else {
            combo = 0
        }
        score = max(0, score - 50)
        return loseLife()
    }

    // MARK: - State

    var current: Question? {
        guard index < questions.count else { return nil }
        return questions[index]
    }

    var isFinished: Bool { index >= questions.count }
    var totalQuestions: Int { questions.count }
    var progressFraction: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(index) / Double(questions.count)
    }

    func markQuestionShown() {
        questionShownAt = Date()
    }

    // MARK: - Answering

    enum AnswerFeedback {
        case correct(xpGained: Int, reveal: String, isCritical: Bool)
        case wrong(reveal: String, shieldUsed: Bool)
    }

    /// Validates an answer for the current question and updates all progress.
    @discardableResult
    func submit(answer: String) -> AnswerFeedback {
        guard let question = current else {
            return .wrong(reveal: "", shieldUsed: false)
        }

        let responseTime = Date().timeIntervalSince(questionShownAt)

        if answer == question.correctAnswer {
            let fast = responseTime < 3.0
            var gained = 10
            gained += min(combo, 5) * 2          // combo bonus, capped
            if fast { gained += 5 }              // speed bonus
            if wrongOnCurrentQuestion { gained = max(2, gained / 2) }

            xpEarned += gained
            combo += 1
            maxCombo = max(maxCombo, combo)
            correctCount += 1
            score += 100 + min(combo, 6) * 20 + (fast ? 50 : 0)
            lastReveal = question.revealText
            revealHistory.append(question.revealText)
            store.registerCorrect(word: question.word, firstTry: !wrongOnCurrentQuestion)
            return .correct(xpGained: gained, reveal: question.revealText, isCritical: fast && combo >= 3)
        } else {
            wrongCount += 1
            wrongWordIDs.insert(question.word.id)
            wrongOnCurrentQuestion = true
            store.registerWrong(word: question.word)

            var shieldUsed = false
            if shieldActive {
                shieldActive = false
                shieldUsed = true       // combo survives one mistake
            } else {
                combo = 0
            }
            return .wrong(reveal: question.revealText, shieldUsed: shieldUsed)
        }
    }

    /// Feeds a locally-verified correct/incorrect judgment into the standard
    /// scoring pipeline without needing the literal matched string — used by
    /// Word Hunt Mirror (the traced grid path has spaces stripped, so it
    /// never equals `correctAnswer` textually even when it's right).
    @discardableResult
    func submitJudged(correct: Bool) -> AnswerFeedback {
        submit(answer: correct ? (current?.correctAnswer ?? "") : "")
    }

    /// Small ad-hoc score/XP bump that does NOT touch mastery, combo, or word
    /// progress — used by Synonym Storm for interim synonym catches within a
    /// single word's family. The family's final catch still goes through
    /// `submitJudged`/`submit` so each word's mastery updates exactly once.
    func awardBonus(score bonusScore: Int, xp bonusXP: Int) {
        score += bonusScore
        xpEarned += bonusXP
    }

    /// Word Hunt Mirror hides several questions' answers in one shared grid
    /// and lets the player find them in any order. Promoting the matched
    /// word's question to the current slot (a swap within the unanswered
    /// tail) keeps the standard submit/advance bookkeeping attributed to the
    /// right word without changing anything for the sequential modes.
    func bringToFront(wordID: Int) {
        guard index < questions.count,
              let pos = questions[index...].firstIndex(where: { $0.word.id == wordID })
        else { return }
        if pos != index { questions.swapAt(index, pos) }
    }

    /// Moves to the next question. Returns false when the round is over.
    @discardableResult
    func advance() -> Bool {
        guard index < questions.count else { return false }
        index += 1
        wrongOnCurrentQuestion = false
        questionShownAt = Date()
        return index < questions.count
    }

    /// The current word escaped (fell off screen / belt ran out). Not a wrong
    /// answer, but the word is requeued at the end of the round once.
    func requeueCurrent() {
        guard let question = current, questions.filter({ $0.word.id == question.word.id }).count < 2 else {
            advance()
            return
        }
        questions.append(question)
        advance()
    }

    // MARK: - Power-ups

    /// Returns a wrong option to remove, or nil if unavailable.
    func useRemoveWrong() -> String? {
        guard let question = current,
              let wrong = question.options.first(where: { $0 != question.correctAnswer }),
              store.consumePowerUp(.removeWrong)
        else { return nil }
        return wrong
    }

    /// Returns the first letter of the correct answer, or nil if unavailable.
    func useFirstLetter() -> String? {
        guard let question = current, store.consumePowerUp(.firstLetter) else { return nil }
        return String(question.correctAnswer.prefix(1)).turkishUppercased
    }

    func useSlowMotion() -> Bool {
        store.consumePowerUp(.slowMotion)
    }

    func useShield() -> Bool {
        guard !shieldActive, store.consumePowerUp(.shield) else { return false }
        shieldActive = true
        return true
    }

    // MARK: - Finishing

    /// Builds the result and applies it to the store exactly once.
    func finish() -> GameResult {
        let uniqueWords = uniquedWords(questions.map(\.word))
        let newlyMastered = uniqueWords.filter {
            store.progress(for: $0).isMastered && !masteredBefore.contains($0.id)
        }
        let weak = uniqueWords.filter { store.progress(for: $0).isWeak }

        var result = GameResult(
            mode: mode,
            kind: kind,
            totalQuestions: questions.count,
            correctCount: correctCount,
            wrongCount: wrongCount,
            xpEarned: xpEarned,
            score: score,
            maxCombo: maxCombo,
            practicedWords: uniqueWords,
            newlyMasteredWords: newlyMastered,
            weakWords: weak
        )

        if !finished {
            finished = true
            result.missionBonusXP = store.completeRound(result: result)
        }
        return result
    }

    private func uniquedWords(_ list: [Word]) -> [Word] {
        var seen = Set<Int>()
        return list.filter { seen.insert($0.id).inserted }
    }
}
