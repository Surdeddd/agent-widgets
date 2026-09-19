import importlib.util
import sys
import unittest
from pathlib import Path

sys.dont_write_bytecode = True

FEED = Path(__file__).resolve().parents[2] / "examples" / "widgets" / "github" / "feed.py"
spec = importlib.util.spec_from_file_location("github_feed", FEED)
feed = importlib.util.module_from_spec(spec)
spec.loader.exec_module(feed)


def day(date, count, level="FIRST_QUARTILE"):
    return {"date": date, "contributionCount": count, "contributionLevel": level if count else "NONE"}


def calendar(*weeks):
    return {"totalContributions": sum(item["contributionCount"] for week in weeks for item in week),
            "weeks": [{"contributionDays": list(week)} for week in weeks]}


def days(counts, start=1):
    return [{"date": f"2026-09-{start + index:02d}", "count": count, "level": 1 if count else 0} for index, count in enumerate(counts)]


class Streaks(unittest.TestCase):
    def test_a_streak_runs_up_to_today(self):
        self.assertEqual(feed.streaks(days([0, 2, 1, 3]), "2026-09-04"), (3, 3))

    def test_an_empty_today_does_not_break_the_streak_yet(self):
        self.assertEqual(feed.streaks(days([1, 1, 1, 0]), "2026-09-04"), (3, 3))

    def test_an_empty_yesterday_breaks_it(self):
        self.assertEqual(feed.streaks(days([5, 5, 0, 0]), "2026-09-04"), (0, 2))
        self.assertEqual(feed.streaks(days([5, 5, 0, 1]), "2026-09-04"), (1, 2))

    def test_days_after_today_are_ignored(self):
        self.assertEqual(feed.streaks(days([1, 1, 0, 0, 0]), "2026-09-02"), (2, 2))

    def test_the_longest_streak_may_be_in_the_past(self):
        self.assertEqual(feed.streaks(days([1, 1, 1, 1, 0, 1]), "2026-09-06"), (1, 4))

    def test_no_days_no_streak(self):
        self.assertEqual(feed.streaks([], "2026-09-04"), (0, 0))


class Summary(unittest.TestCase):
    DATA = {
        "viewer": {
            "login": "octocat",
            "contributionsCollection": {"contributionCalendar": calendar(
                [day("2026-09-13", 0), day("2026-09-14", 3, "SECOND_QUARTILE"), day("2026-09-15", 9, "FOURTH_QUARTILE"),
                 day("2026-09-16", 1), day("2026-09-17", 0), day("2026-09-18", 2), day("2026-09-19", 4, "THIRD_QUARTILE")],
                [day("2026-09-20", 1), day("2026-09-21", 0)],
            )},
        },
        "search": {"issueCount": 7, "nodes": [
            {"number": 482, "title": "Retry failed webhooks", "repository": {"nameWithOwner": "octo/checkout"}},
            {},
            None,
        ]},
    }

    def test_levels_keep_the_week_shape(self):
        payload = feed.summarize(self.DATA, "2026-09-21")
        self.assertEqual(payload["weeks"], [[0, 2, 4, 1, 0, 1, 3], [1, 0]])
        self.assertEqual((payload["login"], payload["total"], payload["today"]), ("octocat", 20, 0))
        self.assertEqual((payload["streak"], payload["longest"]), (3, 3))

    def test_recent_days_stop_at_today_and_keep_their_counts(self):
        payload = feed.summarize(self.DATA, "2026-09-19")
        self.assertEqual(payload["recent"], [
            {"date": "2026-09-13", "count": 0}, {"date": "2026-09-14", "count": 3}, {"date": "2026-09-15", "count": 9},
            {"date": "2026-09-16", "count": 1}, {"date": "2026-09-17", "count": 0}, {"date": "2026-09-18", "count": 2},
            {"date": "2026-09-19", "count": 4},
        ])
        self.assertEqual(len(feed.recent_days(days([1] * 30), "2026-09-30")), feed.RECENT_DAYS)
        self.assertEqual(feed.recent_days(days([1] * 30), "2026-09-30")[-1], {"date": "2026-09-30", "count": 1})

    def test_reviews_skip_broken_nodes_and_keep_the_full_count(self):
        payload = feed.summarize(self.DATA, "2026-09-21")
        self.assertEqual(payload["reviewCount"], 7)
        self.assertEqual(payload["reviews"], [{"repo": "octo/checkout", "number": 482, "title": "Retry failed webhooks"}])

    def test_an_empty_answer_is_still_a_payload(self):
        payload = feed.summarize({}, "2026-09-21")
        self.assertEqual((payload["state"], payload["weeks"], payload["reviews"], payload["streak"]), ("ok", [], [], 0))

    def test_blank_matches_the_shape_of_a_real_payload(self):
        self.assertEqual(set(feed.blank("no-gh")), set(feed.summarize({}, "2026-09-21")))
        self.assertEqual(feed.blank("no-gh")["state"], "no-gh")


if __name__ == "__main__":
    unittest.main()
