import Foundation

/// Stores the user profile and per-word progress as JSON files in
/// Application Support. Fully offline; no account needed.
final class PersistenceController {
    static let shared = PersistenceController()

    private let directory: URL
    private var profileURL: URL { directory.appendingPathComponent("profile.json") }
    private var progressURL: URL { directory.appendingPathComponent("progress.json") }

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.directory = base.appendingPathComponent("YDSMaster", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    // MARK: Profile

    func loadProfile() -> UserProfile? {
        guard let data = try? Data(contentsOf: profileURL) else { return nil }
        return try? decoder.decode(UserProfile.self, from: data)
    }

    func saveProfile(_ profile: UserProfile) {
        if let data = try? encoder.encode(profile) {
            try? data.write(to: profileURL, options: .atomic)
        }
    }

    // MARK: Progress

    func loadProgress() -> [Int: WordProgress] {
        guard let data = try? Data(contentsOf: progressURL),
              let list = try? decoder.decode([WordProgress].self, from: data)
        else { return [:] }
        return Dictionary(uniqueKeysWithValues: list.map { ($0.wordID, $0) })
    }

    func saveProgress(_ progress: [Int: WordProgress]) {
        let list = progress.values.sorted { $0.wordID < $1.wordID }
        if let data = try? encoder.encode(list) {
            try? data.write(to: progressURL, options: .atomic)
        }
    }
}
