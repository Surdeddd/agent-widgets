# Cookbook

Short recipes that compile against the kit. Adapt names, then run `aw preview` — the report and the sheet are the final judges.

## Weather from Open-Meteo (no API key)

`widget.json`:

```json
{
  "id": "weather",
  "name": {"en": "Weather", "ru": "Погода"},
  "families": ["small", "medium", "large"],
  "view": "WeatherView",
  "feed": {"command": "python3 feed.py", "every": "30m", "timeout": "30s"},
  "settings": {"city": "Bangkok", "latitude": 13.75, "longitude": 100.5}
}
```

`feed.py` — standard library only; logs go to stderr, one JSON object to stdout:

```python
#!/usr/bin/env python3
import json
import os
import sys
import urllib.request

settings = json.loads(os.environ.get("AW_SETTINGS") or "{}")
russian = os.environ.get("AW_LANG") == "ru"
url = (
    "https://api.open-meteo.com/v1/forecast"
    f"?latitude={settings['latitude']}&longitude={settings['longitude']}"
    "&current=temperature_2m,weather_code&hourly=temperature_2m"
    "&forecast_days=2&timezone=auto"
)
request = urllib.request.Request(url, headers={"User-Agent": "agent-widgets/0.1"})
with urllib.request.urlopen(request, timeout=20) as response:
    raw = json.load(response)

def describe(code):
    table = [
        ((0,), "sun.max.fill", "Clear", "Ясно"),
        ((1, 2, 3), "cloud.sun.fill", "Partly cloudy", "Переменная облачность"),
        ((45, 48), "cloud.fog.fill", "Fog", "Туман"),
        (tuple(range(51, 68)), "cloud.rain.fill", "Rain", "Дождь"),
        (tuple(range(71, 78)), "cloud.snow.fill", "Snow", "Снег"),
        ((80, 81, 82), "cloud.heavyrain.fill", "Showers", "Ливни"),
        ((95, 96, 99), "cloud.bolt.rain.fill", "Thunderstorm", "Гроза"),
    ]
    for codes, symbol, english, russian_text in table:
        if code in codes:
            return symbol, russian_text if russian else english
    return "cloud.fill", "Cloudy" if not russian else "Облачно"

symbol, condition = describe(raw["current"]["weather_code"])
now = raw["current"]["time"][:13]
hours = [t[:13] for t in raw["hourly"]["time"]]
start = hours.index(now) if now in hours else 0
print(json.dumps({
    "city": settings.get("city", ""),
    "temp": raw["current"]["temperature_2m"],
    "condition": condition,
    "symbol": symbol,
    "hourly": raw["hourly"]["temperature_2m"][start:start + 12],
}, ensure_ascii=False))
print("ok", file=sys.stderr)
```

View: see SKILL.md. Samples: `default.json` with realistic numbers, `long.json` with the longest city and condition names you expect.

## Top list

```swift
struct Service: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let latency: Int
    let healthy: Bool
}

AWList(data.services, maxRows: context.family == .large ? 8 : 3) { service in
    AWRow(service.name, value: context.isSmall ? nil : "\(service.latency) ms", status: service.healthy ? .ok : .critical)
}
```

Medium fits three rows under a header; small has no room for a value column, so it keeps names and status only.

## Goal ring (medium)

```swift
HStack(spacing: AWSpace.m) {
    AWMetric("\(data.done)", unit: "/ \(data.goal)", label: context.pick(en: "glasses today", ru: "стаканов сегодня"))
    Spacer(minLength: 0)
    AWRing(progress: Double(data.done) / Double(max(data.goal, 1)), tint: .blue) {
        AWText("\(Int(Double(data.done) / Double(max(data.goal, 1)) * 100))%", .headline)
    }
    .frame(width: 72, height: 72)
}
```

## Countdown

```swift
AWCountdown(to: data.date, label: data.event)
```

## Timer you start from the widget

```swift
static var tick: AWTick { .everyMinute(count: 60) }

let endsAt = entry.state.date("endsAt")
if let endsAt, endsAt > entry.date {
    AWCountdown(to: endsAt, label: context.pick(en: "Focus", ru: "Фокус"), tint: .orange)
    AWButton(.reset, symbol: "stop.fill", key: "endsAt")
} else {
    AWMetric("25", unit: "min", label: context.pick(en: "Ready", ru: "Готов"))
    AWButton(.stamp, symbol: "play.fill", key: "endsAt", value: "1500")
}
```

