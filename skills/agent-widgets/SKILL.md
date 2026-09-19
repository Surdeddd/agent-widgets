---
name: agent-widgets
description: Use when someone wants something always visible on the Mac desktop — a macOS desktop widget, a WidgetKit or Notification Center widget for limits, statuses, metrics, timers, lists or a small game — or wants an existing agent-widgets widget fixed, restyled, resized or shipped. Also «сделай виджет», «виджет на рабочий стол», «виджет для мака», «виджет macOS».
---

# agent-widgets

You write only the unique part of a widget: a Codable model, a SwiftUI view and, when it needs live data, a feed script. `aw` does the rest — WidgetKit plumbing, previews with layout checks, signing, installing, pointing a dev slot on the desktop at your widget and capturing the real window.

The widget will sit on someone's desktop all day and be seen hundreds of times. A number in a corner with the rest empty, a line ending in “…”, or data that silently went stale reads as broken every single time. The preview measures all three; your job is to leave none of them.

Use the MCP tools (`aw_gallery`, `aw_new`, `aw_preview`, `aw_ship`, …) when they are connected; otherwise run the same commands in a shell with `--json`. A long MCP call (`aw_ship`, `aw_dev`, `aw_slot`, `aw_feed_run`) may answer with a job id before it finishes: call `aw_wait` with that id until the final result arrives.

## Done means

- `aw preview <id>` reports no errors, no warning on the `default` sample, **and** you opened the sheet image and it looks right in every family, light and dark, desktop-idle (monochrome) and Tahoe clear (glass, no color).
- `aw ship <id>` ends with a desktop screenshot and `.aw/shots/<id>-<family>-compare.png` (preview · desktop · outlines), and you looked at both. A ship without a desktop screenshot is not done: `aw ship` exits 5 with stage `unverified`.
- If the widget has live data, `aw feed run <id>` is green twice in a row and the second run says `unchanged` (`"changed": false`) while nothing changed.

## The loop

1. `aw doctor` — toolchain, signing and workspace. No `aw.json` around → `aw init <folder>`.
2. `aw gallery` — AI limits, agent sessions, GitHub, AI spend, 2048, system monitor, focus timer ship ready-made. One fits → `aw gallery add <id>`, `aw feed run <id>`, `aw ship <id>`, done. None fits → open the closest one anyway: it is the best example of a feed, a family ladder and tests.
3. `aw templates`, then `aw new <id> --template <metric|list|ring|chart|card|image|timer|blank> [--families small,medium]`. A template lists the sizes it is drawn for; ask for others only with a plan for them (next section).
4. Edit `widgets/<id>/<Type>View.swift` (model + view) and `widgets/<id>/samples/*.json`: `default.json` is the typical day, `long.json` the longest real strings, `empty.json` contains `null`. Dates in samples are offsets from now — `"+90m"`, `"-4m"` — so countdowns stay alive.
5. `aw preview <id> --json` → fix every error and every warning on `default`, then open `sheet.png` and fix what looks wrong. Repeat until clean. Unknown code → `aw explain <CODE>`.
6. Live data: write `feed.py` that prints one JSON object shaped like the model, add `"feed"` to `widget.json`, run `aw feed run <id>`. Quick test data without a feed: `aw data set <id> '{…}'`.
7. `aw ship <id>` — build, install, dev slot, real screenshot. On `WIDGET_NOT_PLACED` or `WIDGET_HIDDEN` ask the person once to put “<App name> · Dev” on the desktop (right-click the desktop → Edit Widgets) in the sizes your widget supports, then run `aw slot` — it waits for the slot, measures the desktop sizes and captures it.
8. `aw daemon install` keeps feeds running (each feed still runs only at its own `every`).

## Every size says more

A bigger family is a bigger question, not the same answer with more air. Before writing the view, write one line per family: what does this size tell that the smaller one does not? No answer → remove the family from `widget.json`.

| family | it answers | layout that fills it |
|---|---|---|
| small | the one question | header, hero number or ring, one line of context |
| medium | + compared to what, or what is next | hero column on the left; a chart, a ring or 3 short rows on the right |
| large | + the breakdown | hero row with one or two facts on its right, then a chart or 5–7 rows reaching the bottom |
| extraLarge | a small dashboard | 2–3 columns, each a widget of its own: summary · detail · trend |

Where the extra information comes from, cheapest first: facts derived from data you already have (min, max, average, pace, time left, forecast); a second view of the same data (rows **and** a chart); history the feed accumulates itself (read `AW_PREVIOUS_PATH`, append a point when the value changed); more rows in two columns. One piece per layout is flexible — `.frame(maxHeight: .infinity)` on the chart or list — and absorbs what is left; everything else keeps its natural size.

`aw preview` measures the largest empty rectangle of the `default` sample and warns with `UNDERFILLED` (40 % of a small, 30 % of a medium, 25 % of a large or extraLarge); the sheet outlines the hole and `report.json` carries `emptyShare` for every cell. There are three ways out and no fourth: give this size information it lacks, let the hero or the chart take the space, or drop the family. A `Spacer` pushing a detail to the bottom edge does not fill anything — the hole just moves to the middle.

## The code you write

