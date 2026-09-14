#!/usr/bin/env python3
import datetime
import json
import os
import sys
import urllib.request

API = "https://api.frankfurter.dev/v1"
DEFAULT_BASE = "USD"
DEFAULT_SYMBOLS = ["EUR", "GBP", "JPY", "THB"]
NAMES = {
    "EUR": ("Euro", "Евро"),
    "GBP": ("British pound", "Фунт стерлингов"),
    "JPY": ("Japanese yen", "Японская иена"),
    "THB": ("Thai baht", "Тайский бат"),
}


def name_for(code, russian):
    en, ru = NAMES.get(code, (code, code))
    return ru if russian else en


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "agent-widgets-fx/1.0"})
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.load(response)


def main():
    russian = os.environ.get("AW_LANG") == "ru"
    settings = json.loads(os.environ.get("AW_SETTINGS") or "{}")
    base = settings.get("base", DEFAULT_BASE)
    symbols = settings.get("symbols", DEFAULT_SYMBOLS)

    today = datetime.date.today()
    start = today - datetime.timedelta(days=30)
    url = f"{API}/{start.isoformat()}..{today.isoformat()}?from={base}&to={','.join(symbols)}"
    series = fetch(url)
    dates = sorted(series.get("rates", {}).keys())
    if not dates:
        raise RuntimeError("empty rate series")

    rates = []
    for code in symbols:
        history = [series["rates"][d][code] for d in dates if code in series["rates"][d]]
        if not history:
            continue
        first, last = history[0], history[-1]
        change = (last - first) / first if first else 0.0
        rates.append({
            "code": code,
            "name": name_for(code, russian),
            "rate": last,
            "changePct": change,
            "history": history,
        })

    print(json.dumps({"base": base, "rates": rates}, ensure_ascii=False))
    print(f"ok: {len(rates)} rates across {len(dates)} days", file=sys.stderr)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(1)
