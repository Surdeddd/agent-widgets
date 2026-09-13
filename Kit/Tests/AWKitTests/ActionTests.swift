import AWSchema
import Foundation
import Testing
@testable import AWKit

@Test func deckVisitsEveryCardOncePerCycle() {
    for count in 1...50 {
        for seed in [0, 1, 2, 7, 123_456, 9_999_999, -42] {
            let order = (0..<count).map { AWDeck.index($0, count: count, seed: seed) }
            #expect(Set(order) == Set(0..<count), "count \(count) seed \(seed)")
        }
    }
}

@Test func deckWrapsBothWays() {
    #expect(AWDeck.index(-1, count: 5) == 4)
    #expect(AWDeck.index(7, count: 5) == 2)
    #expect(AWDeck.index(3, count: 0) == 0)
}

@Test func seededDeckIsScrambledButStable() {
    let plain = (0..<10).map { AWDeck.index($0, count: 10) }
    let shuffled = (0..<10).map { AWDeck.index($0, count: 10, seed: 4_242) }
    #expect(plain == Array(0..<10))
    #expect(shuffled != plain)
    #expect(shuffled == (0..<10).map { AWDeck.index($0, count: 10, seed: 4_242) })
}

@Test func stepActionsMoveTheCursor() {
    let state = AWState()
    #expect(state.applying(.next).cursor == 1)
    #expect(state.applying(.prev).cursor == -1)
    #expect(state.applying(.next).applying(.next).deckIndex(count: 3, slot: 2) == 1)
}

@Test func valueActionsEditAnyKey() {
    let state = AWState()
    #expect(state.applying(.toggle, key: "done").bool("done"))
    #expect(!state.applying(.toggle, key: "done").applying(.toggle, key: "done").bool("done"))
    #expect(state.applying(.increment, key: "cups").int("cups") == 1)
    #expect(state.applying(.increment, key: "cups", value: "2.5").double("cups") == 2.5)
    #expect(state.applying(.set, key: "mode", value: "focus").string("mode") == "focus")
    #expect(state.applying(.set, key: "goal", value: "8").int("goal") == 8)
    #expect(state.applying(.set, key: "on", value: "true").bool("on"))
}

@Test func shuffleNeedsANewSeedAndRestartsTheDeck() {
    let moved = AWState().applying(.next).applying(.next)
    let shuffled = moved.applying(.shuffle) { 77 }
    #expect(shuffled.seed == 77)
    #expect(shuffled.cursor == 0)
    #expect(shuffled.isShuffled)
    #expect(shuffled.applying(.shuffle) { 77 }.seed == 78)
    #expect(AWState().applying(.shuffle) { 0 }.seed == 1)
    #expect(!shuffled.applying(.reset, key: AWState.seedKey).isShuffled)
}

@Test func resetClearsOneKeyOrEverything() {
    let state = AWState(["cursor": .number(3), "done": .bool(true)])
    #expect(state.applying(.reset).values["cursor"] == nil)
    #expect(state.applying(.reset).bool("done"))
    #expect(state.applying(.reset, key: "").values.isEmpty)
}

@Test func buttonIntentCarriesTheWidgetFromContext() {
    let intent = AWActionIntent(widget: "cards", kind: "aw.cards", action: .next, key: "cursor", value: "")
    #expect(intent.widget == "cards")
    #expect(intent.kind == "aw.cards")
    #expect(intent.action == "next")
}
