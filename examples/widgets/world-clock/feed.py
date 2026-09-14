#!/usr/bin/env python3
import json
import os
import sys

CITY_TABLE = {
    "bangkok": ("Asia/Bangkok", "Bangkok", "Бангкок"),
    "london": ("Europe/London", "London", "Лондон"),
    "new-york": ("America/New_York", "New York", "Нью-Йорк"),
    "moscow": ("Europe/Moscow", "Moscow", "Москва"),
    "tokyo": ("Asia/Tokyo", "Tokyo", "Токио"),
    "sydney": ("Australia/Sydney", "Sydney", "Сидней"),
    "los-angeles": ("America/Los_Angeles", "Los Angeles", "Лос-Анджелес"),
    "dubai": ("Asia/Dubai", "Dubai", "Дубай"),
    "paris": ("Europe/Paris", "Paris", "Париж"),
    "berlin": ("Europe/Berlin", "Berlin", "Берлин"),
    "singapore": ("Asia/Singapore", "Singapore", "Сингапур"),
    "hong-kong": ("Asia/Hong_Kong", "Hong Kong", "Гонконг"),
    "sao-paulo": ("America/Sao_Paulo", "Sao Paulo", "Сан-Паулу"),
    "kuala-lumpur": ("Asia/Kuala_Lumpur", "Kuala Lumpur", "Куала-Лумпур"),
    "port-moresby": ("Pacific/Port_Moresby", "Port Moresby", "Порт-Морсби"),
    "addis-ababa": ("Africa/Addis_Ababa", "Addis Ababa", "Аддис-Абеба"),
    "port-au-prince": ("America/Port-au-Prince", "Port-au-Prince", "Порт-о-Пренс"),
    "shanghai": ("Asia/Shanghai", "Shanghai", "Шанхай"),
    "mumbai": ("Asia/Kolkata", "Mumbai", "Мумбаи"),
    "toronto": ("America/Toronto", "Toronto", "Торонто"),
}

DEFAULT_CITIES = ["bangkok", "london", "new-york", "moscow"]


def main():
    settings = json.loads(os.environ.get("AW_SETTINGS") or "{}")
    russian = os.environ.get("AW_LANG") == "ru"
    keys = settings.get("cities") or DEFAULT_CITIES

    cities = []
    skipped = []
    for key in keys:
        entry = CITY_TABLE.get(key)
        if entry is None:
            skipped.append(key)
            continue
        time_zone_id, english_name, russian_name = entry
        cities.append({
            "id": key,
            "name": russian_name if russian else english_name,
            "timeZoneId": time_zone_id,
        })

    print(json.dumps({"cities": cities}, ensure_ascii=False))
    print(f"ok cities={len(cities)} skipped={skipped}", file=sys.stderr)


if __name__ == "__main__":
    main()
