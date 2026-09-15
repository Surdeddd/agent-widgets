---
name: agent-widgets
description: Build, preview, install and screenshot native macOS desktop widgets (WidgetKit + SwiftUI) with the aw CLI or the agent-widgets MCP tools. Use whenever someone wants a macOS widget, desktop widget, WidgetKit widget or Notification Center widget — including «сделай виджет», «виджет на рабочий стол», «виджет для мака», «виджет macOS».
---

# agent-widgets

You write only the unique part of a widget: a Codable model, a SwiftUI view and, when it needs live data, a feed script. `aw` does everything else — WidgetKit plumbing, previews with layout checks, signing, installing, pointing a dev slot on the desktop at your widget and capturing the real window.

Use the MCP tools (`aw_new`, `aw_preview`, `aw_ship`, …) when they are connected; otherwise run the same commands in a shell with `--json`. A long MCP call (`aw_ship`, `aw_dev`, `aw_slot`, `aw_feed_run`) may answer with a job id before it finishes: call `aw_wait` with that id until the final result arrives.

## Done means

- `aw preview <id>` reports no errors **and** you opened the sheet image and it looks right in every family, light and dark, desktop-idle (monochrome) and Tahoe clear (glass, no color).
- `aw ship <id>` ends with a desktop screenshot and `.aw/shots/<id>-<family>-compare.png` (preview · desktop · outlines), and you looked at both. A ship without a desktop screenshot is not done: `aw ship` exits 5 with stage `unverified`. Ask the person to put the dev slot (“<App> · Dev”: right-click the desktop → Edit Widgets) on the desktop and run `aw slot` — it waits for the slot and captures it. On `WIDGET_HIDDEN` the slot is not visible (covered by windows, on another Space or removed) and macOS does not draw it: ask the person to show the desktop and re-add the slot if it is gone, then run `aw slot`. Never report a widget as done from `sheet.png` alone.
- If the widget has live data, `aw feed run <id>` is green.

## The loop

1. `aw doctor` — toolchain, signing and workspace. No `aw.json` around → `aw init <folder>`.
2. `aw templates`, then `aw new <id> --template <metric|list|ring|chart|card|image|timer|blank> [--families small,medium,large]`.
3. Edit `widgets/<id>/<Type>View.swift` (model + view) and `widgets/<id>/samples/*.json`: `default.json` is required, add `long.json` with the longest real strings and `empty.json` containing `null`.
4. `aw preview <id> --json` → fix every error in `issues`, then open `sheet.png` and fix what looks wrong. Repeat until clean. Unknown code → `aw explain <CODE>`.
5. Live data: write `feed.py` that prints one JSON object shaped like the model, add `"feed"` to `widget.json`, run `aw feed run <id>`. Quick test data without a feed: `aw data set <id> '{…}'`.
6. `aw ship <id>` — build, install, dev slot, real screenshot. On `WIDGET_NOT_PLACED`, ask the person once to add “<App name> · Dev” to the desktop in the sizes your widget supports; you cannot place widgets yourself. Run `aw slot` right after asking — it waits until the slot is on the desktop, measures the desktop sizes and captures the slot. Never script the desktop to get around this — no `osascript` or System Events, no `killall NotificationCenter` or `chronod`, no Mission Control: the desktop and its widgets belong to the person. Ask, and let `aw slot` wait.
7. `aw daemon install` keeps feeds running every minute (each feed still runs only at its own `every`).

## The code you write

```swift
import AWKit
import SwiftUI

struct WeatherData: Codable, Sendable {
    let city: String
    let temp: Double
    let condition: String
    let symbol: String
    let hourly: [Double]
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
                    AWMetric(String(format: "%.0f", data.temp), unit: "°C", label: data.condition)
                case .medium:
                    HStack(alignment: .bottom, spacing: AWSpace.m) {
                        AWMetric(String(format: "%.0f", data.temp), unit: "°C", label: data.condition)
                        AWSparkline(data.hourly, tint: .orange)
                            .frame(height: 56)
                    }
                default:
                    AWMetric(String(format: "%.0f", data.temp), unit: "°C", label: data.condition)
                    Spacer(minLength: 0)
                    AWSparkline(data.hourly, tint: .orange)
                        .frame(height: 96)
                }
            }
        }
    }
}
```

- The view is a struct conforming to `AWView` with `let entry: AWEntry<Model>` and `init(entry:)`. `"view"` in `widget.json` names it exactly.
- `AWPhaseView(entry) { data in … }` draws waiting, error and stale states for you.
- `@Environment(\.aw)` gives `family`, `isSmall`, `isWide`, `isVibrant`, `language` and `pick(en:ru:)`. Branch the layout on `context.family`.
- Import only `AWKit` and `SwiftUI` (`Charts` also works). No networking, timers or `onAppear` in views — widgets are snapshots; the feed fetches.

## widget.json

```json
{
  "id": "weather",
  "name": {"en": "Weather", "ru": "Погода"},
  "families": ["small", "medium", "large"],
  "view": "WeatherView",
  "feed": {"command": "python3 feed.py", "every": "30m"},
  "settings": {"latitude": 13.75, "longitude": 100.5}
}
```

Content sizes depend on the display. `aw geometry` prints this Mac's (run `aw geometry --measure` once any widget is on the desktop) and previews render at exactly those sizes — on a MacBook desktop small 164×164, medium 344×164, large 344×344, extraLarge 704×344 points. Unmeasured previews fall back to 155×155, 329×155, 345×345, 715×345. The frame already adds 14–18 pt of padding, so do not pad the root view.

## Design rules

- Readable at a glance: one hero value, everything else smaller and secondary.
- Each family gets its own layout; show less in small, never shrink everything.
- Nothing hides behind a tap and nothing ends in an ellipsis — shorten, drop, or add a line.
- Color never carries meaning alone: the idle desktop turns widgets monochrome and Tahoe clear glass drops color entirely. Pair color with a symbol, a word or position.
- Freshness is visible: pass `entry:` to `AWHeader`; stale data gets a badge automatically.
- Use kit components; native `Gauge`, `ProgressView` and `Toggle` do not render in previews.

## References

- [components](references/components.md) — every kit component with its signature
- [design rules](references/design-rules.md) — layouts per family, hierarchy, color, type
- [cookbook](references/cookbook.md) — weather, list, progress, countdown, bar chart, buttons, images
- [contracts](references/contracts.md) — `widget.json`, samples, feeds, state and actions, JSON output, exit codes, MCP tools
- [gotchas](references/gotchas.md) — what breaks in WidgetKit and how to avoid it
