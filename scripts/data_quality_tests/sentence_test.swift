import Foundation

func runExampleSentenceQualityTests(words: [Word]) {
    print("— Example sentence quality (no reintroduced verb/object mismatches)")
    let narrowPhrases: [(phrase: String, allowed: Set<String>)] = [
        ("a crucial role in future developments", ["play"]),
        ("a serious threat to local biodiversity", ["pose", "present", "constitute", "create", "reveal", "indicate", "identify"]),
    ]
    var violations = 0
    for word in words {
        let sentence = word.exampleSentenceEN.lowercased()
        for (phrase, allowed) in narrowPhrases {
            guard sentence.contains(phrase) else { continue }
            let verb = word.englishWord.lowercased()
            if word.partOfSpeech == .verb, !allowed.contains(verb) {
                violations += 1
                print("  ❌ FAIL: '\(word.englishWord)' paired with narrow phrase '\(phrase)'")
            }
        }
    }
    expect(violations == 0, "no verb/narrow-object mismatches across \(words.count) words")

    let predicativeOnly: Set<String> = ["afraid", "alive", "asleep", "aware", "unable"]
    var predicativeViolations = 0
    for word in words where word.partOfSpeech == .adjective && predicativeOnly.contains(word.englishWord.lowercased()) {
        if word.exampleSentenceEN.lowercased().hasPrefix("a \(word.englishWord.lowercased())")
            || word.exampleSentenceEN.lowercased().contains(" a \(word.englishWord.lowercased()) ") {
            predicativeViolations += 1
            print("  ❌ FAIL: predicative-only adjective '\(word.englishWord)' used attributively")
        }
    }
    expect(predicativeViolations == 0, "predicative-only adjectives never forced into attributive position")

    var doubledWordViolations = 0
    for word in words {
        let en = word.englishWord.lowercased()
        guard en.count > 2 else { continue }
        let sentence = word.exampleSentenceEN.lowercased()
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: en))\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
        let range = NSRange(sentence.startIndex..., in: sentence)
        let count = regex.numberOfMatches(in: sentence, range: range)
        if count >= 2 {
            doubledWordViolations += 1
            print("  ❌ FAIL: '\(word.englishWord)' appears twice in its own example sentence: \(word.exampleSentenceEN)")
        }
    }
    expect(doubledWordViolations == 0, "no word appears twice in its own example sentence (template/word collision)")

    print("— a/an article agreement")
    let yooSoundPrefixes = ["uni","use","used","user","usual","utopi","utilit","ubiquitous","euro","eu","one","once","ouija"]
    let silentH = ["honest","honor","honour","hour","heir"]
    func correctArticle(_ word: String) -> String {
        let lw = word.lowercased()
        if silentH.contains(where: { lw.hasPrefix($0) }) { return "an" }
        if let first = lw.first, "aeiou".contains(first) {
            return yooSoundPrefixes.contains(where: { lw.hasPrefix($0) }) ? "a" : "an"
        }
        return "a"
    }
    var articleViolations = 0
    for word in words {
        let correct = correctArticle(word.englishWord)
        let wrong = correct == "a" ? "an" : "a"
        let pattern = "\\b\(wrong)\\s+\(NSRegularExpression.escapedPattern(for: word.englishWord))\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
        let sentence = word.exampleSentenceEN
        let range = NSRange(sentence.startIndex..., in: sentence)
        if regex.firstMatch(in: sentence, range: range) != nil {
            articleViolations += 1
            print("  ❌ FAIL: '\(word.englishWord)' has wrong article in: \(sentence)")
        }
    }
    expect(articleViolations == 0, "no a/an article mismatches across \(words.count) words")

    print("— no unrecoverable single/double-letter English word entries")
    let knownValidShortWords: Set<String> = ["go", "do", "ad", "pa", "so", "no", "on", "in", "up", "if", "be", "as", "at", "or", "an", "is", "it"]
    let junkWords = words.filter {
        $0.englishWord.count <= 2 && $0.englishWord.allSatisfy(\.isLetter)
            && !knownValidShortWords.contains($0.englishWord.lowercased())
    }
    expect(junkWords.isEmpty, "no 1-2 letter word entries remain (found: \(junkWords.map(\.englishWord)))")

    print("— phrase-category entries read as natural sentences, not template collisions")
    var phraseCollisions = 0
    for word in words where word.partOfSpeech == .phrase {
        let sentence = word.exampleSentenceEN.lowercased()
        if sentence.contains("the role of \(word.englishWord.lowercased())")
            || sentence.contains("illustrates how \(word.englishWord.lowercased())")
            || sentence.contains("suggests that \(word.englishWord.lowercased())")
            || sentence.contains("analysis of \(word.englishWord.lowercased())") {
            phraseCollisions += 1
            print("  ❌ FAIL: phrase '\(word.englishWord)' still in a noun-slot template: \(word.exampleSentenceEN)")
        }
    }
    expect(phraseCollisions == 0, "no phrase-category word left in a mismatched noun-slot template")
}
