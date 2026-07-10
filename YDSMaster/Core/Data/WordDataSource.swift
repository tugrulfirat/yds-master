import Foundation

// MARK: - Data source abstraction

/// Anything that can supply the vocabulary database.
///
/// The prototype ships `BundledJSONWordDataSource`. When the full 5000-word
/// database arrives, add a new conformer (CSV, SQLite, Core Data import…)
/// and inject it into `WordStore` — nothing else in the app changes.
protocol WordDataSource {
    func loadWords() throws -> [Word]
}

enum WordDataSourceError: Error, LocalizedError {
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let name): return "Word database file not found: \(name)"
        }
    }
}

// MARK: - Bundled JSON

/// Loads `words.json` from the app bundle (or any file URL, for tests/imports).
///
/// Expected JSON shape: an array of `Word` objects — see `words.json`.
/// A 5000-word file in the same format can simply replace the bundled one.
struct BundledJSONWordDataSource: WordDataSource {
    let fileURL: URL?
    let resourceName: String

    init(resourceName: String = "words") {
        self.resourceName = resourceName
        self.fileURL = nil
    }

    init(fileURL: URL) {
        self.resourceName = fileURL.lastPathComponent
        self.fileURL = fileURL
    }

    func loadWords() throws -> [Word] {
        let url: URL
        if let fileURL {
            url = fileURL
        } else if let bundled = Bundle.main.url(forResource: resourceName, withExtension: "json") {
            url = bundled
        } else {
            throw WordDataSourceError.fileNotFound("\(resourceName).json")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Word].self, from: data)
    }
}

// MARK: - CSV (import path for the future 5000-word database)

/// Minimal CSV importer so the big database can arrive as a spreadsheet export.
/// Columns: id,englishWord,turkishMeaning,partOfSpeech,difficultyLevel,category,
/// ydsFrequencyRank,exampleSentenceEN,exampleSentenceTR,synonyms,confusingWords
/// (synonyms/confusingWords are `|`-separated inside the cell).
struct CSVWordDataSource: WordDataSource {
    let fileURL: URL

    func loadWords() throws -> [Word] {
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        var words: [Word] = []
        let rows = text.split(whereSeparator: \.isNewline).dropFirst() // skip header
        for row in rows {
            let cols = row.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard cols.count >= 11,
                  let id = Int(cols[0]),
                  let pos = PartOfSpeech(rawValue: cols[3]),
                  let diffRaw = Int(cols[4]),
                  let diff = DifficultyLevel(rawValue: diffRaw),
                  let rank = Int(cols[6])
            else { continue }
            words.append(Word(
                id: id,
                englishWord: cols[1],
                turkishMeaning: cols[2],
                partOfSpeech: pos,
                difficultyLevel: diff,
                category: cols[5],
                ydsFrequencyRank: rank,
                exampleSentenceEN: cols[7],
                exampleSentenceTR: cols[8],
                synonyms: cols[9].split(separator: "|").map(String.init),
                confusingWords: cols[10].split(separator: "|").map(String.init)
            ))
        }
        return words
    }
}
