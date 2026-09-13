# Widgets workspace

This folder is an **agent-widgets** workspace: native macOS widgets (WidgetKit + SwiftUI) built with the `aw` CLI. You write the unique part — a data model, a SwiftUI view and an optional feed script. `aw` generates the WidgetKit plumbing, renders previews, builds, installs and captures the real widget.

## The loop

1. `aw new <id> --template <metric|list|ring|chart|card|image|timer|blank>` — scaffold `widgets/<id>/`.
2. Edit `widgets/<id>/*.swift` (model + `AWView`) and `widgets/<id>/samples/*.json`.
3. `aw preview <id> --json` — renders every family × light/dark × desktop-idle × sample into `.aw/previews/<id>/sheet.png` and reports issues. Open `sheet.png` and look at it. Repeat until the report has no errors and the sheet looks right.
4. `aw ship <id>` — builds, installs, shows the widget in the dev slot and captures the real widget window.
5. Live data: add `feed` to `widget.json`, check it with `aw feed run <id>`, keep it fresh with `aw daemon install`.

## Rules for good widgets

- Glanceable: one hero value, readable with peripheral vision.
- Nothing hidden behind a tap; no ellipsis — use `lineLimit` with `minimumScaleFactor`.
- Color is not meaning: desktop widgets turn monochrome when the desktop is idle.
- Refresh no faster than 15 minutes; clocks and timers use `Text(date, style:)` instead of reloads.
- Use AW components (`AWMetric`, `AWRing`, `AWSparkline`, …) — native `Gauge` does not render in previews.

## Help

- `aw explain <CODE>` explains any issue code from a report.
- `aw doctor` checks Xcode, XcodeGen, signing and the installed app.
- Add `--json` to any command for machine-readable output.
