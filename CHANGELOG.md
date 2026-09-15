# Changelog

## Unreleased

- Long MCP calls fit every client. `aw_ship`, `aw_dev`, `aw_slot` and `aw_feed_run` run as jobs: a call answers within its budget (none for Claude Code, 45 s for other clients, `aw mcp --call-budget`) with a job id and stage, and the new `aw_wait` returns the final result. Codex and Claude Desktop, which stop a tool call after 60 s, now get through a ship.
- Progress notifications for every stage of a long call, and a pulse every 10 s.
- Cancelling an MCP call stops its work and sends no reply: a build is interrupted, waits end, an install swap already under way still finishes.
- Claude Code plugin: `/plugin marketplace add Surdeddd/agent-widgets`, then `/plugin install agent-widgets@agent-widgets` installs the skill and the MCP server and asks for the widgets folder. A SessionStart hook explains how to install `aw` when it is missing.
- Every MCP tool has a title, read-only, destructive, idempotent and open-world hints, and an output schema. The structured content carries the reply text under `summary`, because Claude Code shows the model that JSON instead of the text block.
- MCP arguments are checked against the input schema: unknown names, wrong types and missing values are `INVALID_ARGUMENT`. Invalid widget ids are `WIDGET_ID_INVALID` everywhere, unknown jobs `JOB_UNKNOWN`.
- Hints in MCP replies name the tool to call (`aw_explain {"code": "…"}`) and mark commands that only exist in a shell.

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
