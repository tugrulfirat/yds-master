import Foundation
import Combine

/// Central observable state: the word database, per-word progress,
/// the user profile, word selection, and progress/streak/XP updates.
final class WordStore: ObservableObject {

    @Published private(set) var words: [Word] = []
    @Published private(set) var progress: [Int: WordProgress] = [:]
    @Published var profile: UserProfile

    // MARK: Free tier

    /// The highest-frequency words playable without a subscription.
    static let freeWordCount = 500

    /// Mirrored from `PremiumStore.isPremium` by the app root.
    @Published var isPremium = false

    /// Words available for gameplay under the current entitlement — `words`
    /// is sorted by frequency rank, so the free tier is exactly the
    /// `freeWordCount` most exam-critical words.
    var playableWords: [Word] {
        isPremium ? words : Array(words.prefix(Self.freeWordCount))
    }

    func isLocked(_ word: Word) -> Bool {
        guard !isPremium else { return false }
        guard let index = words.firstIndex(of: word) else { return false }
        return index >= Self.freeWordCount
    }

    let engine = WordEngine()
    private let persistence: PersistenceController
    private(set) var packs: [WordPack] = []
    private(set) var loadError: String?

    private var calendar: Calendar { Calendar.current }

    init(
        dataSource: WordDataSource = BundledJSONWordDataSource(),
        persistence: PersistenceController = .shared
    ) {
        self.persistence = persistence
        self.profile = persistence.loadProfile() ?? UserProfile()
        self.progress = persistence.loadProgress()
        do {
            self.words = try dataSource.loadWords().sorted { $0.ydsFrequencyRank < $1.ydsFrequencyRank }
        } catch {
            self.loadError = error.localizedDescription
            self.words = []
        }
        self.packs = WordPack.samplePacks(from: words)
        refreshDailyMissionIfNeeded()
        SoundManager.shared.isSoundEnabled = profile.soundEnabled
        SoundManager.shared.isMusicEnabled = profile.musicEnabled
    }

    // MARK: - Audio preferences

    func toggleSound() {
        profile.soundEnabled.toggle()
        SoundManager.shared.isSoundEnabled = profile.soundEnabled
        saveProfile()
    }

    func toggleMusic() {
        profile.musicEnabled.toggle()
        SoundManager.shared.isMusicEnabled = profile.musicEnabled
        saveProfile()
    }

    // MARK: - Progress access

    func progress(for word: Word) -> WordProgress {
        progress[word.id] ?? WordProgress(wordID: word.id)
    }

    // MARK: - Stats

    var learnedCount: Int { words.filter { progress(for: $0).isLearned }.count }
    var masteredCount: Int { words.filter { progress(for: $0).isMastered }.count }
    var weakCount: Int { words.filter { progress(for: $0).isWeak }.count }
    var seenCount: Int { words.filter { progress(for: $0).timesSeen > 0 }.count }

    /// Average mastery 0...1 across the words the user has actually studied.
    /// Deliberately NOT divided by the whole 5,000-word database — that
    /// denominator makes early progress round to 0% and the home-screen
    /// "İlerleme" chip look frozen no matter how much the user plays.
    var overallMastery: Double {
        let seen = words.filter { progress(for: $0).timesSeen > 0 }
        guard !seen.isEmpty else { return 0 }
        let total = seen.reduce(0) { $0 + progress(for: $1).masteryScore }
        return Double(total) / Double(seen.count * 100)
    }

    // MARK: - Word selection

    /// Unseen words, easiest-fit for the user's chosen difficulty, by frequency rank.
    func newWords(count: Int) -> [Word] {
        let unseen = playableWords.filter { progress(for: $0).timesSeen == 0 }
        let preferred = unseen.filter { $0.difficultyLevel <= profile.startingDifficulty }
        let rest = unseen.filter { $0.difficultyLevel > profile.startingDifficulty }
        return Array((preferred + rest).prefix(count))
    }

    /// Seen words whose spaced-repetition review is due, most overdue first.
    func dueReviewWords(count: Int) -> [Word] {
        playableWords
            .filter { progress(for: $0).isDueForReview }
            .sorted {
                (progress(for: $0).nextReviewAt ?? .distantPast) <
                (progress(for: $1).nextReviewAt ?? .distantPast)
            }
            .prefix(count)
            .map { $0 }
    }

    /// Words the user keeps missing, worst first.
    func weakWords(count: Int = .max) -> [Word] {
        playableWords
            .filter { progress(for: $0).isWeak }
            .sorted { progress(for: $0).timesWrong > progress(for: $1).timesWrong }
            .prefix(count)
            .map { $0 }
    }

    /// The standard round mix: ~50% new, ~30% due review, ~20% weak,
    /// topped up with more new/seen words if any bucket runs dry.
    func sessionWords(count: Int, kind: SessionKind = .freePlay) -> [Word] {
        if kind == .weakWords {
            var picked = weakWords(count: count)
            if picked.count < count {
                picked += dueReviewWords(count: count - picked.count).filter { !picked.contains($0) }
            }
            if picked.count < count {
                picked += newWords(count: count - picked.count)
            }
            return picked.shuffled()
        }

        let newTarget = Int((Double(count) * 0.5).rounded())
        let reviewTarget = Int((Double(count) * 0.3).rounded())

        var picked: [Word] = []
        picked += newWords(count: newTarget)
        picked += dueReviewWords(count: reviewTarget).filter { !picked.contains($0) }
        picked += weakWords(count: count - picked.count).filter { !picked.contains($0) }

        if picked.count < count {
            picked += newWords(count: count).filter { !picked.contains($0) }.prefix(count - picked.count)
        }
        if picked.count < count {
            let anySeen = playableWords.filter { progress(for: $0).timesSeen > 0 && !picked.contains($0) }
            picked += anySeen.shuffled().prefix(count - picked.count)
        }
        return picked.shuffled()
    }

