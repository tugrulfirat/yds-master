import Foundation

extension String {
    /// Turkish-correct uppercasing — plain `.uppercased()` / `.textCase(.uppercase)`
    /// turns "i" into "I" instead of "İ" ("kelime" → "KELIME" instead of "KELİME").
    var turkishUppercased: String {
        uppercased(with: Locale(identifier: "tr_TR"))
    }
}

// MARK: - Part of Speech

enum PartOfSpeech: String, Codable, CaseIterable, Hashable {
    case verb, noun, adjective, adverb, preposition, conjunction, phrase

    /// Short Turkish label shown on chips and reveals, e.g. "F." for fiil (verb).
    var shortLabel: String {
        switch self {
        case .verb: return "F."
        case .noun: return "İ."
        case .adjective: return "S."
        case .adverb: return "Z."
        case .preposition: return "Ed."
        case .conjunction: return "Bğ."
        case .phrase: return "Kl."
        }
    }

    var turkishName: String {
        switch self {
        case .verb: return "Fiil"
        case .noun: return "İsim"
        case .adjective: return "Sıfat"
        case .adverb: return "Zarf"
        case .preposition: return "Edat"
        case .conjunction: return "Bağlaç"
        case .phrase: return "Kalıp"
        }
    }
}

// MARK: - Difficulty

enum DifficultyLevel: Int, Codable, CaseIterable, Hashable, Comparable {
    case beginner = 1
    case intermediate = 2
    case advanced = 3

    var title: String {
        switch self {
        case .beginner: return "Başlangıç YDS"
        case .intermediate: return "Orta Düzey YDS"
        case .advanced: return "İleri Düzey YDS"
        }
    }

    static func < (lhs: DifficultyLevel, rhs: DifficultyLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Word (static vocabulary content)

/// One vocabulary entry. Content only — user progress lives in `WordProgress`
/// so the 5000-word database can be swapped/re-imported without losing progress.
struct Word: Identifiable, Codable, Hashable {
    let id: Int
    let englishWord: String
    let turkishMeaning: String
    let partOfSpeech: PartOfSpeech
    let difficultyLevel: DifficultyLevel
    let category: String
    let ydsFrequencyRank: Int
    let exampleSentenceEN: String
    let exampleSentenceTR: String
    let synonyms: [String]
    /// English words this word is commonly confused with (used for hard distractors).
    let confusingWords: [String]

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Word, rhs: Word) -> Bool { lhs.id == rhs.id }
}

// MARK: - Mastery bands

enum MasteryBand: String, Codable, CaseIterable {
    case new        // 0–20
    case familiar   // 21–50
    case strong     // 51–80
    case mastered   // 81–100

    init(score: Int) {
        switch score {
        case ..<21: self = .new
        case ..<51: self = .familiar
        case ..<81: self = .strong
        default: self = .mastered
        }
    }

    var title: String {
        switch self {
        case .new: return "Yeni"
        case .familiar: return "Tanıdık"
        case .strong: return "Güçlü"
        case .mastered: return "Ustalaşıldı"
        }
    }
}

// MARK: - WordProgress (per-user learning state)

struct WordProgress: Codable, Hashable {
    var wordID: Int
    var masteryScore: Int = 0
    var timesSeen: Int = 0
    var timesCorrect: Int = 0
    var timesWrong: Int = 0
    var correctStreak: Int = 0
    var wrongStreak: Int = 0
    var lastSeenAt: Date?
    var nextReviewAt: Date?

    init(wordID: Int) { self.wordID = wordID }

    var band: MasteryBand { MasteryBand(score: masteryScore) }
    var isLearned: Bool { timesCorrect > 0 }
    var isMastered: Bool { band == .mastered }

    /// A word is "weak" when the user keeps missing it and hasn't recovered yet.
    var isWeak: Bool {
        guard timesWrong >= 1 else { return false }
        if wrongStreak >= 1 { return true }
        return timesWrong >= 2 && correctStreak < 3 && masteryScore < 60
    }

    var isDueForReview: Bool {
        guard timesSeen > 0 else { return false }
        guard let next = nextReviewAt else { return true }
        return next <= Date()
    }

    // MARK: Spaced-repetition update

    mutating func registerCorrect(firstTry: Bool, now: Date = Date()) {
        timesSeen += 1
        timesCorrect += 1
        correctStreak += 1
        wrongStreak = 0
        masteryScore = min(100, masteryScore + (firstTry ? 12 : 6))
        lastSeenAt = now
        nextReviewAt = now.addingTimeInterval(Self.reviewInterval(for: band))
    }

    mutating func registerWrong(now: Date = Date()) {
        timesSeen += 1
        timesWrong += 1
        wrongStreak += 1
        correctStreak = 0
        masteryScore = max(0, masteryScore - 8)
        lastSeenAt = now
        // Missed words come back fast.
        nextReviewAt = now.addingTimeInterval(5 * 60)
    }

    private static func reviewInterval(for band: MasteryBand) -> TimeInterval {
        switch band {
        case .new: return 4 * 3600            // 4 hours
        case .familiar: return 24 * 3600      // 1 day
        case .strong: return 3 * 24 * 3600    // 3 days
        case .mastered: return 7 * 24 * 3600  // 7 days
        }
    }
}
