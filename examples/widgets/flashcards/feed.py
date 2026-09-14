#!/usr/bin/env python3
import json
import os

russian = os.environ.get("AW_LANG") == "ru"
deck_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "deck.json")
with open(deck_path, encoding="utf-8") as handle:
    cards = json.load(handle)

print(json.dumps({
    "kicker": "Англ → рус" if russian else "EN → RU",
    "cards": cards,
}, ensure_ascii=False))
