#!/usr/bin/env python3
import json
import os
import sys

lang = os.environ.get("AW_LANG", "en")
settings = json.loads(os.environ.get("AW_SETTINGS") or "{}")
habits = settings.get("habits", [])

result = [
    {"id": habit.get("id", ""), "name": habit.get(lang) or habit.get("en") or habit.get("id", "")}
    for habit in habits
]

print(json.dumps({"habits": result}, ensure_ascii=False))
print(f"ok: {len(result)} habits", file=sys.stderr)