`.stamp` records the moment of the tap, not the moment the view was drawn. The minute ticks flip the widget back to “Ready” within a minute after the timer ends. Preview the running state with a sidecar such as `{"endsAt": 1789400000}`.

## Grid of equal items

```swift
let columns = context.family == .medium ? 4 : 2
LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AWSpace.s), count: columns), spacing: AWSpace.m) {
    ForEach(Array(data.cities.prefix(context.isSmall ? 2 : 4))) { city in
        let zone = TimeZone(identifier: city.zone) ?? .current
        VStack(spacing: AWSpace.xs) {
            AWText(city.name, .label)
                .foregroundStyle(.secondary)
            AWText(entry.date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: zone)), .title)
        }
        .frame(maxWidth: .infinity)
    }
}
.frame(maxHeight: .infinity)
```

The same peers in every family, fewer of them in small; times in other zones come from `Date.FormatStyle(timeZone:)` and tick with `static var tick: AWTick { .everyMinute(count: 60) }`.

For days-away counters use a number (`AWMetric("\(days)", unit: "days")`) and `static var tick: AWTick { .every(seconds: 3600, count: 24) }` so the number updates hourly without reloads.

## Bar chart for the week

```swift
AWBarChart(data.days.map { AWBarItem($0.label, $0.value, highlighted: $0.isToday) }, tint: .green)
    .frame(height: context.family == .large ? 120 : 60)
```

## Counter with buttons

```swift
let cups = entry.state.int("cups")
HStack(spacing: AWSpace.s) {
    AWMetric("\(cups)", unit: "/ \(data.goal)")
    Spacer(minLength: 0)
    AWButton(.increment, symbol: "plus", key: "cups")
    AWButton(.reset, symbol: "arrow.counterclockwise", key: "cups")
}
```

Preview a pressed state with a sidecar sample: `samples/default.state.json` containing `{"cups": 3}`.

## Habit week

Keys for per-day state are absolute dates, never column numbers — the seven-day window moves every midnight.

```swift
let days = (0..<7).reversed().map { Calendar.current.date(byAdding: .day, value: -$0, to: entry.date) ?? entry.date }
HStack(spacing: AWSpace.xs) {
    ForEach(days, id: \.self) { day in
        let key = "\(habit.id)@\(AWState.dayKey(day))"
        AWButton(.toggle, key: key) {
            Circle()
                .fill(entry.state.bool(key) ? Color.green : Color.secondary.opacity(0.2))
                .frame(width: 18, height: 18)
        }
    }
}
```

A sidecar like `{"read@2026-09-13": true, "read@2026-09-14": true}` previews a partly done week; the label of an `AWButton` can be any view.

## Flash-card deck

```swift
if data.cards.isEmpty {
    AWEmptyState(symbol: "rectangle.stack", title: context.pick(en: "No cards yet", ru: "Карточек пока нет"))
} else {
    let slot = Int(entry.date.timeIntervalSince1970 / 900)
    let card = data.cards[entry.state.deckIndex(count: data.cards.count, slot: slot)]
    VStack(alignment: .leading, spacing: AWSpace.s) {
        AWText(card.word, card.word.count > 16 ? .title : .display, lines: card.word.count > 16 ? 2 : 1)
        AWText(card.translation, .body, lines: 2)
            .foregroundStyle(.secondary)
        Spacer(minLength: 0)
        HStack(spacing: AWSpace.s) {
            AWButton(.prev, symbol: "chevron.left")
            AWButton(.next, symbol: "chevron.right")
            Spacer(minLength: 0)
            AWButton(entry.state.isShuffled ? .reset : .shuffle, symbol: "shuffle", key: entry.state.isShuffled ? "seed" : "cursor")
        }
    }
}
```

`AWPhaseView` covers missing data, not empty arrays — hence the guard. `.display` makes the word the hero; long phrases step down to `.title` on two lines. Add `static var tick: AWTick { .every(seconds: 900, count: 8) }` so the card changes every 15 minutes without reloads.

## Image of the day

The feed downloads the picture into `$AW_IMAGES_DIR/<name>` and prints `{"title": "…", "image": "<name>"}`; the view shows it:

```swift
AWImage(widget: "photo", name: data.image)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
```

Previews read `samples/images/<name>`.
