# Contracts

## Workspace

```
<workspace>/
  aw.json            name, slug, bundlePrefix, locale?, overrides?
  aw.local.json      signingIdentity, teamID, secrets (machine-specific, git-ignored)
  widgets/<id>/
    widget.json
    *.swift          model + AWView
    feed.py | feed.sh (optional)
    samples/default.json, long.json, empty.json, <name>.state.json, images/
  .aw/               previews, build, logs, shots (git-ignored)
```

## widget.json

| field | type | meaning |
|---|---|---|
| `id` | string | `^[a-z][a-z0-9-]{0,39}$`, equals the folder name |
| `name` | string or `{"en","ru"}` | name in the widget gallery |
| `description` | string or `{"en","ru"}` | gallery subtitle (optional) |
| `families` | array | any of `small`, `medium`, `large`, `extraLarge` |
| `view` | string | the Swift struct conforming to `AWView` |
| `kind` | string | optional; default `aw.<id>`; changing it makes people re-add the widget |
| `refresh` | interval | how often WidgetKit asks for a new timeline (default `30m`) |
| `feed` | object | `command` (run in the widget folder with `/bin/zsh -c`), `every` (≥ `60s`; < `15m` warns), `timeout` (default `60s`), `secrets` (names from `secrets` in `aw.local.json` the feed gets as environment variables) |
| `settings` | JSON | handed to the feed as `AW_SETTINGS`; the person can change them in the app window (open the app), the edits live in the App Group, win over widget.json and make the feed run at the next tick |

Intervals: `"30s"`, `"15m"`, `"1h"`, `"1d"` or a number of seconds.

## Samples

- `default.json` — required; the preview, the gallery placeholder and the dev slot use it. A sample can be the model itself or the same `{"timeline": [...]}` envelope your feed prints; the preview renders the entry that is current now.
- `long.json` — longest realistic strings; truncation there is a warning, in default an error.
- `empty.json` — `null`, previews the waiting state.
- `<sample>.state.json` — button state for that sample, for example `{"cursor": 2, "cups": 3}`; a shuffled deck is `{"cursor": 5, "seed": 42}` (any non-zero seed), a running timer `{"endsAt": 1789400000}`.
- `<sample>.status.json` — feed status for that sample, for example `{"ok": false, "checkedAt": "2026-09-14T09:00:00Z", "fetchedAt": "2026-09-14T06:00:00Z"}` to preview staleness.
- `images/` — files `AWImage` finds in previews.
- `<sample>.ru.json` / `<sample>.en.json` — the same sample with feed text in that language; `aw preview <id> --lang ru` uses it instead of `<sample>.json`, so feed-localized strings can be checked too. A feed widget previewed with `--lang ru` and no `default.ru.json` gets `SAMPLE_NOT_LOCALIZED`.

## What `aw preview` renders

- By default: `default` in light, dark, desktop-idle and Tahoe clear (dark glass, no color) for every family, every other sample in dark, plus the next two entries of timeline samples.
- `--full`: every sample in light, dark, light-idle, dark-idle and clear.
- Each cell is a PNG next to `sheet.png` (`<family>-<appearance>-<mode>-<sample>.png`); `report.json` lists the issues per cell.
- Cells of the `default` sample also carry `emptyShare` (0…1, the largest empty rectangle as a share of the content area) and `emptyArea` (`[x, y, width, height]` as fractions of the widget). `UNDERFILLED` fires at 0.4 for small, 0.3 for medium, 0.25 for large and extraLarge; a cell without `emptyShare` was not judged (side sample, empty state or overflow).

## Feed

- Runs in the widget folder as `/bin/zsh -c "<command>"` with `PATH=/opt/homebrew/bin:/usr/local/bin:~/.local/bin:$PATH`.
- Environment: `AW_WIDGET_ID`, `AW_LANG` (`en` / `ru`), `AW_SETTINGS` (JSON), `AW_PREVIOUS_PATH` (last published data, may not exist), `AW_STATE_PATH` (button state), `AW_IMAGES_DIR` (write images here), plus every secret listed in `feed.secrets`. A listed secret without a value in `aw.local.json` stops the feed with `FEED_SECRET_MISSING`; `aw doctor` warns when `secrets` sit in the shared `aw.json`.
- stdout: exactly one JSON object — the model, or a timeline:

```json
{"timeline": [
  {"date": "2026-09-14T09:00:00Z", "data": {"temp": 30}},
  {"date": "2026-09-14T10:00:00Z", "data": {"temp": 31}}
], "refreshAfter": "2026-09-14T12:00:00Z"}
```

- stderr: logs, kept in `.aw/logs/<id>.log` (`aw logs <id>`).
- Exit code ≠ 0, a timeout or invalid JSON → the previous data stays, the widget shows it as stale.
- Exit 127 / 126 → `FEED_COMMAND_NOT_FOUND` names the missing or non-executable program and the PATH feeds get. The status keeps the exit code and the last stderr lines.
- `aw doctor` reports every feed: ok N min ago, the last failure, or `STALE_DATA` once the last good data is older than three runs.
- Output is published only when it changed, so an unchanged feed costs no reload.
- Dates — in the timeline envelope and in `Date` fields of your model alike: ISO 8601 (`2026-09-14T09:00:00Z`, fractions allowed) or epoch seconds.
- In samples, write dates as an offset from now — `"+90m"`, `"-4m"`, `"+2h30m"`, `"+6d"` (units `s`, `m`, `h`, `d`, `w`) — so a countdown or “waiting for 4 min” stays alive in every preview instead of expiring with the day you wrote the sample. Feeds print absolute dates: an offset is read again on every redraw.

