import Foundation

/// A themed subset of the word database (e.g. "Essential YDS 100", "Confusing Words").
/// Packs reference word IDs so they survive database re-imports.
struct WordPack: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let packDescription: String
    let emoji: String
    let wordIDs: [Int]

    /// Planned pack lineup for the full 5000-word database.
    /// Only the sample packs below have IDs wired up in the prototype.
    static let plannedPackNames: [String] = [
        "Essential YDS 100", "Core Academic Verbs", "Common YDS Nouns",
        "Common YDS Adjectives", "Confusing Words", "Advanced Academic Words",
        "Synonyms", "Negative Meaning Words", "Positive Meaning Words",
        "Cause and Effect Words", "Contrast Words", "Exam Traps",
    ]

    /// Builds the sample packs from whatever words are currently loaded.
    static func samplePacks(from words: [Word]) -> [WordPack] {
        let verbs = words.filter { $0.partOfSpeech == .verb }.map(\.id)
        let confusing = words.filter { !$0.confusingWords.isEmpty }.map(\.id)
        return [
            WordPack(
                id: "essential-starter",
                name: "Essential YDS Starter",
                packDescription: "The highest-frequency YDS words. Start here.",
                emoji: "⭐️",
                wordIDs: words.map(\.id)
            ),
            WordPack(
                id: "core-academic-verbs",
                name: "Core Academic Verbs",
                packDescription: "The verbs that carry every YDS sentence.",
                emoji: "🏃",
                wordIDs: verbs
            ),
            WordPack(
                id: "confusing-words",
                name: "Confusing Words",
                packDescription: "prevent / provide / prove and other exam traps.",
                emoji: "🌀",
                wordIDs: confusing
            ),
        ]
    }
}
