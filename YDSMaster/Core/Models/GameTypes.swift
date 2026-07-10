import Foundation

// MARK: - Direction

/// Which way a single question is asked.
enum Direction: String, Codable, Hashable {
    /// English word shown as the prompt, Turkish meanings are the answers.
    case enToTr
    /// Turkish meaning shown as the prompt, English words are the answers.
    case trToEn
}

/// The user's preferred direction (Mixed alternates randomly per question).
enum DirectionPreference: String, Codable, CaseIterable, Identifiable {
    case enToTr, trToEn, mixed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .enToTr: return "İngilizce → Türkçe"
        case .trToEn: return "Türkçe → İngilizce"
        case .mixed: return "Karışık"
        }
    }

    var subtitle: String {
        switch self {
        case .enToTr: return "İngilizce kelimeyi gör, Türkçe anlamını seç"
        case .trToEn: return "Türkçe anlamı gör, İngilizce kelimeyi seç"
        case .mixed: return "Her iki yön karışık — sınav için en iyisi"
        }
    }

    func resolvedDirection() -> Direction {
        switch self {
        case .enToTr: return .enToTr
        case .trToEn: return .trToEn
        case .mixed: return Bool.random() ? .enToTr : .trToEn
        }
    }
}

// MARK: - Game modes

enum GameMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case wordCannon, wordSlice, meaningFactory, monsterBattle, wordHuntMirror, wordInvaders

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wordCannon: return "Word Cannon"
        case .wordSlice: return "Word Slice"
        case .meaningFactory: return "Meaning Factory"
        case .monsterBattle: return "Monster Battle"
        case .wordHuntMirror: return "Word Hunt Mirror"
        case .wordInvaders: return "Word Circuit"
        }
    }

    var emoji: String {
        switch self {
        case .wordCannon: return "🎯"
        case .wordSlice: return "⚔️"
        case .meaningFactory: return "🏭"
        case .monsterBattle: return "👾"
        case .wordHuntMirror: return "🔎"
        case .wordInvaders: return "🔌"
        }
    }

    var shortDescription: String {
        switch self {
        case .wordCannon: return "Nişan al ve kelime toplarını doğru anlam hedefine fırlat."
        case .wordSlice: return "Kelimeler uçar — sadece doğru olanı kes."
        case .meaningFactory: return "Bant üzerindeki kelimeleri doğru anlam makinesine ayır."
        case .monsterBattle: return "Canavara zarar vermek için doğru kelimeyi fırlat."
        case .wordHuntMirror: return "Harf ızgarasında gizli kelimeyi bul, sonra yönü değiştir."
        case .wordInvaders: return "Hedef anlam ailesindeki kelimeleri tek devrede bağla."
        }
    }

    var bestFor: String {
        switch self {
        case .wordCannon: return "Yeni kelimeler öğren"
        case .wordSlice: return "Karışan kelimeleri ayırt et"
        case .meaningFactory: return "Hızlı tekrar yap"
        case .monsterBattle: return "Zayıf kelimeleri tekrar et"
        case .wordHuntMirror: return "Anlamı bul, kelimeyi hatırla"
        case .wordInvaders: return "Benzer anlamları bağla"
        }
    }

    var difficultyLabel: String {
        switch self {
        case .wordCannon: return "Başlamak için kolay"
        case .wordSlice: return "Reaksiyon hızı"
        case .meaningFactory: return "Baskı altında sıralama"
        case .monsterBattle: return "Tekrar mücadelesi"
        case .wordHuntMirror: return "Dikkat ve arama"
        case .wordInvaders: return "Rota ve devre planı"
        }
    }

    var instruction: String {
        switch self {
        case .wordCannon: return "Doğru anlama sahip kaleye nişan almak için sürükle, ateşlemek için bırak."
        case .wordSlice: return "Doğru uçan kelimeyi kaydırarak kes. Yanlış kelimelerden ve bombalardan kaçın!"
        case .meaningFactory: return "Her kelimeyi bantan alıp doğru makineye bırak."
        case .monsterBattle: return "Canavar saldırmadan önce doğru kelimeyi ona fırlat."
        case .wordHuntMirror: return "Listedeki kelimelerin karşılıkları ızgarada gizli. Bulduğun kelimenin üzerinden parmağını kaydırarak çiz."
        case .wordInvaders: return "Parmağını kaldırmadan başlangıçtan çıkışa bir devre çiz; hedef anlam ailesindeki tüm kelimeleri bağla."
        }
    }

    /// Round countdown in seconds (arcade timer shown in the HUD).
    var roundDuration: Int {
        switch self {
        case .wordCannon: return 90
        case .wordSlice: return 75
        case .meaningFactory: return 100
        case .monsterBattle: return 75
        case .wordHuntMirror: return 110
        case .wordInvaders: return 150
        }
    }
}

// MARK: - Session kind

enum SessionKind: Codable, Hashable {
    /// A normal free-play round.
    case freePlay
    /// A step of today's mission.
    case dailyMission
    /// A weak-words-only revenge round.
    case weakWords
}

// MARK: - Question

/// What a question asks about the word.
enum QuestionVariant: Hashable {
    /// Match the word with its meaning (the normal case).
    case meaning
    /// Sort the word by its part of speech (Meaning Factory interlude rounds).
    case partOfSpeech
}

struct Question: Identifiable, Hashable {
    let id = UUID()
    let word: Word
    let direction: Direction
    /// Shuffled answer strings, including the correct one.
    let options: [String]
    var variant: QuestionVariant = .meaning

    var prompt: String {
        switch variant {
        case .meaning:
            return direction == .enToTr ? word.englishWord : word.turkishMeaning
        case .partOfSpeech:
            return word.englishWord
        }
    }

    var correctAnswer: String {
        switch variant {
        case .meaning:
            return direction == .enToTr ? word.turkishMeaning : word.englishWord
        case .partOfSpeech:
            return word.partOfSpeech.turkishName
        }
    }

    /// "prevent = önlemek" — the consistent reveal format.
    var revealText: String {
        switch variant {
        case .meaning:
            return "\(word.englishWord) = \(word.turkishMeaning)"
        case .partOfSpeech:
            return "\(word.englishWord) = \(word.partOfSpeech.turkishName)"
        }
    }
}

// MARK: - Round result

struct GameResult {
    var mode: GameMode
    var kind: SessionKind
    var totalQuestions: Int
    var correctCount: Int
    var wrongCount: Int
    var xpEarned: Int
    var score: Int
    var maxCombo: Int
    var practicedWords: [Word]
    var newlyMasteredWords: [Word]
    var weakWords: [Word]
    var missionBonusXP: Int = 0

    var accuracy: Double {
        let attempts = correctCount + wrongCount
        guard attempts > 0 else { return 0 }
        return Double(correctCount) / Double(attempts)
    }
}
