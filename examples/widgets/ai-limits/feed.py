#!/usr/bin/env python3
import getpass
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

TIMEOUT = 15
USER_AGENT = "agent-widgets (+https://github.com/Surdeddd/agent-widgets)"
USAGE_URL = "https://api.anthropic.com/api/oauth/usage"
CLAUDE_HOME = Path.home() / ".claude"
CODEX_HOME = Path.home() / ".codex"
STALE_AFTER = 24 * 3600
HISTORY_SECONDS = 7 * 86400
HISTORY_STEP = 1800
HISTORY_POINTS = 336
SCAN_FILES = 200
SCAN_DAYS = 21


def moment(value):
    if value in (None, ""):
        return None
    if isinstance(value, (int, float)):
        try:
            return datetime.fromtimestamp(float(value), timezone.utc)
        except (OverflowError, OSError, ValueError):
            return None
    try:
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)


def stamp(value):
    point = moment(value)
    return point.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ") if point else None


def epoch(value):
    point = moment(value)
    return point.timestamp() if point else None


def read_json(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return None


def percentage(value):
    try:
        return round(float(value), 1)
    except (TypeError, ValueError):
        return None


def window(percent, resets, hours):
    value = percentage(percent)
    if value is None:
        return None
    return {"percent": value, "resetsAt": stamp(resets), "windowHours": hours}


def account_name():
    try:
        return getpass.getuser()
    except (KeyError, OSError):
        return ""


def claude_credentials():
    best = None
    user = account_name()
    for account in (user, "unknown", None):
        command = ["security", "find-generic-password", "-s", "Claude Code-credentials", "-w"]
        if account:
            command[-1:-1] = ["-a", account]
        try:
            result = subprocess.run(command, capture_output=True, text=True, timeout=TIMEOUT, check=False)
        except (OSError, subprocess.SubprocessError):
            continue
        if result.returncode != 0 or not result.stdout.strip():
            continue
        try:
            record = (json.loads(result.stdout) or {}).get("claudeAiOauth")
        except ValueError:
            continue
        if not record or not record.get("accessToken"):
            continue
        if not best or record.get("expiresAt", 0) > best.get("expiresAt", 0):
            best = record
    if best:
        return best
    stored = read_json(CLAUDE_HOME / ".credentials.json") or {}
    record = stored.get("claudeAiOauth", stored)
    return record if str(record.get("accessToken", "")).startswith("sk-ant-") else None


PLAN_NAMES = {"prolite": "Pro Lite", "max": "Max", "pro": "Pro", "plus": "Plus", "team": "Team"}


def plan_name(raw):
    plan = str(raw or "").strip().lower()
    if not plan:
        return None
    return PLAN_NAMES.get(plan, plan.replace("_", " ").title())


def plan_label(record):
    return plan_name(record.get("subscriptionType"))


def claude_usage(token):
    request = urllib.request.Request(
        USAGE_URL,
        headers={
            "Authorization": f"Bearer {token}",
            "anthropic-beta": "oauth-2025-04-20",
            "User-Agent": USER_AGENT,
            "Accept": "application/json",
        },
    )
    with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
        return json.load(response)


def claude_service():
    if not CLAUDE_HOME.exists():
        return None
    record = claude_credentials()
    if not record:
        return {"id": "claude", "name": "Claude", "state": "no-auth"}
    plan = plan_label(record)
    expires = (record.get("expiresAt") or 0) / 1000
    if expires and time.time() > expires:
        return {"id": "claude", "name": "Claude", "plan": plan, "state": "expired"}
    try:
        payload = claude_usage(record["accessToken"])
    except urllib.error.HTTPError as error:
        print(f"claude usage answered {error.code}", file=sys.stderr)
        state = "expired" if error.code in (401, 403) else "error"
        return {"id": "claude", "name": "Claude", "plan": plan, "state": state}
    except (urllib.error.URLError, OSError, ValueError, TimeoutError) as error:
        print(f"claude usage failed: {type(error).__name__}", file=sys.stderr)
        return {"id": "claude", "name": "Claude", "plan": plan, "state": "error"}

    return claude_summary(payload, plan)


def claude_summary(payload, plan):
    five = payload.get("five_hour") or {}
    week = payload.get("seven_day") or {}
    models = []
    for item in payload.get("limits") or []:
        label = ((item.get("scope") or {}).get("model") or {}).get("display_name")
        percent = percentage(item.get("percent"))
        if item.get("kind") != "weekly_scoped" or not label or percent is None:
            continue
        models.append({"label": label, "percent": percent})
    return {
        "id": "claude",
        "name": "Claude",
        "plan": plan,
        "state": "ok",
        "session": window(five.get("utilization"), five.get("resets_at"), 5),
        "week": window(week.get("utilization"), week.get("resets_at"), 168),
        "models": models[:3],
    }


def codex_rate_limits():
    sessions = CODEX_HOME / "sessions"
    if not sessions.exists():
        return None
    files = []
    oldest = time.time() - SCAN_DAYS * 86400
    for path in sessions.rglob("rollout-*.jsonl"):
        try:
            modified = path.stat().st_mtime
        except OSError:
            continue
        if modified >= oldest:
            files.append((modified, path))
    files.sort(reverse=True)
    for _, path in files[:SCAN_FILES]:
        found = None
        try:
            with open(path, "rb") as handle:
                for raw in handle:
                    if b'"rate_limits"' not in raw:
                        continue
                    try:
                        entry = json.loads(raw)
                    except ValueError:
                        continue
                    limits = (entry.get("payload") or {}).get("rate_limits")
                    if usable(limits):
                        found = (limits, entry.get("timestamp"))
        except OSError:
            continue
        if found:
            return found
    return None


def usable(limits):
    if not isinstance(limits, dict):
        return False
    return any(
        isinstance(limits.get(key), dict) and limits[key].get("used_percent") is not None
        for key in ("primary", "secondary")
    )


def codex_window(raw, base, hours):
    if not raw:
        return None
    percent = percentage(raw.get("used_percent"))
    if percent is None:
        return None
    minutes = raw.get("window_minutes")
    resets = raw.get("resets_at")
    if resets is None and raw.get("resets_in_seconds") is not None and base:
        resets = base + float(raw["resets_in_seconds"])
    return {
        "percent": percent,
        "resetsAt": stamp(resets),
        "windowHours": round(minutes / 60, 2) if minutes else hours,
    }


def settled(slot, now):
    if not slot:
        return None
    resets = epoch(slot.get("resetsAt"))
    if resets is not None and resets <= now:
        return {"percent": 0.0, "resetsAt": None, "windowHours": slot.get("windowHours")}
    return slot


def codex_service(now=None):
    if not CODEX_HOME.exists():
        return None
    found = codex_rate_limits()
    if not found:
        return {"id": "codex", "name": "Codex", "state": "absent"}
    return codex_summary(found[0], found[1], now or time.time())


def codex_summary(limits, timestamp, now):
    base = epoch(timestamp) or now
    session = settled(codex_window(limits.get("primary"), base, 5), now)
    week = settled(codex_window(limits.get("secondary"), base, 168), now)
    open_windows = [slot for slot in (session, week) if slot and slot.get("resetsAt")]
    stale = now - base > STALE_AFTER and bool(open_windows)
    return {
        "id": "codex",
        "name": "Codex",
        "plan": plan_name(limits.get("plan_type")),
        "state": "stale" if stale else "ok",
        "session": session,
        "week": week,
        "asOf": stamp(base),
    }


def worst_window(services):
    candidates = []
    for service in services:
        if service.get("state") not in ("ok", "stale"):
            continue
        for scope in ("session", "week"):
            slot = service.get(scope)
            if slot:
                candidates.append({
                    "service": service["name"],
                    "scope": scope,
                    "percent": slot["percent"],
                    "resetsAt": slot.get("resetsAt"),
                    "windowHours": slot.get("windowHours"),
                })
    if not candidates:
        return None
    return max(candidates, key=lambda item: item["percent"])


def build(services):
    return {"services": services, "worst": worst_window(services)}


def remember(services, previous, now):
    known = {}
    listed = (previous or {}).get("services") if isinstance(previous, dict) else None
    for item in listed if isinstance(listed, list) else []:
        if isinstance(item, dict) and isinstance(item.get("history"), list):
            known[item.get("id")] = item["history"]
    for service in services:
        points = list(known.get(service["id"], []))
        session = service.get("session")
        week = service.get("week")
        reading = {"session": session["percent"] if session else None, "week": week["percent"] if week else None}
        fresh = service.get("state") == "ok" and (session or week)
        last = points[-1] if points else {}
        due = not points or now - (epoch(last.get("at")) or 0) >= HISTORY_STEP
        moved = any(last.get(key) != value for key, value in reading.items())
        if fresh and due and moved:
            points.append({"at": stamp(now), **reading})
            points = [point for point in points if now - (epoch(point.get("at")) or 0) <= HISTORY_SECONDS][-HISTORY_POINTS:]
        service["history"] = points


def main():
    now = time.time()
    services = [service for service in (claude_service(), codex_service(now)) if service]
    remember(services, read_json(os.environ.get("AW_PREVIOUS_PATH") or ""), now)
    print(json.dumps(build(services), ensure_ascii=False))
    print(f"services: {', '.join(item['id'] + '=' + item['state'] for item in services) or 'none'}", file=sys.stderr)


if __name__ == "__main__":
    main()
