import Foundation

func runDistractorFairnessTests() {
    print("— Distractor fairness (no synonyms / duplicate options)")
    let engine = WordEngine()
    func fixture(_ id: Int, _ en: String, _ tr: String, synonyms: [String] = []) -> Word {
        Word(
            id: id, englishWord: en, turkishMeaning: tr, partOfSpeech: .verb,
            difficultyLevel: .intermediate, category: "test", ydsFrequencyRank: id,
            exampleSentenceEN: "", exampleSentenceTR: "", synonyms: synonyms, confusingWords: []
        )
    }
    let target = fixture(1, "reduce", "azaltmak", synonyms: ["decrease"])
    let sameMeaning = fixture(2, "diminish", "azaltmak")
    let listedSynonym = fixture(3, "decrease", "düşürmek")
    let reverseSynonym = fixture(4, "lessen", "hafifletmek", synonyms: ["reduce"])
    let partialOverlap = fixture(5, "cut", "kesmek, azaltmak")
    let caseVariant = fixture(6, "shrink", "Azaltmak")
    let legit1 = fixture(7, "increase", "artırmak")
    let legit2 = fixture(8, "prevent", "önlemek")
    let legit3 = fixture(9, "support", "desteklemek")
    let pool = [target, sameMeaning, listedSynonym, reverseSynonym, partialOverlap, caseVariant, legit1, legit2, legit3]

    for direction in [Direction.trToEn, Direction.enToTr] {
        let picks = engine.distractors(for: target, direction: direction, count: 3, pool: pool)
        let ids = Set(picks.map(\.id))
        expect(!ids.contains(2), "\(direction): word sharing the exact meaning excluded")
        expect(!ids.contains(3), "\(direction): listed synonym excluded")
        expect(!ids.contains(4), "\(direction): reverse-listed synonym excluded")
        expect(!ids.contains(5), "\(direction): partial meaning overlap excluded")
        expect(!ids.contains(6), "\(direction): case-variant duplicate excluded")
        expect(picks.count == 3, "\(direction): still fills 3 distractors from legit words (got \(picks.count))")
    }

    let question = engine.makeQuestion(for: target, direction: .trToEn, optionCount: 4, pool: pool)
    let normalizedOptions = question.options.map { $0.lowercased().replacingOccurrences(of: " ", with: "") }
    expect(Set(normalizedOptions).count == question.options.count, "no two options render the same text")
    expect(question.options.contains("reduce"), "correct answer present among options")
}
