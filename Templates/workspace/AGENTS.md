# Widgets workspace

This folder is an **agent-widgets** workspace: native macOS widgets (WidgetKit + SwiftUI) built with the `aw` CLI. You write the unique part — a Codable model, a SwiftUI view and an optional feed script. `aw` generates the WidgetKit plumbing, renders previews with layout checks, builds, installs and captures the real widget.

The full guide is the `agent-widgets` skill (`aw skill install` links it for Claude Code, Codex and other agents); `aw mcp` serves the same loop as MCP tools.

## Done means

- `aw preview <id>` reports no errors, no warning on the `default` sample, and you looked at the sheet image: every family, light, dark, desktop idle and Tahoe clear.
- `aw ship <id>` ends with a desktop screenshot and `.aw/shots/<id>-<family>-compare.png` (preview · desktop · outlines), and you looked at both. A ship without a desktop screenshot is not done: `aw ship` exits 5 with stage `unverified`. Ask the person to put the dev slot (“<App> · Dev”: right-click the desktop → Edit Widgets) on the desktop and run `aw slot` — it waits for the slot and captures it. Never report a widget as done from `sheet.png` alone.
- If the widget has live data, `aw feed run <id>` is green twice in a row and the second run says `unchanged` while nothing changed.

## The loop

0. `aw gallery` — AI limits, agent sessions, GitHub, AI spend, 2048, system monitor and focus timer ship ready-made: `aw gallery add <id>`, then `aw feed run <id>` and `aw ship <id>`. Write a new widget only when none fits.
1. `aw new <id> --template <metric|list|ring|chart|card|image|timer|blank> [--families small,medium]` — scaffold `widgets/<id>/`. `aw templates` shows the sizes each template is drawn for.
2. Edit `widgets/<id>/*.swift` (model + `AWView`) and `widgets/<id>/samples/*.json` — `default.json` is the typical day and is required; add `long.json` with the longest real strings and `empty.json` containing `null`. Dates in samples are offsets from now: `"+90m"`, `"-4m"`.
3. `aw preview <id> --json` — fix every error and every warning on `default` in `issues`, open `sheet.png`, fix what looks wrong, repeat. `aw explain <CODE>` explains any code.
4. `aw ship <id>` — builds, installs, points the dev slot at the widget and captures the real window. On `WIDGET_NOT_PLACED` ask the person once to add “<App name> · Dev” to the desktop. Run `aw slot` right after asking — it waits until the slot is on the desktop, measures the desktop sizes and captures the slot.
5. Live data: add `"feed": {"command": "python3 feed.py", "every": "30m"}` to `widget.json`; the feed prints one JSON object shaped like the model and logs to stderr. Check it with `aw feed run <id>`, keep it fresh with `aw daemon install`.

## The view

```swift
import AWKit
import SwiftUI

struct StepsData: Codable, Sendable {
    let steps: Int
    let goal: Int
}

struct StepsView: AWView {
    let entry: AWEntry<StepsData>
    @Environment(\.aw) private var context

    init(entry: AWEntry<StepsData>) {
        self.entry = entry
    }

    var body: some View {
        AWPhaseView(entry) { data in
            VStack(alignment: .leading, spacing: AWMetrics.spacing(for: context.family)) {
                AWHeader(context.pick(en: "Steps", ru: "Шаги"), symbol: "figure.walk", entry: entry)
                AWMetric("\(data.steps)", unit: "/ \(data.goal)")
                Spacer(minLength: 0)
                AWBar(progress: Double(data.steps) / Double(max(data.goal, 1)), tint: .green)
            }
        }
    }
}
```

`"view"` in `widget.json` must name the struct. Branch layouts on `context.family`. Sizes depend on the display: `aw geometry` prints this Mac's (on a MacBook desktop small 164×164, medium 344×164, large 344×344, extraLarge 704×344 points) and previews render at them; run `aw geometry --measure` once any widget is on the desktop.

## Rules for good widgets

- Glanceable: one hero value, readable with peripheral vision.
- Every size says more: small answers the one question, medium adds what it compares to or what is next, large adds the breakdown, extraLarge is a small dashboard of 2–3 columns. No extra information for a size → remove it from `families`. The preview warns with `UNDERFILLED` when a size is mostly empty; a `Spacer` that pushes a detail to the bottom fills nothing.
- Nothing hidden behind a tap and no ellipsis — shorten or drop text per family.
- Color is not meaning: desktop widgets turn monochrome when the desktop is idle.
- A feed prints the same output while nothing changed — no “fetched at”, nothing computed from the clock — because only a changed publish spends one of the 40–70 reloads a day. Time-dependent values are computed in the view from `entry.date`; clocks and timers use `Text(date, style:)`, `AWCountdown` or `AWClock`.
- Use AW components (`AWMetric`, `AWRing`, `AWSparkline`, `AWList`, `AWButton`, …) — native `Gauge` does not render in previews.
- No networking or timers in views; the feed fetches.

## Help

- `aw explain <CODE>` — what an issue code means and how to fix it.
- `aw doctor` — Xcode, XcodeGen, signing, Screen Recording, installed app, dev slot, feed daemon.
- `--json` on any command gives `{ok, issues, artifacts, data}`.
- No certificate yet: `aw preview` still works; for `aw ship` add a free Apple ID in Xcode → Settings → Accounts and create an Apple Development certificate — no payment needed.
