# Gotchas

Things that look fine in code and break on the desktop. The preview catches many of them; the rest you have to know.

## Rendering

- **Native controls do not render in previews.** `Gauge`, `ProgressView` styles, `Toggle` and `Picker` are AppKit-backed and draw as placeholders outside a real widget. Use `AWGauge`, `AWRing`, `AWBar`, `AWButton`.
- **`@Environment(\.widgetFamily)` is empty in previews.** Read `@Environment(\.aw).family` instead; it is correct in both.
- **Widgets are snapshots.** No `URLSession`, timers, `onAppear`, tasks or animations in views. Fetch in the feed; animate only through changes between timeline entries (the system cross-fades, ≤ 2 s).
- **Time that ticks** must use `Text(date, style: .timer / .relative / .time)`, `AWCountdown` or `AWClock` with `AWTick` entries — reloading every second is impossible.
- **Crashes are blank widgets.** A force unwrap or an out-of-range index kills the preview (`PREVIEW_CRASHED`) and shows nothing on the desktop. Guard arrays and optionals.
- **SF Symbols must exist on macOS 14.** A misspelled name renders nothing; check the name in the SF Symbols app.

## Data

- **Reload budget:** roughly 40–70 reloads a day per widget. `every` under 15 minutes gets throttled. Buttons and the app in the foreground do not count.
- **Models change, stored data does not.** After changing the model, run `aw feed run <id>` or `aw data set` so old JSON in the App Group does not fail to decode.
- **The feed runs without your shell profile.** It gets a fixed PATH; call interpreters by name (`python3 feed.py`) or make scripts executable (`chmod +x feed.sh`). Prefer the Python standard library — no pip installs.
- **stdout is the data channel.** Any `print` besides the final JSON breaks the feed; log to stderr.
- **Images** reach widgets only through the App Group: download into `$AW_IMAGES_DIR` and pass the file name in the model.

## Install and desktop

- **Signing is mandatory:** the App Group (`<TeamID>.<bundle>`) needs an Apple Development certificate. `aw doctor` checks it.
- **Placing widgets is a human action.** Ask once for the dev slot “<App> · Dev” in medium and large; `aw dev` / `aw ship` switch it afterwards.
- **Changing `id` or `kind` is a new widget** to macOS; the old one disappears from the desktop.
- **Screenshots need Screen Recording** for the app that runs `aw`.
- **A redraw can lag.** If `aw ship` reports `SHOT_UNCHANGED`, wait and run `aw shot --dev`, or `aw install --hard`.
