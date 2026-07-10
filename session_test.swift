import Foundation

func runBringToFrontTests(store: WordStore) {
    print("— GameSession.bringToFront (word search any-order finds)")
    let words = Array(store.words.prefix(6))
    let gs = GameSession(mode: .wordHuntMirror, kind: .freePlay, store: store, questionCount: 6, words: words)
    expect(gs.totalQuestions == 6, "session has 6 questions")

    let thirdID = gs.questions[2].word.id
    gs.bringToFront(wordID: thirdID)
    expect(gs.current?.word.id == thirdID, "3rd question promoted to current")
    expect(gs.totalQuestions == 6, "promotion keeps queue size (got \(gs.totalQuestions))")

    let scoreBefore = gs.score
    _ = gs.submitJudged(correct: true)
    expect(gs.score > scoreBefore, "promoted question scores on submit")
    gs.advance()
    expect(gs.index == 1, "advance moves on normally after promotion")

    // Promoting the current question is a no-op.
    let currentID = gs.current!.word.id
    gs.bringToFront(wordID: currentID)
    expect(gs.current?.word.id == currentID, "promoting current is a no-op")

    // Promoting an already-answered word does nothing (it's before index).
    gs.bringToFront(wordID: thirdID)
    expect(gs.current?.word.id == currentID, "already-answered word is not re-promoted")

    // Unknown id is a safe no-op.
    gs.bringToFront(wordID: -99)
    expect(gs.current?.word.id == currentID, "unknown wordID is a safe no-op")
}
