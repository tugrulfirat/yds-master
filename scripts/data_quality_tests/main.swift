import Foundation

var failures = 0
func expect(_ condition: Bool, _ label: String) {
    if condition { print("  ✅ \(label)") } else { failures += 1; print("  ❌ FAIL: \(label)") }
}

let wordsURL = URL(fileURLWithPath: CommandLine.arguments[1])
let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("yds-test-\(UUID().uuidString)")
let dataSource = BundledJSONWordDataSource(fileURL: wordsURL)
let store = WordStore(dataSource: dataSource, persistence: PersistenceController(directory: tempDir))

print("— GameMode sanity")
expect(GameMode.allCases.count == 6, "still 6 modes (got \(GameMode.allCases.count))")
expect(!GameMode.wordInvaders.title.isEmpty, "mode has a title (currently \(GameMode.wordInvaders.title))")
expect(GameMode.wordHuntMirror.bestFor == "Anlamı bul, kelimeyi hatırla", "word hunt subtitle updated")

print("— SynonymCluster data")
expect(SynonymCluster.all.count == 10, "10 clusters defined")
expect(SynonymCluster.all.filter(\.isBoss).count == 1, "exactly one boss cluster")

print("— WordInvadersSession core scoring")
let session = WordInvadersSession(store: store, kind: .freePlay)
let wave = session.currentWave
let firstCorrect = wave.correctWords.first!.en
let scoreBefore = session.score
if case .correct(_, let xp, _) = session.resolveShot(word: firstCorrect) {
    expect(session.score > scoreBefore, "score increased on correct shot")
    expect(xp > 0, "xp gained > 0")
} else {
    expect(false, "first correct word should resolve as .correct")
}
if case .correct(_, let xp2, _) = session.resolveShot(word: firstCorrect) {
    expect(xp2 == 0, "re-catch awards 0 XP")
} else {
    expect(false, "re-catch should still be .correct")
}

print("— Wave completion & advance")
let session2 = WordInvadersSession(store: store, kind: .freePlay)
for pair in session2.currentWave.correctWords { _ = session2.resolveShot(word: pair.en) }
expect(session2.advanceWave(), "advanceWave succeeds")
expect(session2.waveIndex == 1, "wave index incremented")

print("— overallMastery moves at 5000-word scale")
expect(store.overallMastery == 0 || store.seenCount > 0, "mastery is 0 only when nothing studied")
if let firstWord = store.words.first(where: { store.progress(for: $0).timesSeen == 0 }) {
    store.registerCorrect(word: firstWord, firstTry: true)
    expect(store.overallMastery > 0, "one correct answer already lifts İlerleme above 0 (got \(store.overallMastery))")
    expect(Int(store.overallMastery * 100) > 0, "displayed percentage is non-zero (got \(Int(store.overallMastery * 100))%)")
}

runBringToFrontTests(store: store)
runFreeTierTests(store: store)
runExampleSentenceQualityTests(words: store.words)
runDistractorFairnessTests()

try? FileManager.default.removeItem(at: tempDir)
print("")
if failures == 0 {
    print("ALL SMOKE TESTS PASSED ✅")
} else {
    print("\(failures) FAILURES ❌")
    exit(1)
}
