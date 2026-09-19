# Changelog

## Unreleased

- A gallery of ready-made widgets ships with the engine. `aw gallery` lists them, `aw gallery add <id>` copies one into the workspace with its feed and samples; the MCP server has `aw_gallery` and `aw_gallery_add`. An unknown id is `GALLERY_UNKNOWN` with the list of what exists.
- `aw_init` creates the workspace from an MCP client, so Claude Desktop and other clients without a shell can start from nothing; `WORKSPACE_NOT_FOUND` points at it.
- Seven gallery widgets on live data replace the old examples: **AI limits** (what is left of the Claude and Codex windows, the pace against an even spend, a forecast and a week of history), **Agents** (coding sessions that wait for you, went silent or are working, with live timers and sessions by hour), **GitHub** (contribution calendar, streaks, the review queue, the last 14 days), **AI spend** (tokens of the day at API prices, by model), **2048** (played with widget buttons), and redrawn **System pulse** and **Focus**.
- The preview checks how a widget uses its space. It measures the largest empty rectangle of the `default` sample in every family and warns with `UNDERFILLED` once it takes 40 % of a small, 30 % of a medium, 25 % of a large or extra large widget; the sheet outlines the hole, every cell shows `empty N%`, and `report.json` carries `emptyShare` and `emptyArea`. Gaps between a label and its value do not count; empty states and side samples are not judged.
- Templates fill the sizes they declare: the list has two columns in medium and eight default targets, metric and chart put derived facts next to the hero and let the chart take the rest, the timer has its ring in medium. `card` is drawn for small and medium, `list` for small to large; `aw templates` shows the sizes. A test renders every template and fails on `UNDERFILLED`.
- The skill is rewritten around what agents get wrong: a family ladder (each size answers a bigger question), where the extra information comes from, feeds that print the same bytes while nothing changed, red flags with the right move. Its example is compiled and rendered by the tests.
- `context.locale` is the current locale speaking the language of the widget: dates and numbers formatted with it match the text around them, where a Russian Mac used to print “16 сент.” inside an English widget.
- Sample dates can be offsets from now — `"+90m"`, `"-4m"`, `"+2h30m"` — so countdowns and “waiting for” labels stay alive in every preview instead of expiring with the day the sample was written.
- Feed scripts of the gallery are covered by `Tests/Feeds` (python unittest) and run in CI; the 2048 logic and the limits pace by a Swift test target.

## 0.3.1 — 2026-09-19

- `aw new` works when the engine sits behind a symlink — a Homebrew install always does. It used to fail with `UNEXPECTED … couldn’t be copied`: the created paths were cut at the wrong place once the symlink was resolved.
- A widget with a running timer settles on the desktop. `aw ship` and `aw dev` compared captured frames byte by byte, so a `Text(date, style: .timer)` or an `AWCountdown`, which changes every second, never looked still: every window waited its full 30 s and the run ended `unverified` with `SHOT_UNCHANGED`. Frames are now compared as pictures: a ticking clock is neither a redraw nor a widget that keeps redrawing, and the same ticking widget is still reported as unchanged.

## 0.3.0 — 2026-09-15

- Long MCP calls fit every client. `aw_ship`, `aw_dev`, `aw_slot` and `aw_feed_run` run as jobs: a call answers within its budget (none for Claude Code, 45 s for other clients, `aw mcp --call-budget`) with a job id and stage, and the new `aw_wait` returns the final result. Codex and Claude Desktop, which stop a tool call after 60 s, now get through a ship.
- Progress notifications for every stage of a long call, and a pulse every 10 s.
- Cancelling an MCP call stops its work and sends no reply: a build is interrupted, waits end, an install swap already under way still finishes.
- Claude Code plugin: `/plugin marketplace add Surdeddd/agent-widgets`, then `/plugin install agent-widgets@agent-widgets` installs the skill and the MCP server and asks for the widgets folder. A SessionStart hook explains how to install `aw` when it is missing.
- Every MCP tool has a title, read-only, destructive, idempotent and open-world hints, and an output schema. The structured content carries the reply text under `summary`, because Claude Code shows the model that JSON instead of the text block.
- MCP arguments are checked against the input schema: unknown names, wrong types and missing values are `INVALID_ARGUMENT`. Invalid widget ids are `WIDGET_ID_INVALID` everywhere, unknown jobs `JOB_UNKNOWN`.
- Hints in MCP replies name the tool to call (`aw_explain {"code": "…"}`) and mark commands that only exist in a shell.
- A dev slot covered by windows is `WIDGET_HIDDEN` instead of a misleading `SHOT_MISMATCH`: macOS does not draw desktop widgets that are not on screen, so their capture is an empty frame. `aw dev` no longer waits 30 s for a redraw that cannot happen, `aw slot` waits until the slot is visible, `aw ship` without a visible slot ends `unverified`, and `aw doctor` tells a placed but invisible slot from a missing one.
- `aw ship` and `aw dev` capture and compare only the dev slot sizes the widget supports.
- `aw_preview` takes `lang` (`en` / `ru`), like `aw preview --lang`.
- Long issue labels under a preview cell wrap inside the tile instead of pushing the next cell out of the grid.
- `SAMPLE_NOT_LOCALIZED` fires only when the default sample holds text; a feed of numbers has nothing to translate.
- The contracts say how `Date` fields of a model decode: ISO 8601 or epoch seconds, as in the timeline envelope. The skill asks for the dev slot in the sizes the widget supports.