    /// Boss rounds re-use previously missed and confusing words — review, not new material.
    func bossWords(count: Int) -> [Word] {
        var picked = weakWords(count: count)
        if picked.count < count {
            let confusingSeen = playableWords.filter {
                !$0.confusingWords.isEmpty && progress(for: $0).timesSeen > 0 && !picked.contains($0)
            }
            picked += confusingSeen.shuffled().prefix(count - picked.count)
        }
        if picked.count < count {
            picked += dueReviewWords(count: count - picked.count).filter { !picked.contains($0) }
        }
        if picked.count < count {
            picked += playableWords.shuffled().filter { !picked.contains($0) }.prefix(count - picked.count)
        }
        return picked.shuffled()
    }

    // MARK: - Answer recording

    func registerCorrect(word: Word, firstTry: Bool) {
        var p = progress(for: word)
        p.registerCorrect(firstTry: firstTry)
        progress[word.id] = p
        persistence.saveProgress(progress)
    }

    func registerWrong(word: Word) {
        var p = progress(for: word)
        p.registerWrong()
        progress[word.id] = p
        persistence.saveProgress(progress)
    }

    // MARK: - Round completion

    /// Applies XP, streak, mission progress and badges. Returns mission bonus XP (0 if none).
    @discardableResult
    func completeRound(result: GameResult) -> Int {
        profile.xp += result.xpEarned
        profile.roundsPlayed += 1
        profile.bestCombo = max(profile.bestCombo, result.maxCombo)
        updateStreak()

        var bonus = 0
        if result.kind == .dailyMission {
            refreshDailyMissionIfNeeded()
            profile.dailyMission.completedModes.insert(result.mode)
            if profile.dailyMission.isComplete && !profile.dailyMission.bonusClaimed {
                profile.dailyMission.bonusClaimed = true
                bonus = 100
                profile.xp += bonus
                earnBadge("mission-complete")
            }
        }

        if profile.roundsPlayed == 1 { earnBadge("first-round") }
        if profile.streak >= 3 { earnBadge("streak-3") }
        if profile.streak >= 7 { earnBadge("streak-7") }
        if masteredCount >= 10 { earnBadge("mastered-10") }
        if result.maxCombo >= 8 { earnBadge("combo-8") }

        saveProfile()
        return bonus
    }

    func earnBadge(_ id: String) {
        profile.earnedBadgeIDs.insert(id)
    }

    // MARK: - Power-ups

    func consumePowerUp(_ powerUp: PowerUp) -> Bool {
        switch powerUp {
        case .firstLetter:
            guard profile.hints.firstLetter > 0 else { return false }
            profile.hints.firstLetter -= 1
        case .removeWrong:
            guard profile.hints.removeWrong > 0 else { return false }
            profile.hints.removeWrong -= 1
        case .slowMotion:
            guard profile.hints.slowMotion > 0 else { return false }
            profile.hints.slowMotion -= 1
        case .magnet:
            guard profile.hints.magnet > 0 else { return false }
            profile.hints.magnet -= 1
        case .shield:
            guard profile.hints.shield > 0 else { return false }
            profile.hints.shield -= 1
        }
        saveProfile()
        return true
    }

    func powerUpCount(_ powerUp: PowerUp) -> Int {
        switch powerUp {
        case .firstLetter: return profile.hints.firstLetter
        case .removeWrong: return profile.hints.removeWrong
        case .slowMotion: return profile.hints.slowMotion
        case .magnet: return profile.hints.magnet
        case .shield: return profile.hints.shield
        }
    }

    // MARK: - Streak & daily mission

    private func updateStreak() {
        let today = calendar.startOfDay(for: Date())
        if let last = profile.lastPlayedDay {
            let lastDay = calendar.startOfDay(for: last)
            if lastDay == today { return }
            let gap = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            profile.streak = gap == 1 ? profile.streak + 1 : 1
        } else {
            profile.streak = 1
        }
        profile.lastPlayedDay = today
    }

    func refreshDailyMissionIfNeeded() {
        let today = calendar.startOfDay(for: Date())
        if profile.dailyMission.day != today {
            profile.dailyMission = DailyMissionState(day: today)
        }
        refillHintsIfNeeded()
    }

    /// Tops power-ups back up to their daily baseline once per calendar day.
    /// Previously hints were a one-time pool that, once spent, never
    /// returned — this restores them each day so a bad round doesn't
    /// permanently strand the player without hints.
    private func refillHintsIfNeeded() {
        let today = calendar.startOfDay(for: Date())
        if let last = profile.lastHintRefillDay, calendar.isDate(last, inSameDayAs: today) {
            return
        }
        let baseline = HintInventory()
        profile.hints.firstLetter = max(profile.hints.firstLetter, baseline.firstLetter)
        profile.hints.removeWrong = max(profile.hints.removeWrong, baseline.removeWrong)
        profile.hints.slowMotion = max(profile.hints.slowMotion, baseline.slowMotion)
        profile.hints.magnet = max(profile.hints.magnet, baseline.magnet)
        profile.hints.shield = max(profile.hints.shield, baseline.shield)
        profile.lastHintRefillDay = today
        saveProfile()
    }

    func saveProfile() {
        persistence.saveProfile(profile)
    }

    // MARK: - Onboarding

    func completeOnboarding(goal: Int, difficulty: DifficultyLevel, direction: DirectionPreference) {
        profile.dailyGoal = goal
        profile.startingDifficulty = difficulty
        profile.directionPreference = direction
        profile.hasOnboarded = true
        saveProfile()
    }
}