## State and actions

`AWButton` runs the generated `AWWidgetAction` intent (compiled into the extension and the host app, so macOS can register it): it updates `state.json` for that widget and redraws it (and the dev slot). Actions: `next`, `prev`, `toggle`, `increment`, `set`, `shuffle`, `reset`, `stamp`. The view reads `entry.state`; feeds can read `AW_STATE_PATH`.

## CLI output

Every command accepts `--json`, `--workspace <dir>` and `--lang en|ru` (the language of messages and of `context.pick` in previews; `AW_LANG` sets the default). With `--json` it prints:

```json
{"ok": true, "issues": [{"code": "OVERFLOW", "severity": "error", "message": "…", "hint": "…", "file": "…", "line": 12}], "artifacts": ["…/sheet.png"], "data": {}}
```

Exit codes: `0` ok, `1` checks failed, `2` usage, `3` environment, `4` build failed, `5` shipped but not seen on the desktop.

## Commands

| command | does |
|---|---|
| `aw init [dir]` | new workspace with signing detected |
| `aw gallery` / `aw gallery add <id>` | list the ready-made widgets that ship with the engine / copy one into `widgets/` with its feed and samples |
| `aw templates` / `aw new <id> --template t [--families small,medium]` | scaffold a widget; `aw templates` shows the sizes each template is drawn for |
| `aw preview <id> [--family f] [--scenario s] [--full] [--built-in-sizes] [--open] [--lang ru]` | render the matrix, check the layout, write `sheet.png` + `report.json`; `--open` opens the sheet |
| `aw ship <id> [--scenario s] [--live] [--force] [--no-shot]` | preview → build → install → dev slot → real screenshot |
| `aw build [--no-sign]` / `aw install [--hard]` / `aw rollback` | build and install the app with backups |
| `aw dev <id> [--scenario s] [--live] [--timeout s]` | point the dev slot at a widget, wait until the desktop redraws it, capture it and compare it with the preview |
| `aw shot [--kind k] [--dev]` | capture real widget windows; the dev slot also gets `.aw/shots/<id>-<family>-compare.png` (preview · desktop · outlines) and `SHOT_MISMATCH` when they differ |
| `aw slot [--family f,…] [--timeout s]` | wait until the person puts the dev slot on the desktop, then measure sizes and capture it |
| `aw geometry [--measure]` | desktop widget sizes previews render at; `--measure` reads them from this Mac's system log |
| `aw feed run <id>` / `aw data set <id> <json\|@file>` / `aw data get <id>` | run a feed / push data / read data |
| `aw tick` / `aw daemon install\|status\|uninstall` / `aw logs <id>` | scheduling and logs |
| `aw doctor` / `aw list` / `aw explain [CODE]` | health, widgets, issue codes |
| `aw mcp [--workspace dir] [--call-budget s]` | MCP server over stdio; long calls answer within the budget |

## MCP tools

`aw_init`, `aw_gallery`, `aw_gallery_add`, `aw_templates`, `aw_new`, `aw_preview` (sheet image + report), `aw_ship` (desktop screenshots), `aw_shot`, `aw_slot`, `aw_dev`, `aw_wait`, `aw_doctor`, `aw_list`, `aw_data_set`, `aw_feed_run`, `aw_explain`. Each takes an optional `workspace` path.

- **Long calls.** `aw_ship`, `aw_dev`, `aw_slot` and `aw_feed_run` run as jobs. When a call would outlast the client, it answers with `{"job": {"id", "tool", "stage", "elapsed"}}`; call `aw_wait {"job": "<id>"}` until the final result arrives — the same text, images and data the tool itself returns. The budget is none for Claude Code and 45 s for other clients (Codex and Claude Desktop stop a tool call after 60 s); `aw mcp --call-budget <s>` or `AW_MCP_CALL_BUDGET` override it, `0` means no limit. Identical calls join the running job; `JOB_UNKNOWN` means it ended more than 15 minutes ago, was cancelled or the server restarted.
- **Progress and cancel.** A call with a progress token gets a notification for every stage (preview, build, install, redraw) and a pulse every 10 s. Cancelling a call stops its work: a build is interrupted, waits end, an install swap already under way still finishes.
- **Structured results.** Every tool declares an output schema. Its structured content carries the reply text under `summary`, so clients that show the model only JSON (Claude Code does) still pass on the summary and the hints.
- **Argument errors.** Unknown arguments, values of the wrong type and missing required ones come back together as `INVALID_ARGUMENT`. Widget ids are lowercase letters, digits and dashes, starting with a letter (`WIDGET_ID_INVALID`).
