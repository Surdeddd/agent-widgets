import AWKit
import SwiftUI

struct FlashCard: Codable, Sendable {
    let word: String
    let translation: String
    let example: String
}

struct FlashcardsData: Codable, Sendable {
    let kicker: String
    let cards: [FlashCard]
}

struct FlashcardsView: AWView {
    static var tick: AWTick { .every(seconds: 900, count: 8) }

    let entry: AWEntry<FlashcardsData>
    @Environment(\.aw) private var context

    init(entry: AWEntry<FlashcardsData>) {
        self.entry = entry
    }

    var body: some View {
        AWPhaseView(entry) { data in
            if data.cards.isEmpty {
                AWEmptyState(symbol: "rectangle.stack", title: context.pick(en: "No cards yet", ru: "Карточек пока нет"))
            } else {
                deck(data)
            }
        }
    }

    private func deck(_ data: FlashcardsData) -> some View {
        let slot = Int(entry.date.timeIntervalSince1970 / 900)
        let index = entry.state.deckIndex(count: data.cards.count, slot: slot)
        let card = data.cards[index]
        let isLarge = context.family == .large
        let isLong = card.word.count > 16
        return VStack(alignment: .leading, spacing: AWMetrics.spacing(for: context.family)) {
            AWHeader(data.kicker, symbol: "character.book.closed", entry: entry)
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: isLarge ? AWSpace.m : 2) {
                AWText(card.word, isLarge ? .hero : (isLong ? .title : .display), lines: isLarge || isLong ? 2 : 1)
                AWText(card.translation, .headline, lines: context.family == .medium ? 1 : 2)
                    .foregroundStyle(.secondary)
                if isLarge {
                    quote(card.example)
                }
            }
            Spacer(minLength: 0)
            controls(count: data.cards.count, index: index)
        }
    }

    private func quote(_ text: String) -> some View {
        HStack(alignment: .top, spacing: AWSpace.s) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(.tertiary)
                .frame(width: 3)
            AWText(text, .body, lines: 4)
                .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func controls(count: Int, index: Int) -> some View {
        HStack(spacing: AWSpace.s) {
            AWButton(.prev, symbol: "chevron.left")
            AWButton(.next, symbol: "chevron.right")
            if !context.isSmall {
                AWText("\(index + 1)/\(count)", .caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            AWButton(entry.state.isShuffled ? .reset : .shuffle, symbol: "shuffle", key: entry.state.isShuffled ? "seed" : "cursor")
        }
    }
}