## 0.2.0 — 2026-09-14

- `aw slot` waits until the person puts the dev slot on the desktop, then measures sizes and captures it (`SLOT_TIMEOUT`).
- A free Apple ID is enough for signing: docs and `SIGNING_MISSING` now say so; `aw preview` needs no certificate. Verified: this repository is built, signed and installed with a free Personal Team.
- `aw ship` without a desktop screenshot no longer reports success: exit 5, stage `unverified` (`SHIP_UNVERIFIED`).
- `aw geometry [--measure]` reads the real desktop widget sizes of this Mac from the system log; previews, the sheet and window matching use them, and `aw doctor` warns while they are unknown (`GEOMETRY_UNKNOWN`).
- The dev slot shot is compared with the preview cell of the sample it shows: `aw shot` and `aw ship` write `<id>-<family>-compare.png` (preview, desktop, outlines) and warns with `SHOT_MISMATCH` when the size or the outlines differ.
- Feeds are never silent: exit 127 / 126 become `FEED_COMMAND_NOT_FOUND` with the missing program and the feed PATH, the status keeps the exit code and the last stderr lines, and `aw doctor` reports every feed — ok N min ago, the last failure, or `STALE_DATA` after three missed runs.
- Feed secrets live in `aw.local.json`: a feed gets only the names it lists in `feed.secrets`, a missing value stops it with `FEED_SECRET_MISSING`, and `aw doctor` warns when `secrets` are in the shared `aw.json` (`SECRETS_IN_CONFIG`).
- A feed widget previewed with `--lang ru` and no `samples/default.ru.json` warns with `SAMPLE_NOT_LOCALIZED`, with the command that writes that sample.
- `aw dev` and `aw_dev` wait until the desktop has redrawn the dev slot, then capture it and compare it with the preview; before, a shot right after `aw dev` could still show the previous widget.
- The app window edits widget settings: every widget whose feed takes `settings` gets a form (text, numbers, toggles, JSON for the rest); edits are saved in the App Group, win over widget.json in `AW_SETTINGS` and make the feed run at the next tick. The kit is unchanged.
- Templates lay out extraLarge: metric, chart, list, ring, card, image and timer get two-column dashboards (the timer also a large layout with an elapsed ring), and new widgets from them include the family. The template test renders all of them.
- The preview matrix gets a Tahoe clear row: `default` is also rendered as dark clear glass in the accented rendering mode, where color disappears.

## 0.1.0 — 2026-09-14

First public version.

- `aw` CLI: `init`, `new` (8 templates), `preview`, `build`, `install`, `rollback`, `dev`, `shot`, `ship`, `feed run`, `data set/get`, `tick`, `daemon`, `logs`, `list`, `templates`, `doctor`, `explain`, `mcp`, `skill install`. Every command speaks English and Russian and prints JSON with `--json`.
- Preview harness: renders every family × light/dark × desktop-idle × sample into a sheet and reports `OVERFLOW`, `TRUNCATION`, `DECODE`, `TINY_TEXT` and friends, with a hint for each.
- Ship loop: generated WidgetKit app, signed build, atomic install with backups, a dev slot on the desktop that shows whichever widget an agent is working on, and screenshots of the real window. Install keeps the installed app the only registered copy of the widget extension and retries the launch while the previous copy is still closing.
- Live data: feeds with timeouts and model checks, canonical JSON published only on change, a LaunchAgent that runs due feeds every minute.
- AWKit: header, metric, trend, badge, ring, gauge, bar, sparkline, bar chart, list, countdown, clock, image, empty and stale states, a type scale with a `display` role for big words, buttons with state (next, prev, toggle, increment, set, shuffle, reset, stamp) and a full-cycle deck.
- Eight example widgets, each written by a fresh agent from a one-paragraph brief and the skill, then given one design review pass.
- For agents: MCP server with 11 tools (preview returns the sheet image), the `agent-widgets` skill with components, cookbook, contracts and gotchas, an issue catalog behind `aw explain`.
