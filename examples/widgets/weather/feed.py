#!/usr/bin/env python3
import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta

WEATHER_TABLE = [
    ((0,), "sun.max.fill", "Clear", "Ясно"),
    ((1, 2, 3), "cloud.sun.fill", "Partly cloudy", "Переменная облачность"),
    ((45, 48), "cloud.fog.fill", "Fog", "Туман"),
    (tuple(range(51, 68)), "cloud.rain.fill", "Rain", "Дождь"),
    (tuple(range(71, 78)), "cloud.snow.fill", "Snow", "Снег"),
    ((80, 81, 82), "cloud.heavyrain.fill", "Showers", "Ливни"),
    ((95, 96, 99), "cloud.bolt.rain.fill", "Thunderstorm", "Гроза"),
]

ENTRY_HOURS = 10
WINDOW_HOURS = 8
BANGKOK_UTC_OFFSET = 7


def describe(code, russian):
    for codes, symbol, english, russian_text in WEATHER_TABLE:
        if code in codes:
            return symbol, russian_text if russian else english
    return "cloud.fill", "Облачно" if russian else "Cloudy"


def hour_stamp(iso_time):
    return f"{iso_time}:00Z"


def local_label(iso_time):
    utc_hour = int(iso_time[11:13])
    local_hour = (utc_hour + BANGKOK_UTC_OFFSET) % 24
    return f"{local_hour:02d}:00"


def fetch(latitude, longitude):
    url = (
        "https://api.open-meteo.com/v1/forecast"
        f"?latitude={latitude}&longitude={longitude}"
        "&current=temperature_2m,weather_code"
        "&hourly=temperature_2m,weather_code"
        "&forecast_days=2&timezone=UTC"
    )
    with urllib.request.urlopen(url, timeout=20) as response:
        return json.load(response)


def build_timeline(raw, city, russian):
    hourly_times = raw["hourly"]["time"]
    hourly_temps = raw["hourly"]["temperature_2m"]
    hourly_codes = raw["hourly"]["weather_code"]

    now_hour = raw["current"]["time"][:13]
    start = next((i for i, t in enumerate(hourly_times) if t[:13] == now_hour), 0)
    entry_count = min(ENTRY_HOURS, max(1, len(hourly_times) - start))

    timeline = []
    for offset in range(entry_count):
        idx = start + offset
        symbol, condition = describe(hourly_codes[idx], russian)
        window_end = min(idx + WINDOW_HOURS, len(hourly_times))

        hourly = hourly_temps[idx:window_end]
        labels = [local_label(t) for t in hourly_times[idx:window_end]]
        symbols = [describe(code, russian)[0] for code in hourly_codes[idx:window_end]]

        timeline.append({
            "date": hour_stamp(hourly_times[idx]),
            "data": {
                "city": city,
                "temp": hourly_temps[idx],
                "condition": condition,
                "symbol": symbol,
                "hourly": hourly,
                "hourlyLabels": labels,
                "hourlySymbols": symbols,
            },
        })

    last_date = datetime.strptime(hour_stamp(hourly_times[start + entry_count - 1]), "%Y-%m-%dT%H:%M:%SZ")
    refresh_after = (last_date + timedelta(hours=2)).strftime("%Y-%m-%dT%H:%M:%SZ")
    return timeline, refresh_after


def main():
    settings = json.loads(os.environ.get("AW_SETTINGS") or "{}")
    russian = os.environ.get("AW_LANG") == "ru"
    latitude = settings.get("latitude", 13.75)
    longitude = settings.get("longitude", 100.5)
    city_en = settings.get("city", "Bangkok")
    city = "Бангкок" if russian and city_en == "Bangkok" else city_en

    try:
        raw = fetch(latitude, longitude)
    except (urllib.error.URLError, TimeoutError, ValueError, KeyError) as exc:
        print(f"fetch failed: {exc}", file=sys.stderr)
        sys.exit(1)

    try:
        timeline, refresh_after = build_timeline(raw, city, russian)
    except (KeyError, IndexError, ValueError) as exc:
        print(f"unexpected response shape: {exc}", file=sys.stderr)
        sys.exit(1)

    print(json.dumps({"timeline": timeline, "refreshAfter": refresh_after}, ensure_ascii=False))
    print("ok", file=sys.stderr)


if __name__ == "__main__":
    main()
