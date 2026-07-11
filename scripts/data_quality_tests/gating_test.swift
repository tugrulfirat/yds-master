import Foundation

func runFreeTierTests(store: WordStore) {
    print("— Free tier gating (\(WordStore.freeWordCount) words)")
    store.isPremium = false
    expect(store.playableWords.count == WordStore.freeWordCount, "free tier is exactly \(WordStore.freeWordCount) words (got \(store.playableWords.count))")
    let freeSet = Set(store.playableWords.map(\.id))
    let session = store.sessionWords(count: 12)
    expect(session.allSatisfy { freeSet.contains($0.id) }, "free sessions never draw locked words")
    let boss = store.bossWords(count: 6)
    expect(boss.allSatisfy { freeSet.contains($0.id) }, "boss rounds never draw locked words")
    let lockedWord = store.words.last!
    expect(store.isLocked(lockedWord), "last-ranked word is locked for free users")
    expect(!store.isLocked(store.words.first!), "top-ranked word is free")

    store.isPremium = true
    expect(store.playableWords.count == store.words.count, "premium unlocks the whole database")
    expect(!store.isLocked(lockedWord), "nothing is locked for premium users")
    store.isPremium = false
}