```swift
import AWKit
import SwiftUI

struct WeatherDay: Codable, Sendable, Identifiable {
    let name: String
    let symbol: String
    let high: Double
    let low: Double

    var id: String { name }
}

struct WeatherData: Codable, Sendable {
    let city: String
    let temp: Double
    let condition: String
    let symbol: String
    let hourly: [Double]
    let days: [WeatherDay]
}

struct WeatherView: AWView {
    let entry: AWEntry<WeatherData>
    @Environment(\.aw) private var context

    init(entry: AWEntry<WeatherData>) {
        self.entry = entry
    }

    var body: some View {
        AWPhaseView(entry) { data in
            VStack(alignment: .leading, spacing: AWMetrics.spacing(for: context.family)) {
                AWHeader(data.city, symbol: data.symbol, entry: entry)
                switch context.family {
                case .small:
                    now(data)
                    Spacer(minLength: 0)
                    hours(data).frame(height: 30)
                case .medium:
                    HStack(alignment: .top, spacing: AWSpace.l) {
                        now(data).frame(width: 110, alignment: .leading)
                        hours(data).frame(maxHeight: .infinity)
                    }
                case .large:
                    now(data)
                    hours(data).frame(maxHeight: .infinity)
                    week(data.days.prefix(6))
                case .extraLarge:
                    HStack(alignment: .top, spacing: AWSpace.xl) {
                        VStack(alignment: .leading, spacing: AWSpace.m) {
                            now(data)
                            hours(data).frame(maxHeight: .infinity)
                        }
                        week(data.days.prefix(7))
                    }
                }
            }
        }
    }

    private func now(_ data: WeatherData) -> some View {
        AWMetric(String(format: "%.0f", data.temp), unit: "°C", label: data.condition)
    }

    private func hours(_ data: WeatherData) -> some View {
        AWSparkline(data.hourly, tint: .orange)
    }

    private func week(_ days: ArraySlice<WeatherDay>) -> some View {
        AWList(Array(days), maxRows: days.count) { day in
            AWRow(day.name, value: String(format: "%.0f° / %.0f°", day.high, day.low), symbol: day.symbol)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

- The view is a struct conforming to `AWView` with `let entry: AWEntry<Model>` and `init(entry:)`. `"view"` in `widget.json` names it exactly.
- `AWPhaseView(entry) { data in … }` draws waiting, error and stale states for you.
- `@Environment(\.aw)` gives `family`, `isSmall`, `isWide`, `isVibrant`, `language`, `locale` and `pick(en:ru:)`. “Now” inside a view is `entry.date`, never `Date()`. Dates and numbers take `.locale(context.locale)`: the system locale may speak another language than the widget.
- Import only `AWKit` and `SwiftUI` (`Charts` also works). No networking, timers or `onAppear` in views — widgets are snapshots; the feed fetches.

## widget.json

```json
{
  "id": "weather",
  "name": {"en": "Weather", "ru": "Погода"},
  "families": ["small", "medium", "large", "extraLarge"],
  "view": "WeatherView",
  "feed": {"command": "python3 feed.py", "every": "30m"},
  "settings": {"latitude": 13.75, "longitude": 100.5}
}
```

Content sizes depend on the display. `aw geometry` prints this Mac's (run `aw geometry --measure` once any widget is on the desktop) and previews render at exactly those sizes — on a MacBook desktop small 164×164, medium 344×164, large 344×344, extraLarge 704×344 points. The frame already adds 14–18 pt of padding, so do not pad the root view.

## Rules that the preview cannot check for you

- One hero per size, readable from the corner of the eye; everything else smaller and secondary.
- Color never carries meaning alone: the idle desktop turns widgets monochrome and Tahoe clear glass drops color. Pair it with a symbol, a word or position.
- The feed prints the same bytes while nothing changed — no “fetched at”, no value computed from the clock. Output is published only when it differs, and every publish spends one of the 40–70 reloads a day. Anything that depends on the time is computed in the view from `entry.date`; anything that ticks is `Text(date, style: .timer)`, `AWCountdown` or `AWClock`.
- Use kit components; native `Gauge`, `ProgressView` and `Toggle` do not render in previews.

## Red flags

If you catch yourself thinking any of these, stop and do the right column.

| thought | what to do |
|---|---|
| “The report has zero errors, so it is clean” | Warnings on `default` are work items. `UNDERFILLED`, `TRUNCATION` and `BUDGET_RISK` each name their fix. |
| “I anchored the detail to the bottom, the space is used” | The hole moved to the middle. Take one of the three ways out of `UNDERFILLED`. |
| “The template came with four families, so I ship four” | Families are a decision. Keep the ones you wrote a line for. |
| “The sheet looks right, I will report it done” | Done is a desktop screenshot you looked at. `aw ship`, then `aw slot` if it asks. |
| “I will place or reload the widget myself to save the person a step” | Never: no `osascript`, System Events, `killall NotificationCenter` or `chronod`, no Mission Control. The desktop belongs to the person. Ask once, let `aw slot` wait. |
| “I reviewed every cell myself” without having opened `sheet.png` | Open the image. The report cannot see overlap, crowding or a chart that says nothing. |

## References

- [design rules](references/design-rules.md) — the family ladder with worked examples, hierarchy, color, type
- [components](references/components.md) — every kit component with its signature
- [cookbook](references/cookbook.md) — weather, list, progress, countdown, bar chart, buttons, images
- [contracts](references/contracts.md) — `widget.json`, samples, feeds, state and actions, JSON output, exit codes, commands, MCP tools
- [gotchas](references/gotchas.md) — what breaks in WidgetKit and how to avoid it
