# Gotchas

Things that look fine in code and break on the desktop. The preview catches many of them; the rest you have to know.

## Rendering

- **Native controls do not render in previews.** `Gauge`, `ProgressView` styles, `Toggle` and `Picker` are AppKit-backed and draw as placeholders outside a real widget. Use `AWGauge`, `AWRing`, `AWBar`, `AWButton`.
- **`@Environment(\.widgetFamily)` is empty in previews.** Read `@Environment(\.aw).family` instead; it is correct in both.
- **Widgets are snapshots.** No `URLSession`, timers, `onAppear`, tasks or animations in views. Fetch in the feed; animate only through changes between timeline entries (the system cross-fades, ≤ 2 s).
- **Time that ticks** must use `Text(date, style: .timer / .relative / .time)`, `AWCountdown` or `AWClock` with `AWTick` entries — reloading every second is impossible.
- **Crashes are blank widgets.** A force unwrap or an out-of-range index kills the preview (`PREVIEW_CRASHED`) and shows nothing on the desktop. Guard arrays and optionals.
- **Spell colors out in ternaries.** `cond ? .primary : .orange` fails to compile (`.primary` is also a `HierarchicalShapeStyle`); write `Color.primary` and `Color.orange`.
- **SF Symbols must exist on macOS 14.** A misspelled name renders nothing; check the name in the SF Symbols app.

## Data

- **Reload budget:** roughly 40–70 reloads a day per widget. `every` under 15 minutes gets throttled. Buttons and the app in the foreground do not count.
- **Models change, stored data does not.** After changing the model, run `aw feed run <id>` or `aw data set` so old JSON in the App Group does not fail to decode.
- **The feed runs without your shell profile.** It gets a fixed PATH; call interpreters by name (`python3 feed.py`) or make scripts executable (`chmod +x feed.sh`). Prefer the Python standard library — no pip installs.
- **stdout is the data channel.** Any `print` besides the final JSON breaks the feed; log to stderr.
- **Disk numbers on APFS.** `df`'s Used and Capacity count one volume of the shared container; take free space from `shutil.disk_usage("/").free` (or `df`'s Avail) and never derive it from Used.
- **Send a User-Agent.** APIs behind Cloudflare (Frankfurter, many others) answer Python's default agent with HTTP 403; use `urllib.request.Request(url, headers={"User-Agent": "agent-widgets/0.1"})`.
- **Images** reach widgets only through the App Group: download into `$AW_IMAGES_DIR` and pass the file name in the model.
- **Per-day state needs date keys.** Store `"habit@\(AWState.dayKey(day))"`, not “column 3”: a relative key silently moves to another day at midnight and no preview can show it.
- **Timeline samples show their future.** When a sample is `{"timeline": [...]}`, `aw preview` also renders the next two entries as rows like `default+1h` — check them.

## Install and desktop

- **Signing is mandatory:** the App Group (`<TeamID>.<bundle>`) needs an Apple Development certificate — a free Apple ID with its Personal Team is enough. `aw doctor` checks it.
- **Placing widgets is a human action.** Ask once for the dev slot “<App> · Dev” in the sizes your widgets support; `aw dev` / `aw ship` switch it afterwards and capture only those sizes.
- **Changing `id` or `kind` is a new widget** to macOS; the old one disappears from the desktop.
- **Screenshots need Screen Recording** for the app that runs `aw`.
- **An invisible widget is not drawn.** macOS draws desktop widgets only while they are on screen; behind windows, on another Space, under a full-screen app or after the widget was removed (its window lingers for a while) the dev slot is an empty frame. `aw` then reports `WIDGET_HIDDEN` instead of comparing a blank shot, and `aw doctor` shows the slot as not visible: ask the person to show the desktop and re-add the slot if it is gone, then run `aw slot`.
- **A redraw can lag** — 1 to 20 s, WidgetKit decides. `aw ship` and `aw dev` wait until the dev slot changes before they capture it; on `SHOT_UNCHANGED` run `aw dev <id>` again or `aw install --hard`.
- **Stateful widgets show their live state in the dev slot** (a deck's card, toggles), while the preview uses the sample state. A `SHOT_MISMATCH` there is expected; the compare image shows the difference.
- **The desktop is the truth, not the sheet.** `aw shot` compares the dev slot with the preview cell of the same sample and writes `<id>-<family>-compare.png`; on `SHOT_MISMATCH` open it — a size gap needs `aw geometry --measure`, red outlines are things only the desktop shows.
