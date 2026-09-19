# Design rules

A desktop widget is read from the corner of the eye in under a second. Everything below serves that.

## Hierarchy

- One hero: the single value the person installed the widget for, in `AWMetric` or `.hero` text.
- Then one line of context (`label`, trend, caption), then optional detail (chart, list).
- Build hierarchy with size and weight, not with color. Secondary text uses `.foregroundStyle(.secondary)`.
- Numbers use `AWMetric` (monospaced digits); units stay small next to the value.

## Every size says more

A bigger family answers a bigger question. It is never the small layout with more air around it.

| family | content on a MacBook desktop (pt) | it answers | layout that fills it |
|---|---|---|---|
| small | 164 × 164 | the one question | header, hero value or ring, one line or a tiny sparkline |
| medium | 344 × 164 | + compared to what, or what is next | hero column on the left; chart, ring or 3 short rows on the right |
| large | 344 × 344 | + the breakdown | hero row with one or two facts on its right, then a chart or 5–7 rows reaching the bottom |
| extraLarge | 704 × 344 | a small dashboard | 2–3 columns, each a widget of its own: summary · detail · trend |

Write the ladder down before the view — one line per family — and drop every family you have no line for. The gallery widgets show it (`aw gallery add <id>` to read the code):

| widget | small | medium | large | extraLarge |
|---|---|---|---|---|
| `ai-limits` | ring of the tightest limit | + both services, 5-hour and week | + per-window bars with reset times | + even-pace marks, forecast, a week of history per service |
| `agents` | how many sessions wait for you, the first one | + three sessions with timers | + five sessions with what they do | + sessions by hour for the last 12 hours |
| `github` | streak and 13 weeks of the calendar | + 20 weeks and the year total | + a year in two blocks, the review queue | + 53 weeks, reviews, the last 14 days as bars |

Where the extra information comes from, cheapest first:

1. **Derived facts** from data already in the model: min, max, average, pace against an even spend, time left, a forecast.
2. **A second view of the same data**: rows and a chart, a ring and its history.
3. **History the feed keeps itself**: read `AW_PREVIOUS_PATH`, append a point when the value changed, cap the list. The view resamples by time, so sleep gaps do not bend the line.
4. **More rows in two columns** instead of one long column with a tail of “+5 more”.

One piece per layout is flexible — `.frame(maxHeight: .infinity)` on the chart or the list — and absorbs the leftover; everything else keeps its natural size. A `Spacer` that pushes a detail to the bottom edge fills nothing: the hole moves to the middle.

`aw preview` measures this. It renders the `default` sample alone on a transparent background, finds the largest empty rectangle (a gap between a label and its value does not count) and warns with `UNDERFILLED` once it takes 40 % of a small, 30 % of a medium, 25 % of a large or extraLarge widget. The sheet outlines the hole with a dashed line, every cell label shows `empty N%`, and `report.json` has `emptyShare` and `emptyArea` per cell. The ways out: add information this size lacks, let the hero or the chart take the space, or remove the family from `widget.json`. Empty states and side samples (`long`, `empty`, your own) are not judged — so `default.json` has to be the typical day, not the best one.

Sizes change with the display. `aw geometry --measure` reads them from this Mac once a widget is on the desktop, and every preview renders at the measured sizes; without a measurement previews use 155 × 155, 329 × 155, 345 × 345 and 715 × 345. The desktop window around a widget is 16 pt larger than its content — `aw shot` matches windows to families by the same table.

- Branch on `context.family`; do not scale one layout down.
- `ideal 109/155` under a cell on the sheet shows how much of the height the content asks for; `empty 31%` next to it is the largest hole.
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

- The preview report has no errors and no warnings on `default`; warnings in `long` are acceptable only if the default sample is clean.
- Look at the sheet: alignment, crowding, contrast in dark and idle, nothing touching the edges.
- One glance test: cover the sheet with your hand, uncover a cell for a second — can you say the hero value?
