# Contracts

## Workspace

```
<workspace>/
  aw.json            name, slug, bundlePrefix, locale?, overrides?
  aw.local.json      signingIdentity, teamID (machine-specific, git-ignored)
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
| `feed` | object | `command` (run in the widget folder with `/bin/zsh -c`), `every` (≥ `60s`; < `15m` warns), `timeout` (default `60s`) |
| `settings` | JSON | handed to the feed as `AW_SETTINGS` |

Intervals: `"30s"`, `"15m"`, `"1h"`, `"1d"` or a number of seconds.

## Samples

- `default.json` — required; the preview, the gallery placeholder and the dev slot use it. A sample can be the model itself or the same `{"timeline": [...]}` envelope your feed prints; the preview renders the entry that is current now.
- `long.json` — longest realistic strings; truncation there is a warning, in default an error.
- `empty.json` — `null`, previews the waiting state.
- `<sample>.state.json` — button state for that sample, for example `{"cursor": 2, "cups": 3}`; a shuffled deck is `{"cursor": 5, "seed": 42}` (any non-zero seed), a running timer `{"endsAt": 1789400000}`.
- `<sample>.status.json` — feed status for that sample, for example `{"ok": false, "checkedAt": "2026-09-14T09:00:00Z", "fetchedAt": "2026-09-14T06:00:00Z"}` to preview staleness.
- `images/` — files `AWImage` finds in previews.
- `<sample>.ru.json` / `<sample>.en.json` — the same sample with feed text in that language; `aw preview <id> --lang ru` uses it instead of `<sample>.json`, so feed-localized strings can be checked too.

## What `aw preview` renders

- By default: `default` in light, dark and desktop-idle for every family, every other sample in dark, plus the next two entries of timeline samples.
- `--full`: every sample in light, dark, light-idle and dark-idle.
- Each cell is a PNG next to `sheet.png` (`<family>-<appearance>-<mode>-<sample>.png`); `report.json` lists the issues per cell.

## Feed

- Runs in the widget folder as `/bin/zsh -c "<command>"` with `PATH=/opt/homebrew/bin:/usr/local/bin:~/.local/bin:$PATH`.
- Environment: `AW_WIDGET_ID`, `AW_LANG` (`en` / `ru`), `AW_SETTINGS` (JSON), `AW_PREVIOUS_PATH` (last published data, may not exist), `AW_STATE_PATH` (button state), `AW_IMAGES_DIR` (write images here).
- stdout: exactly one JSON object — the model, or a timeline:

```json
{"timeline": [
  {"date": "2026-09-14T09:00:00Z", "data": {"temp": 30}},
  {"date": "2026-09-14T10:00:00Z", "data": {"temp": 31}}
], "refreshAfter": "2026-09-14T12:00:00Z"}
```

- stderr: logs, kept in `.aw/logs/<id>.log` (`aw logs <id>`).
- Exit code ≠ 0, a timeout or invalid JSON → the previous data stays, the widget shows it as stale.
- Output is published only when it changed, so an unchanged feed costs no reload.
- Dates: ISO 8601 (`2026-09-14T09:00:00Z`, fractions allowed) or epoch seconds.

## State and actions

`AWButton` runs `AWActionIntent` inside the widget: it updates `state.json` for that widget and redraws it (and the dev slot). Actions: `next`, `prev`, `toggle`, `increment`, `set`, `shuffle`, `reset`, `stamp`. The view reads `entry.state`; feeds can read `AW_STATE_PATH`.

## CLI output

Every command accepts `--json`, `--workspace <dir>` and `--lang en|ru` (the language of messages and of `context.pick` in previews; `AW_LANG` sets the default). With `--json` it prints:

```json
{"ok": true, "issues": [{"code": "OVERFLOW", "severity": "error", "message": "…", "hint": "…", "file": "…", "line": 12}], "artifacts": ["…/sheet.png"], "data": {}}
```

Exit codes: `0` ok, `1` checks failed, `2` usage, `3` environment, `4` build failed.

## Commands

| command | does |
|---|---|
| `aw init [dir]` | new workspace with signing detected |
| `aw templates` / `aw new <id> --template t` | scaffold a widget |
| `aw preview <id> [--family f] [--scenario s] [--full] [--open] [--lang ru]` | render the matrix, check the layout, write `sheet.png` + `report.json`; `--open` opens the sheet |
| `aw ship <id> [--scenario s] [--live] [--force] [--no-shot]` | preview → build → install → dev slot → real screenshot |
| `aw build [--no-sign]` / `aw install [--hard]` / `aw rollback` | build and install the app with backups |
| `aw dev <id> [--scenario s] [--live]` | point the dev slot at a widget |
| `aw shot [--kind k] [--dev]` | capture real widget windows |
| `aw feed run <id>` / `aw data set <id> <json\|@file>` / `aw data get <id>` | run a feed / push data / read data |
| `aw tick` / `aw daemon install\|status\|uninstall` / `aw logs <id>` | scheduling and logs |
| `aw doctor` / `aw list` / `aw explain [CODE]` | health, widgets, issue codes |
| `aw mcp [--workspace dir]` | MCP server over stdio |

## MCP tools

`aw_templates`, `aw_new`, `aw_preview` (sheet image + report), `aw_ship` (desktop screenshots), `aw_shot`, `aw_dev`, `aw_doctor`, `aw_list`, `aw_data_set`, `aw_feed_run`, `aw_explain`. Each takes an optional `workspace` path.
