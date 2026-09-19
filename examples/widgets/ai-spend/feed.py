#!/usr/bin/env python3
import json
import os
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path

CLAUDE_PROJECTS = Path.home() / ".claude" / "projects"
CODEX_SESSIONS = Path.home() / ".codex" / "sessions"
PRICES_AS_OF = "2026-09-19"
DAYS = 30
CHART_DAYS = 14
MILLION = 1_000_000

PRICES = [
    ("claude-fable-5-1", "Fable 5.1", 10.0, 50.0, 0.025),
    ("claude-mythos-5-1", "Mythos 5.1", 10.0, 50.0, 0.025),
    ("claude-fable-5", "Fable 5", 10.0, 50.0, 0.1),
    ("claude-mythos-5", "Mythos 5", 10.0, 50.0, 0.1),
    ("claude-opus-5", "Opus 5", 5.0, 25.0, 0.1),
    ("claude-opus-4-1", "Opus 4.1", 15.0, 75.0, 0.1),
    ("claude-opus-4-2", "Opus 4", 15.0, 75.0, 0.1),
    ("claude-opus-4-", "Opus 4", 5.0, 25.0, 0.1),
    ("claude-sonnet-5", "Sonnet 5", 2.0, 10.0, 0.1),
    ("claude-sonnet-4", "Sonnet 4", 3.0, 15.0, 0.1),
    ("claude-haiku-4-5", "Haiku 4.5", 1.0, 5.0, 0.1),
    ("claude-3-5-haiku", "Haiku 3.5", 0.8, 4.0, 0.1),
]


def price_for(model):
    name = str(model or "")
    for prefix, label, base, output, read in PRICES:
        if name.startswith(prefix):
            return label, base, output, read
    return None


def tokens_of(usage):
    creation = usage.get("cache_creation") or {}
    written = int(usage.get("cache_creation_input_tokens") or 0)
    hour = int(creation.get("ephemeral_1h_input_tokens") or 0)
    short = int(creation.get("ephemeral_5m_input_tokens") or 0)
    if hour + short == 0:
        short = written
    return {
        "input": int(usage.get("input_tokens") or 0),
        "output": int(usage.get("output_tokens") or 0),
        "write5m": short,
        "write1h": hour,
        "read": int(usage.get("cache_read_input_tokens") or 0),
    }


def cost_of(tokens, price):
    _, base, output, read = price
    dollars = (
        tokens["input"] * base
        + tokens["write5m"] * base * 1.25
        + tokens["write1h"] * base * 2
        + tokens["read"] * base * read
        + tokens["output"] * output
    )
    return dollars / MILLION


def local_day(timestamp):
    try:
        parsed = datetime.fromisoformat(str(timestamp).replace("Z", "+00:00"))
    except ValueError:
        return None
    return parsed.astimezone().date().isoformat()


def claude_messages(paths):
    seen = set()
    for path in paths:
        try:
            handle = open(path, "rb")
        except OSError:
            continue
        with handle:
            for raw in handle:
                if b'"usage"' not in raw or b'"assistant"' not in raw:
                    continue
                try:
                    entry = json.loads(raw)
                except ValueError:
                    continue
                message = entry.get("message") or {}
                usage = message.get("usage")
                if entry.get("type") != "assistant" or not isinstance(usage, dict):
                    continue
                key = (message.get("id"), entry.get("requestId"))
                if key != (None, None):
                    if key in seen:
                        continue
                    seen.add(key)
                yield message.get("model"), usage, entry.get("timestamp")


def recent(paths, since):
    found = []
    for path in paths:
        try:
            if path.stat().st_mtime >= since:
                found.append(path)
        except OSError:
            continue
    return found


def summarize(messages, today, plan_usd):
    first = (datetime.fromisoformat(today) - timedelta(days=DAYS - 1)).date().isoformat()
    days = {}
    models = {}
    unpriced = 0
    for model, usage, timestamp in messages:
        day = local_day(timestamp)
        if not day or day < first or day > today:
            continue
        tokens = tokens_of(usage)
        total = sum(tokens.values())
        price = price_for(model)
        if price is None:
            if model and not str(model).startswith("<"):
                unpriced += total
            continue
        dollars = cost_of(tokens, price)
        slot = days.setdefault(day, {"usd": 0.0, "tokens": 0})
        slot["usd"] += dollars
        slot["tokens"] += total
        entry = models.setdefault(price[0], {"usd": 0.0, "tokens": 0})
        entry["usd"] += dollars
        entry["tokens"] += total
    chart = []
    for offset in range(CHART_DAYS - 1, -1, -1):
        day = (datetime.fromisoformat(today) - timedelta(days=offset)).date().isoformat()
        slot = days.get(day, {"usd": 0.0, "tokens": 0})
        chart.append({"date": day, "usd": round(slot["usd"], 2), "tokens": slot["tokens"]})
    week_start = (datetime.fromisoformat(today) - timedelta(days=6)).date().isoformat()
    month = sum(slot["usd"] for slot in days.values())
    ranked = sorted(models.items(), key=lambda item: item[1]["usd"], reverse=True)
    return {
        "todayUsd": round(days.get(today, {}).get("usd", 0.0), 2),
        "weekUsd": round(sum(slot["usd"] for day, slot in days.items() if day >= week_start), 2),
        "monthUsd": round(month, 2),
        "monthTokens": sum(slot["tokens"] for slot in days.values()),
        "days": chart,
        "byModel": [{"label": label, "usd": round(entry["usd"], 2), "tokens": entry["tokens"]} for label, entry in ranked[:4]],
        "planUsd": plan_usd,
        "leverage": round(month / plan_usd, 1) if plan_usd else None,
        "unpricedTokens": unpriced,
        "pricesAsOf": PRICES_AS_OF,
    }


def codex_tokens(paths, today):
    first = (datetime.fromisoformat(today) - timedelta(days=DAYS - 1)).date().isoformat()
    total = 0
    for path in paths:
        best = 0
        day = None
        try:
            handle = open(path, "rb")
        except OSError:
            continue
        with handle:
            for raw in handle:
                if b'"total_token_usage"' not in raw:
                    continue
                try:
                    entry = json.loads(raw)
                except ValueError:
                    continue
                usage = (((entry.get("payload") or {}).get("info")) or {}).get("total_token_usage") or {}
                best = max(best, int(usage.get("total_tokens") or 0))
                day = local_day(entry.get("timestamp")) or day
        if day and first <= day <= today:
            total += best
    return total


def main():
    settings = json.loads(os.environ.get("AW_SETTINGS") or "{}")
    plan = settings.get("planUsd")
    now = time.time()
    since = now - (DAYS + 1) * 86400
    today = datetime.fromtimestamp(now).astimezone().date().isoformat()
    payload = summarize(claude_messages(recent(CLAUDE_PROJECTS.glob("*/*.jsonl"), since)), today, float(plan) if plan else None)
    payload["codexTokens"] = codex_tokens(recent(CODEX_SESSIONS.rglob("rollout-*.jsonl"), since), today)
    print(json.dumps(payload, ensure_ascii=False))
    print(f"today ${payload['todayUsd']}, week ${payload['weekUsd']}, 30 days ${payload['monthUsd']}", file=sys.stderr)


if __name__ == "__main__":
    main()
