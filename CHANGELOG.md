# Changelog

## Unreleased

- `aw geometry [--measure]` reads the real desktop widget sizes of this Mac from the system log; previews, the sheet and window matching use them, and `aw doctor` warns while they are unknown (`GEOMETRY_UNKNOWN`).

## 0.1.0 — 2026-09-14

First public version.

- `aw` CLI: `init`, `new` (8 templates), `preview`, `build`, `install`, `rollback`, `dev`, `shot`, `ship`, `feed run`, `data set/get`, `tick`, `daemon`, `logs`, `list`, `templates`, `doctor`, `explain`, `mcp`, `skill install`. Every command speaks English and Russian and prints JSON with `--json`.
- Preview harness: renders every family × light/dark × desktop-idle × sample into a sheet and reports `OVERFLOW`, `TRUNCATION`, `DECODE`, `TINY_TEXT` and friends, with a hint for each.
- Ship loop: generated WidgetKit app, signed build, atomic install with backups, a dev slot on the desktop that shows whichever widget an agent is working on, and screenshots of the real window. Install keeps the installed app the only registered copy of the widget extension and retries the launch while the previous copy is still closing.
- Live data: feeds with timeouts and model checks, canonical JSON published only on change, a LaunchAgent that runs due feeds every minute.
- AWKit: header, metric, trend, badge, ring, gauge, bar, sparkline, bar chart, list, countdown, clock, image, empty and stale states, a type scale with a `display` role for big words, buttons with state (next, prev, toggle, increment, set, shuffle, reset, stamp) and a full-cycle deck.
- Eight example widgets, each written by a fresh agent from a one-paragraph brief and the skill, then given one design review pass.
- For agents: MCP server with 11 tools (preview returns the sheet image), the `agent-widgets` skill with components, cookbook, contracts and gotchas, an issue catalog behind `aw explain`.
