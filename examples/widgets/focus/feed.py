#!/usr/bin/env python3
import json
import os
import sys

settings = json.loads(os.environ.get("AW_SETTINGS") or "{}")
russian = os.environ.get("AW_LANG") == "ru"

focus_minutes = int(settings.get("focusMinutes", 25))
break_minutes = int(settings.get("breakMinutes", 5))

print(json.dumps({
    "focusMinutes": focus_minutes,
    "breakMinutes": break_minutes,
}, ensure_ascii=False))
print("готово" if russian else "ok", file=sys.stderr)
