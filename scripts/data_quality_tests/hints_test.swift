import Foundation

func runHintRefillTests(store: WordStore) {
    print("— Power-up (hint) daily refill")
    // Exhaust every power-up.
    while store.consumePowerUp(.firstLetter) {}
    while store.consumePowerUp(.removeWrong) {}
    while store.consumePowerUp(.slowMotion) {}
    while store.consumePowerUp(.magnet) {}
    while store.consumePowerUp(.shield) {}
    expect(store.powerUpCount(.firstLetter) == 0, "firstLetter exhausted")
    expect(store.powerUpCount(.shield) == 0, "shield exhausted")

    // Simulate the next calendar day and re-trigger the refresh path the
    // app calls on every Home screen appearance.
    store.profile.lastHintRefillDay = Calendar.current.date(byAdding: .day, value: -1, to: Date())
    store.profile.dailyMission = DailyMissionState(day: Calendar.current.date(byAdding: .day, value: -1, to: Date()))
    store.refreshDailyMissionIfNeeded()

    expect(store.powerUpCount(.firstLetter) == HintInventory().firstLetter, "firstLetter refilled to baseline (got \(store.powerUpCount(.firstLetter)))")
    expect(store.powerUpCount(.removeWrong) == HintInventory().removeWrong, "removeWrong refilled to baseline")
    expect(store.powerUpCount(.slowMotion) == HintInventory().slowMotion, "slowMotion refilled to baseline")
    expect(store.powerUpCount(.magnet) == HintInventory().magnet, "magnet refilled to baseline")
    expect(store.powerUpCount(.shield) == HintInventory().shield, "shield refilled to baseline (got \(store.powerUpCount(.shield)))")

    // Refilling again same day must not double-grant beyond baseline.
    _ = store.consumePowerUp(.shield)
    store.refreshDailyMissionIfNeeded()
    expect(store.powerUpCount(.shield) == HintInventory().shield - 1, "same-day refresh does not re-grant an already-spent power-up")

    // A bonus stash above baseline (e.g. future IAP) must never be reduced by a refill.
    store.profile.hints.magnet = HintInventory().magnet + 5
    store.profile.lastHintRefillDay = Calendar.current.date(byAdding: .day, value: -1, to: Date())
    store.refreshDailyMissionIfNeeded()
    expect(store.powerUpCount(.magnet) == HintInventory().magnet + 5, "refill never lowers a stash above baseline")
}
