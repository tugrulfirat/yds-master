import Foundation

// MARK: - Power-up inventory

struct HintInventory: Codable, Hashable {
    var firstLetter: Int = 3
    var removeWrong: Int = 3
    var slowMotion: Int = 2
    var magnet: Int = 2
    var shield: Int = 1
}

enum PowerUp: String, Codable, CaseIterable, Identifiable {
    case firstLetter, removeWrong, slowMotion, magnet, shield

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstLetter: return "İlk Harf"
        case .removeWrong: return "Yanlışı Kaldır"
        case .slowMotion: return "Yavaş Çekim"
        case .magnet: return "Mıknatıs"
        case .shield: return "Kalkan"
        }
    }

    var emoji: String {
        switch self {
        case .firstLetter: return "🔤"
        case .removeWrong: return "✂️"
        case .slowMotion: return "🐌"
        case .magnet: return "🧲"
        case .shield: return "🛡️"
        }
    }
}

// MARK: - Daily mission

struct DailyMissionState: Codable, Hashable {
    /// Start-of-day this state belongs to.
    var day: Date?
    var completedModes: Set<GameMode> = []
    var bonusClaimed: Bool = false

    /// Mission steps, in the recommended order.
    static let steps: [GameMode] = [.wordCannon, .wordSlice, .meaningFactory, .monsterBattle]

    var isComplete: Bool { completedModes.count >= Self.steps.count }

    var nextStep: GameMode? {
        Self.steps.first { !completedModes.contains($0) }
    }
}

// MARK: - Badges

struct Badge: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let emoji: String

    static let all: [Badge] = [
        Badge(id: "first-round", title: "İlk Tur", emoji: "🎉"),
        Badge(id: "streak-3", title: "3 Günlük Seri", emoji: "🔥"),
        Badge(id: "streak-7", title: "7 Günlük Seri", emoji: "🌋"),
        Badge(id: "mastered-10", title: "10 Kelimede Ustalaşıldı", emoji: "🏅"),
        Badge(id: "combo-8", title: "Kombo ×8", emoji: "⚡️"),
        Badge(id: "boss-slayer", title: "Boss Avcısı", emoji: "🗡️"),
        Badge(id: "mission-complete", title: "Tam Görev Günü", emoji: "🚀"),
    ]
}

// MARK: - User profile

struct UserProfile: Codable, Hashable {
    var hasOnboarded: Bool = false
    var dailyGoal: Int = 20
    var startingDifficulty: DifficultyLevel = .beginner
    var directionPreference: DirectionPreference = .mixed

    var xp: Int = 0
    var streak: Int = 0
    var lastPlayedDay: Date?

    var hints: HintInventory = HintInventory()
    /// Last calendar day hints were topped back up to their daily minimums.
    /// Optional so profiles saved before this existed still decode.
    var lastHintRefillDay: Date?
    var earnedBadgeIDs: Set<String> = []
    var dailyMission: DailyMissionState = DailyMissionState()
    var bestCombo: Int = 0
    var roundsPlayed: Int = 0

    // MARK: Audio preferences

    /// Stored as optionals so profiles saved before the audio update still
    /// decode (a missing key becomes nil instead of a decoding failure that
    /// would silently reset the whole profile).
    private var soundEnabledStorage: Bool?
    private var musicEnabledStorage: Bool?

    var soundEnabled: Bool {
        get { soundEnabledStorage ?? true }
        set { soundEnabledStorage = newValue }
    }

    var musicEnabled: Bool {
        get { musicEnabledStorage ?? true }
        set { musicEnabledStorage = newValue }
    }

    // MARK: Levels

    /// XP needed to go from `level` to `level + 1`.
    static func xpNeeded(forLevel level: Int) -> Int { 150 + (level - 1) * 75 }

    var level: Int {
        var lvl = 1
        var remaining = xp
        while remaining >= Self.xpNeeded(forLevel: lvl) {
            remaining -= Self.xpNeeded(forLevel: lvl)
            lvl += 1
        }
        return lvl
    }

    /// Progress toward the next level, 0...1.
    var levelProgress: Double {
        var lvl = 1
        var remaining = xp
        while remaining >= Self.xpNeeded(forLevel: lvl) {
            remaining -= Self.xpNeeded(forLevel: lvl)
            lvl += 1
        }
        return Double(remaining) / Double(Self.xpNeeded(forLevel: lvl))
    }
}
