import Foundation

/// Generates questions and *smart* distractors.
///
/// Distractors are scored, not random: confusing words, same part of speech,
/// same difficulty, visually similar English spellings and same-category
/// (semantically close) Turkish meanings all rank higher than random picks.
struct WordEngine {

    // MARK: Question generation

    func makeQuestion(
        for word: Word,
        direction: Direction,
        optionCount: Int,
        pool: [Word]
    ) -> Question {
        let distractorWords = distractors(
            for: word,
            direction: direction,
            count: max(1, optionCount - 1),
            pool: pool
        )
        let answer: (Word) -> String = { direction == .enToTr ? $0.turkishMeaning : $0.englishWord }
        var options = [answer(word)] + distractorWords.map(answer)
        options = uniqued(options).shuffled()
        return Question(word: word, direction: direction, options: options)
    }

    /// "Sort by part of speech" question: the answer bins are POS names.
    func makePartOfSpeechQuestion(for word: Word, optionCount: Int) -> Question {
        let mainPOS: [PartOfSpeech] = [.verb, .noun, .adjective, .adverb]
        var pool = mainPOS.filter { $0 != word.partOfSpeech }.shuffled()
        var options = [word.partOfSpeech.turkishName]
        while options.count < min(optionCount, mainPOS.count), let next = pool.popLast() {
            options.append(next.turkishName)
        }
        return Question(
            word: word,
            direction: .enToTr,
            options: options.shuffled(),
            variant: .partOfSpeech
        )
    }

    // MARK: Distractor selection

    func distractors(for word: Word, direction: Direction, count: Int, pool: [Word]) -> [Word] {
        let answerText: (Word) -> String = { direction == .enToTr ? $0.turkishMeaning : $0.englishWord }

        // Normalized comparisons: at 5,000-word scale the pool contains
        // case/whitespace variants and true synonyms of the correct answer.
        // A distractor that is actually right (a synonym, or a word sharing
        // any Turkish meaning) is unfair — the player picks a correct word
        // and gets punished for it.
        func normalized(_ s: String) -> String {
            s.lowercased().replacingOccurrences(of: " ", with: "")
        }
        func meaningTokens(_ s: String) -> Set<String> {
            Set(
                s.lowercased()
                    .components(separatedBy: CharacterSet(charactersIn: "/,;"))
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            )
        }
        let correctNorm = normalized(answerText(word))
        let correctMeanings = meaningTokens(word.turkishMeaning)
        let wordEN = word.englishWord.lowercased()
        let wordSynonyms = Set(word.synonyms.map { $0.lowercased() })

        var scored: [(word: Word, score: Int)] = []
        for candidate in pool {
            guard candidate.id != word.id else { continue }
            let candEN = candidate.englishWord.lowercased()
            guard normalized(answerText(candidate)) != correctNorm,
                  !wordSynonyms.contains(candEN),
                  !candidate.synonyms.contains(where: { $0.lowercased() == wordEN }),
                  meaningTokens(candidate.turkishMeaning).isDisjoint(with: correctMeanings)
            else { continue }
            var score = 0

            // Explicitly confusing words are the best traps.
            if word.confusingWords.contains(where: { $0.lowercased() == candEN }) { score += 5 }
            if candidate.confusingWords.contains(where: { $0.lowercased() == word.englishWord.lowercased() }) { score += 3 }

            if candidate.partOfSpeech == word.partOfSpeech { score += 2 }
            if candidate.difficultyLevel == word.difficultyLevel { score += 1 }
            // Same category ≈ semantically close Turkish meanings.
            if candidate.category == word.category { score += 1 }

            // Visually similar English spellings when English words are the answers.
            if direction == .trToEn {
                if sharedPrefixLength(candEN, word.englishWord.lowercased()) >= 3 { score += 2 }
                if levenshtein(candEN, word.englishWord.lowercased()) <= 3 { score += 2 }
            }

            // Small random jitter so the same distractors don't appear every time.
            score += Int.random(in: 0...1)
            scored.append((candidate, score))
        }

        // Pick top-scored while keeping every option string distinct —
        // two different words can render the same answer text (shared
        // Turkish meanings), which looks like a duplicated option.
        var picked: [Word] = []
        var usedTexts: Set<String> = [correctNorm]
        for entry in scored.sorted(by: { $0.score > $1.score }) {
            let key = normalized(answerText(entry.word))
            guard usedTexts.insert(key).inserted else { continue }
            picked.append(entry.word)
            if picked.count == count { break }
        }
        return picked
    }

    // MARK: String similarity helpers

    private func sharedPrefixLength(_ a: String, _ b: String) -> Int {
        zip(a, b).prefix(while: { $0 == $1 }).count
    }

    func levenshtein(_ a: String, _ b: String) -> Int {
        let aChars = Array(a), bChars = Array(b)
        if aChars.isEmpty { return bChars.count }
        if bChars.isEmpty { return aChars.count }
        var previous = Array(0...bChars.count)
        var current = [Int](repeating: 0, count: bChars.count + 1)
        for i in 1...aChars.count {
            current[0] = i
            for j in 1...bChars.count {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                current[j] = Swift.min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            swap(&previous, &current)
        }
        return previous[bChars.count]
    }

    private func uniqued(_ items: [String]) -> [String] {
        var seen = Set<String>()
        return items.filter { seen.insert($0).inserted }
    }
}
