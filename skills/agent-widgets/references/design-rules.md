# Design rules

A desktop widget is read from the corner of the eye in under a second. Everything below serves that.

## Hierarchy

- One hero: the single value the person installed the widget for, in `AWMetric` or `.hero` text.
- Then one line of context (`label`, trend, caption), then optional detail (chart, list).
- Build hierarchy with size and weight, not with color. Secondary text uses `.foregroundStyle(.secondary)`.
- Numbers use `AWMetric` (monospaced digits); units stay small next to the value.

## Layout per family

| family | content (pt) | what fits |
|---|---|---|
| small | 155 × 155 | header, hero value, one line or a tiny sparkline |
| medium | 329 × 155 | two columns: hero on the left, chart / ring / 2–3 rows on the right |
| large | 345 × 345 | header, hero, chart, a short list (4–6 rows) |
| extraLarge | 715 × 345 | a small dashboard: 2–3 columns |

- Branch on `context.family`; do not scale one layout down.
- Fill the family: header on top, the hero next, one detail pinned to the bottom (sparkline, bar, controls, the next hours) with `Spacer(minLength: 0)` in between. An empty bottom third reads as broken; `ideal 109/155` under a cell on the sheet shows how much of the height the content really uses. Charts get explicit heights per family.
- The frame already pads 14–18 pt; do not add outer padding or backgrounds.
- Use the `AWSpace` grid (4 / 8 / 12 / 16) for gaps.

## Color and modes

- Widgets appear light, dark and, when the desktop is idle, monochrome — `context.isMonochrome` is true then. Check all three rows of the sheet.
- Color never carries meaning alone: pair it with a symbol (`AWStatus.symbol`), a word or position.
- Use one accent color per widget; kit components already fade tints in idle mode.
- No solid backgrounds — the system draws the glass; painted fills look wrong in idle mode.

## Text

- No ellipses. Shorten text for smaller families, give it another line with `lines:`, or drop it.
- Keep labels to two or three words; move long explanations out of the widget.
- Localize view strings with `context.pick(en:ru:)`; the feed receives `AW_LANG` to localize data.

## State and freshness

- Always wrap in `AWPhaseView` so empty and error states look intentional.
- Pass `entry:` to `AWHeader` so people see how old the data is; stale data gets a badge by itself.
- Timers and clocks tick with `Text(date, style:)`, `AWCountdown` or `AWClock` — never by reloading.

## Before you call it done

- The preview report has no errors; warnings in `long` are acceptable only if the default sample is clean.
- Look at the sheet: alignment, crowding, contrast in dark and idle, nothing touching the edges.
- One glance test: cover the sheet with your hand, uncover a cell for a second — can you say the hero value?
