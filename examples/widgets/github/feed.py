#!/usr/bin/env python3
import json
import shutil
import subprocess
import sys
from datetime import date, datetime, timezone

TIMEOUT = 25
RECENT_DAYS = 14
LEVELS = {"NONE": 0, "FIRST_QUARTILE": 1, "SECOND_QUARTILE": 2, "THIRD_QUARTILE": 3, "FOURTH_QUARTILE": 4}
QUERY = """
query {
  viewer {
    login
    contributionsCollection {
      contributionCalendar {
        totalContributions
        weeks { contributionDays { contributionCount contributionLevel date } }
      }
    }
  }
  search(query: "is:pr is:open review-requested:@me archived:false", type: ISSUE, first: 4) {
    issueCount
    nodes { ... on PullRequest { number title repository { nameWithOwner } } }
  }
}
"""


def days_of(calendar):
    days = []
    for week in calendar.get("weeks") or []:
        for day in week.get("contributionDays") or []:
            days.append({
                "date": day.get("date"),
                "count": int(day.get("contributionCount") or 0),
                "level": LEVELS.get(day.get("contributionLevel"), 0),
            })
    return days


def streaks(days, today):
    past = [day for day in days if day["date"] and day["date"] <= today]
    longest = run = 0
    for day in past:
        run = run + 1 if day["count"] > 0 else 0
        longest = max(longest, run)
    current = 0
    for index, day in enumerate(reversed(past)):
        if day["count"] > 0:
            current += 1
        elif index == 0:
            continue
        else:
            break
    return current, longest


def recent_days(days, today):
    past = [day for day in days if day["date"] and day["date"] <= today]
    return [{"date": day["date"], "count": day["count"]} for day in past[-RECENT_DAYS:]]


def weeks_of(days):
    return [[day["level"] for day in days[start:start + 7]] for start in range(0, len(days), 7)]


def summarize(data, today):
    viewer = data.get("viewer") or {}
    calendar = ((viewer.get("contributionsCollection") or {}).get("contributionCalendar")) or {}
    days = days_of(calendar)
    current, longest = streaks(days, today)
    search = data.get("search") or {}
    reviews = []
    for node in search.get("nodes") or []:
        if not node or not node.get("title"):
            continue
        reviews.append({
            "repo": ((node.get("repository") or {}).get("nameWithOwner")) or "",
            "number": int(node.get("number") or 0),
            "title": node["title"],
        })
    return {
        "state": "ok",
        "login": viewer.get("login") or "",
        "total": int(calendar.get("totalContributions") or 0),
        "today": next((day["count"] for day in days if day["date"] == today), 0),
        "streak": current,
        "longest": longest,
        "weeks": weeks_of(days),
        "recent": recent_days(days, today),
        "reviewCount": int(search.get("issueCount") or 0),
        "reviews": reviews,
    }


def blank(state):
    return {"state": state, "login": "", "total": 0, "today": 0, "streak": 0, "longest": 0, "weeks": [], "recent": [], "reviewCount": 0, "reviews": []}


def fetch():
    result = subprocess.run(
        ["gh", "api", "graphql", "-f", f"query={QUERY}"],
        capture_output=True, text=True, timeout=TIMEOUT, check=False,
    )
    if result.returncode != 0:
        message = (result.stderr or "").strip().splitlines()[-1:] or ["gh failed"]
        print(f"gh: {message[0][:200]}", file=sys.stderr)
        return None
    return (json.loads(result.stdout) or {}).get("data")


def main():
    if not shutil.which("gh"):
        print("gh is not installed: brew install gh, then gh auth login", file=sys.stderr)
        print(json.dumps(blank("no-gh")))
        return
    try:
        data = fetch()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"gh failed: {type(error).__name__}", file=sys.stderr)
        sys.exit(1)
    if data is None:
        print(json.dumps(blank("no-auth")))
        return
    today = datetime.now(timezone.utc).astimezone().date().isoformat()
    payload = summarize(data, today)
    print(json.dumps(payload, ensure_ascii=False))
    print(f"{payload['login']}: {payload['total']} this year, streak {payload['streak']}, reviews {payload['reviewCount']}", file=sys.stderr)


if __name__ == "__main__":
    main()
