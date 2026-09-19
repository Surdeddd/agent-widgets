#!/usr/bin/env python3
import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

CLAUDE_PROJECTS = Path.home() / ".claude" / "projects"
CODEX_SESSIONS = Path.home() / ".codex" / "sessions"
TAIL_BYTES = 600_000
ACTIVE_FOR = 3 * 60
SILENT_FOR = 60 * 60
WAITING_FOR = 3 * 60 * 60
LIMIT = 6
HOURS = 12
ENDED = ("end_turn", "stop_sequence", "max_tokens")
HEADLESS = "sdk-cli"
CODEX_WORKING = ("task_started", "token_count", "agent_message", "agent_reasoning", "exec_command_begin", "exec_command_end")


def epoch(value):
    if value in (None, ""):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    try:
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None
    if not parsed.tzinfo:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.timestamp()


def stamp(seconds):
    return datetime.fromtimestamp(seconds, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def tail(path, size=TAIL_BYTES):
    length = os.path.getsize(path)
    with open(path, "rb") as handle:
        handle.seek(max(0, length - size))
        data = handle.read()
    lines = data.decode("utf-8", "ignore").splitlines()
    if length > size:
        lines = lines[1:]
    entries = []
    for line in lines:
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        if isinstance(entry, dict):
            entries.append(entry)
    return entries


def is_prompt(entry):
    if entry.get("type") != "user" or entry.get("isMeta"):
        return False
    content = (entry.get("message") or {}).get("content")
    if isinstance(content, str):
        return bool(content.strip())
    if isinstance(content, list):
        kinds = [block.get("type") for block in content if isinstance(block, dict)]
        return "tool_result" not in kinds and "text" in kinds
    return False


def classify_claude(entries, modified):
    chain = [entry for entry in entries if not entry.get("isSidechain")]
    info = {"project": None, "branch": None, "title": None}
    for entry in reversed(chain):
        if info["title"] is None and entry.get("type") == "ai-title" and entry.get("aiTitle"):
            info["title"] = str(entry["aiTitle"])
        if info["project"] is None and entry.get("cwd"):
            info["project"] = Path(str(entry["cwd"])).name or None
            info["branch"] = entry.get("gitBranch") or None
    last = next((entry for entry in reversed(chain) if entry.get("type") in ("user", "assistant")), None)
    if last is None:
        return None
    if last["type"] == "assistant" and (last.get("message") or {}).get("stop_reason") in ENDED:
        if any(entry.get("entrypoint") == HEADLESS for entry in chain):
            return None
        info["state"] = "waiting"
        info["since"] = epoch(last.get("timestamp")) or modified
        return info
    info["state"] = "working"
    prompt = next((entry for entry in reversed(chain) if is_prompt(entry)), None)
    info["since"] = (epoch(prompt.get("timestamp")) if prompt else None) or modified
    return info


def classify_codex(entries, modified):
    info = {"project": None, "branch": None, "title": None}
    state = None
    since = None
    started = None
    for entry in entries:
        payload = entry.get("payload") or {}
        if entry.get("type") == "session_meta":
            cwd = payload.get("cwd")
            info["project"] = Path(str(cwd)).name if cwd else None
            info["branch"] = ((payload.get("git") or {}).get("branch")) or None
        kind = payload.get("type")
        if kind == "task_started":
            started = epoch(entry.get("timestamp"))
        if kind == "task_complete":
            state, since = "waiting", epoch(entry.get("timestamp"))
        elif kind in CODEX_WORKING:
            state, since = "working", started
    if state is None:
        return None
    info["state"] = state
    info["since"] = since or modified
    return info


def settle(info, modified, now):
    quiet = now - modified
    if info["state"] == "waiting":
        return info if quiet <= WAITING_FOR else None
    if quiet <= ACTIVE_FOR:
        return info
    if quiet > SILENT_FOR:
        return None
    return dict(info, state="silent", since=modified)


def recent(paths, now, horizon):
    found = []
    for path in paths:
        try:
            modified = path.stat().st_mtime
        except OSError:
            continue
        if now - modified <= horizon:
            found.append((modified, path))
    return sorted(found, reverse=True)


def sessions(now):
    rows = []
    sources = (
        ("claude", CLAUDE_PROJECTS.glob("*/*.jsonl"), classify_claude),
        ("codex", CODEX_SESSIONS.rglob("rollout-*.jsonl"), classify_codex),
    )
    for agent, paths, classify in sources:
        for modified, path in recent(paths, now, WAITING_FOR):
            try:
                info = classify(tail(path), modified)
            except OSError:
                continue
            info = settle(info, modified, now) if info else None
            if not info:
                continue
            rows.append({
                "id": f"{agent}-{path.stem[-12:]}",
                "agent": agent,
                "project": info["project"] or path.parent.name.rsplit("-", 1)[-1],
                "branch": info["branch"] if info["branch"] not in (None, "", "HEAD") else None,
                "title": info["title"],
                "state": info["state"],
                "since": stamp(min(info["since"], now)),
            })
    return rows


def ordered(rows):
    ranked = []
    for state in ("waiting", "silent", "working"):
        ranked += sorted((row for row in rows if row["state"] == state), key=lambda row: row["since"], reverse=True)
    return ranked


def today_count(now):
    midnight = datetime.fromtimestamp(now).replace(hour=0, minute=0, second=0, microsecond=0).timestamp()
    total = 0
    for paths in (CLAUDE_PROJECTS.glob("*/*.jsonl"), CODEX_SESSIONS.rglob("rollout-*.jsonl")):
        total += len(recent(paths, now, now - midnight))
    return total


def touched(now):
    found = []
    for paths in (CLAUDE_PROJECTS.glob("*/*.jsonl"), CODEX_SESSIONS.rglob("rollout-*.jsonl")):
        found += [modified for modified, _ in recent(paths, now, HOURS * 3600)]
    return found


def activity(modified, previous, now):
    known = {}
    for item in previous if isinstance(previous, list) else []:
        if isinstance(item, dict) and isinstance(item.get("hour"), str) and isinstance(item.get("sessions"), int):
            known[item["hour"]] = item["sessions"]
    current = int(now) // 3600 * 3600
    buckets = []
    for index in range(HOURS - 1, -1, -1):
        begin = current - index * 3600
        seen = sum(begin <= moment < begin + 3600 for moment in modified)
        buckets.append({"hour": stamp(begin), "sessions": max(seen, known.get(stamp(begin), 0))})
    return buckets


def remembered():
    try:
        with open(os.environ.get("AW_PREVIOUS_PATH") or "", encoding="utf-8") as handle:
            previous = json.load(handle)
    except (OSError, ValueError):
        return None
    return previous.get("activity") if isinstance(previous, dict) else None


def build(rows, today, hours):
    rows = ordered(rows)
    return {
        "working": sum(row["state"] == "working" for row in rows),
        "waiting": sum(row["state"] == "waiting" for row in rows),
        "silent": sum(row["state"] == "silent" for row in rows),
        "sessions": rows[:LIMIT],
        "today": today,
        "activity": hours,
    }


def main():
    now = time.time()
    payload = build(sessions(now), today_count(now), activity(touched(now), remembered(), now))
    print(json.dumps(payload, ensure_ascii=False))
    print(f"working {payload['working']}, waiting {payload['waiting']}, silent {payload['silent']}, today {payload['today']}", file=sys.stderr)


if __name__ == "__main__":
    main()
