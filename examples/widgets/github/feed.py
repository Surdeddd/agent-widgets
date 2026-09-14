#!/usr/bin/env python3
import json
import os
import sys
import urllib.error
import urllib.request

settings = json.loads(os.environ.get("AW_SETTINGS") or "{}")
owner = settings.get("owner", "apple")
repo = settings.get("repo", "swift")

url = f"https://api.github.com/repos/{owner}/{repo}"
request = urllib.request.Request(
    url,
    headers={
        "Accept": "application/vnd.github+json",
        "User-Agent": "agent-widgets-github-widget",
    },
)

try:
    with urllib.request.urlopen(request, timeout=20) as response:
        raw = json.load(response)
except (urllib.error.URLError, urllib.error.HTTPError) as error:
    print(f"github api request failed: {error}", file=sys.stderr)
    sys.exit(1)

stars = raw.get("stargazers_count", 0)
forks = raw.get("forks_count", 0)
open_issues = raw.get("open_issues_count", 0)

history = []
previous = os.environ.get("AW_PREVIOUS_PATH")
if previous and os.path.exists(previous):
    with open(previous, encoding="utf-8") as handle:
        history = json.load(handle).get("starHistory", [])
history = (history + [stars])[-24:]
stars_change = (
    (history[-1] - history[0]) / history[0]
    if len(history) > 1 and history[0]
    else None
)

print(json.dumps({
    "owner": raw.get("owner", {}).get("login", owner),
    "repo": raw.get("name", repo),
    "stars": stars,
    "forks": forks,
    "openIssues": open_issues,
    "starsChange": stars_change,
    "starHistory": [float(value) for value in history],
}, ensure_ascii=False))
print("ok", file=sys.stderr)
