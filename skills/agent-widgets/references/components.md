# Kit components

Everything here comes from `import AWKit`. Every component reads `@Environment(\.aw)` and adapts its type size to the family, so the same code looks right in small and large.

## Structure

| component | use it for |
|---|---|
| `AWPhaseView(entry) { data in … }` | root of every view: shows content when data exists, otherwise waiting / error states |
| `AWHeader(_ title: String, symbol: String? = nil, entry: AWEntry<M>, lines: Int = 1)` | small caps title with an SF Symbol, freshness (“5m ago”) and a stale badge; `lines: 2` for long titles |
| `AWHeader(_ title:, symbol:, fetchedAt: Date?, isStale: Bool, lines:)` | same, without an entry |
| `AWStaleBadge()` | the stale badge alone |
| `AWEmptyState(symbol: String = "tray", title: String, subtitle: String? = nil)` | your own empty or error message |

## Text and numbers

| component | use it for |
|---|---|
| `AWText(_ string: String, _ role: AWTextRole = .body, lines: Int = 1)` | all text; never ellipsizes silently — previews report `TRUNCATION` |
| `AWMetric(_ value: String, unit: String? = nil, label: String? = nil, trend: AWTrend? = nil, tint: Color? = nil)` | the hero number with unit, caption and trend; `tint` colors the number and fades in monochrome |
| `AWTrendLabel(_ trend: AWTrend)` | “↗ +4.2%” with status color |
| `AWBadge(_ text: String, status: AWStatus = .neutral, showsSymbol: Bool = true)` | a status pill |

`AWTextRole`: `.hero` (numbers, rounded), `.display` (big words — a card, an event, a song that is the point of the widget), `.title`, `.headline`, `.body`, `.caption`, `.label` (small caps). Roles scale per family; the preview checks the fit at each role's minimum scale.

`AWTrend.percent(_ delta: Double, positiveIsGood: Bool = true)` — `delta` is a fraction (`0.042` = 4.2 %).

## Progress and charts

| component | use it for |
|---|---|
| `AWRing(progress: Double, tint: Color = .accentColor, lineWidth: CGFloat? = nil) { center }` | a circular progress ring with anything in the middle; give it a frame |
| `AWRing(progress:tint:lineWidth:)` | ring without a center |
| `AWGauge(value: Double, in: ClosedRange<Double> = 0...1, valueText: String? = nil, label: String? = nil, tint: Color = .accentColor)` | a 270° gauge with the value inside |
| `AWBar(progress: Double, tint: Color = .accentColor, height: CGFloat? = nil)` | a horizontal progress bar |
| `AWSparkline(_ values: [Double], tint: Color = .accentColor, style: AWSparklineStyle = .area, showsLastPoint: Bool = true)` | a trend line; give it a height |
| `AWBarChart(_ items: [AWBarItem], tint: Color = .accentColor, showsLabels: Bool = true)` | small bar charts |
| `AWBarItem(_ label: String, _ value: Double, highlighted: Bool = false, id: String? = nil)` | one bar |

## Lists

```swift
AWList(items, maxRows: context.family == .large ? 8 : 3) { item in
    AWRow(item.name, value: context.isSmall ? nil : item.value, status: item.ok ? .ok : .warning, symbol: "server.rack")
}
```

- `AWList(_ items: [Item], maxRows: Int? = nil, row:)` — `Item` must be `Identifiable`; extra rows collapse into “+N more”.
- `AWRow(_ title: String, value: String? = nil, detail: String? = nil, status: AWStatus? = nil, symbol: String? = nil)`.

## Time

| component | use it for |
|---|---|
| `AWCountdown(to: Date, label: String? = nil, tint: Color? = nil)` | a live countdown (`Text(date, style: .timer)`), no reloads needed |
| `AWClock(date: Date, timeZone: TimeZone = .current, label: String? = nil)` | a clock face in text; pair with `static var tick: AWTick { .everyMinute(count: 60) }` |

`Text(date, style: .relative | .time | .timer)` also works anywhere and keeps ticking without reloads.

## Images

`AWImage(widget: String, name: String, contentMode: ContentMode = .fill)` shows `<name>` from the widget's images folder in the App Group. The feed writes files into `$AW_IMAGES_DIR`; previews read `samples/images/`.

## Buttons and state

```swift
AWButton(.next, symbol: "chevron.right")
AWButton(.increment, key: "cups") { Label("Cup", systemImage: "plus") }
```

- `AWButton(_ action: AWAction, key: String = "cursor", value: String = "", label:)` and `AWButton(_ action:, symbol:, key:, value:)` for a round icon button.
- `AWAction`: `.next`, `.prev` (cursor ± 1), `.toggle`, `.increment` (by `value`, default 1), `.set` (JSON or text `value`), `.shuffle` (new deck order, cursor back to 0), `.reset` (clears `key`, or all state with `key: ""`), `.stamp` (stores the moment of the tap plus `value` seconds — `AWButton(.stamp, key: "endsAt", value: "1500")` starts a 25-minute timer).
- Read state in the view: `entry.state.int("cups") -> Int`, `.bool("done") -> Bool`, `.double(_) -> Double` (all take `default:`, 0 / false otherwise), `.string(_) -> String?`, `.date(_) -> Date?` (for stamps), `.cursor -> Int`.
- Never bake `Date()` or `entry.date` into a button's `value`: the view was drawn minutes before the tap. Use `.stamp`.
- Daily counters reset themselves when the day is part of the key: `AWButton(.increment, key: "sessions@\(AWState.dayKey(entry.date))")`.
- Decks: `entry.state.deckIndex(count: cards.count, slot: slot)` gives the card to show; with a shuffle seed it walks a scrambled order that still visits every card once per cycle. `entry.state.isShuffled` tells the button which icon to show.
- Buttons do not spend the reload budget.

## Finding what overflows

`OVERFLOW` names the tallest (or widest) kit components in the cell, for example `Tallest parts: AWSparkline 96 pt · AWList, 5 rows 140 pt`. Your own stacks and shapes show up there too once you name them: `.awBlock("Clock face")`.

## Tokens

- `AWSpace`: `xxs` 2, `xs` 4, `s` 8, `m` 12, `l` 16, `xl` 24.
- `AWMetrics.spacing(for: family)` (6 in small, 8 otherwise), `AWMetrics.padding(for:)`.
- `AWStatus`: `.ok`, `.warning`, `.critical`, `.info`, `.neutral` with `.symbol`, `.color` and `.tint(context)` (monochrome when idle).
- `context.isMonochrome` is true on the idle desktop (and in accented mode) — color is gone, so switch to weight, symbols or position; `context.isVibrant` is the same check for the idle desktop only.
- `AWFormat.compact(_ value: Double) -> String` — `1234` → `"1.2K"`, `2_000_000` → `"2M"`; pass `Double(intValue)` for integers.
- `AWFormat.freshness(_ date: Date, now: Date = Date(), language:) -> String` → “5m ago” / “5 мин назад”; `AWFormat.updated(_:)` → “updated 5m ago”.
- `AWTick`: `.none`, `.everyMinute(count:)`, `.every(seconds:count:)` — extra timeline entries so time-based views update without reloads.
