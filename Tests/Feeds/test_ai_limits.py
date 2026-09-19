import contextlib
import importlib.util
import io
import sys
import unittest
import urllib.error
from pathlib import Path

sys.dont_write_bytecode = True

FEED =Path(__file__).resolve().parents[2] / "examples" / "widgets" / "ai-limits" / "feed.py"
spec = importlib.util.spec_from_file_location("ai_limits_feed", FEED)
feed = importlib.util.module_from_spec(spec)
spec.loader.exec_module(feed)

NOW = 1_800_000_000.0
HOUR = 3600
TOKEN = "sk-ant-oat01-SECRET-TOKEN-VALUE"


class Dates(unittest.TestCase):
    def test_stamp_reads_iso_fractions_offsets_and_epoch(self):
        self.assertEqual(feed.stamp("2026-09-19T13:10:00.042804+00:00"), "2026-09-19T13:10:00Z")
        self.assertEqual(feed.stamp("2026-09-19T20:10:00+07:00"), "2026-09-19T13:10:00Z")
        self.assertEqual(feed.stamp(NOW), "2027-01-15T08:00:00Z")
        self.assertIsNone(feed.stamp("soon"))
        self.assertIsNone(feed.stamp(None))


class Claude(unittest.TestCase):
    PAYLOAD = {
        "five_hour": {"utilization": 62.4, "resets_at": "2027-01-15T10:00:00+00:00"},
        "seven_day": {"utilization": 34, "resets_at": "2027-01-20T03:00:00+00:00"},
        "limits": [
            {"kind": "session", "percent": 62, "scope": None},
            {"kind": "weekly_scoped", "percent": 41, "scope": {"model": {"display_name": "Fable"}}},
            {"kind": "weekly_scoped", "percent": None, "scope": {"model": {"display_name": "Broken"}}},
            {"kind": "weekly_scoped", "percent": 5, "scope": None},
        ],
    }

    def test_summary_keeps_windows_and_model_limits(self):
        service = feed.claude_summary(self.PAYLOAD, "Max")
        self.assertEqual(sorted(service), ["id", "models", "name", "plan", "session", "state", "week"])
        self.assertEqual(service["state"], "ok")
        self.assertEqual(service["session"], {"percent": 62.4, "resetsAt": "2027-01-15T10:00:00Z", "windowHours": 5})
        self.assertEqual(service["week"]["percent"], 34.0)
        self.assertEqual(service["models"], [{"label": "Fable", "percent": 41.0}])

    def test_summary_survives_an_empty_answer(self):
        service = feed.claude_summary({}, None)
        self.assertIsNone(service["session"])
        self.assertIsNone(service["week"])
        self.assertEqual(service["models"], [])

    def test_a_refused_request_never_prints_the_token(self):
        def refuse(_token):
            raise urllib.error.HTTPError(feed.USAGE_URL, 401, "Unauthorized", {}, None)

        original = (feed.claude_credentials, feed.claude_usage, feed.CLAUDE_HOME)
        feed.claude_credentials = lambda: {"accessToken": TOKEN, "subscriptionType": "max", "expiresAt": (NOW + HOUR) * 1000}
        feed.claude_usage = refuse
        feed.CLAUDE_HOME = Path("/")
        errors = io.StringIO()
        try:
            with contextlib.redirect_stderr(errors):
                service = feed.claude_service()
        finally:
            feed.claude_credentials, feed.claude_usage, feed.CLAUDE_HOME = original
        self.assertEqual(service, {"id": "claude", "name": "Claude", "plan": "Max", "state": "expired"})
        self.assertNotIn(TOKEN, errors.getvalue())
        self.assertNotIn(TOKEN, repr(service))

    def test_plan_names(self):
        self.assertEqual(feed.plan_name("prolite"), "Pro Lite")
        self.assertEqual(feed.plan_name("max"), "Max")
        self.assertEqual(feed.plan_name("enterprise_plus"), "Enterprise Plus")
        self.assertIsNone(feed.plan_name(None))


class Codex(unittest.TestCase):
    def test_entries_without_windows_are_useless(self):
        self.assertFalse(feed.usable({"primary": None, "secondary": None, "credits": {"balance": "0"}}))
        self.assertFalse(feed.usable(None))
        self.assertTrue(feed.usable({"primary": {"used_percent": 0.0}, "secondary": None}))

    def test_window_reads_absolute_and_relative_resets(self):
        absolute = feed.codex_window({"used_percent": 12.5, "window_minutes": 300, "resets_at": NOW + HOUR}, NOW, 5)
        relative = feed.codex_window({"used_percent": 12.5, "window_minutes": 300, "resets_in_seconds": HOUR}, NOW, 5)
        self.assertEqual(absolute, relative)
        self.assertEqual(absolute, {"percent": 12.5, "resetsAt": feed.stamp(NOW + HOUR), "windowHours": 5.0})

    def test_a_window_that_has_reset_counts_as_unused(self):
        limits = {
            "plan_type": "pro",
            "primary": {"used_percent": 95.0, "window_minutes": 300, "resets_at": NOW - 2 * HOUR},
            "secondary": {"used_percent": 40.0, "window_minutes": 10080, "resets_at": NOW + 48 * HOUR},
        }
        service = feed.codex_summary(limits, feed.stamp(NOW - 72 * HOUR), NOW)
        self.assertEqual(service["session"], {"percent": 0.0, "resetsAt": None, "windowHours": 5.0})
        self.assertEqual(service["week"]["percent"], 40.0)
        self.assertEqual(service["state"], "stale")
        self.assertEqual(service["plan"], "Pro")

    def test_old_data_is_not_stale_once_every_window_has_reset(self):
        limits = {
            "primary": {"used_percent": 95.0, "window_minutes": 300, "resets_at": NOW - 2 * HOUR},
            "secondary": {"used_percent": 99.0, "window_minutes": 10080, "resets_at": NOW - HOUR},
        }
        service = feed.codex_summary(limits, feed.stamp(NOW - 300 * HOUR), NOW)
        self.assertEqual(service["state"], "ok")
        self.assertEqual(service["week"]["percent"], 0.0)

    def test_fresh_data_is_ok(self):
        limits = {"primary": {"used_percent": 10.0, "window_minutes": 300, "resets_at": NOW + HOUR}, "secondary": None}
        self.assertEqual(feed.codex_summary(limits, feed.stamp(NOW - 60), NOW)["state"], "ok")


class Summary(unittest.TestCase):
    def service(self, name, state, session, week=None):
        slot = lambda percent: {"percent": percent, "resetsAt": feed.stamp(NOW + HOUR), "windowHours": 5}
        return {
            "id": name.lower(),
            "name": name,
            "state": state,
            "session": slot(session) if session is not None else None,
            "week": slot(week) if week is not None else None,
        }

    def test_worst_is_the_fullest_window_of_a_readable_service(self):
        services = [
            self.service("Claude", "ok", 30, 61),
            self.service("Codex", "stale", 12, 18),
            self.service("Ghost", "expired", 99),
        ]
        worst = feed.worst_window(services)
        self.assertEqual((worst["service"], worst["scope"], worst["percent"]), ("Claude", "week", 61))

    def test_no_readable_service_means_no_worst(self):
        self.assertIsNone(feed.worst_window([self.service("Claude", "no-auth", None)]))
        self.assertEqual(feed.build([]), {"services": [], "worst": None})

    def test_build_keeps_what_the_view_needs_for_the_forecast(self):
        payload = feed.build([self.service("Claude", "ok", 90)])
        self.assertEqual(payload["worst"], {
            "service": "Claude", "scope": "session", "percent": 90, "resetsAt": feed.stamp(NOW + HOUR), "windowHours": 5,
        })
        self.assertEqual(sorted(payload), ["services", "worst"])


class History(unittest.TestCase):
    def service(self, state="ok", session=40.0, week=20.0):
        slot = lambda percent: {"percent": percent, "resetsAt": feed.stamp(NOW + HOUR), "windowHours": 5}
        return {"id": "claude", "name": "Claude", "state": state, "session": slot(session), "week": slot(week)}

    def previous(self, *ages):
        points = [{"at": feed.stamp(NOW - age), "session": 1.0, "week": 2.0} for age in ages]
        return {"services": [{"id": "claude", "history": points}]}

    def test_a_point_is_added_every_half_hour(self):
        services = [self.service()]
        feed.remember(services, self.previous(3 * HOUR, 2 * HOUR), NOW)
        history = services[0]["history"]
        self.assertEqual(len(history), 3)
        self.assertEqual(history[-1], {"at": feed.stamp(NOW), "session": 40.0, "week": 20.0})

    def test_a_recent_point_is_not_repeated(self):
        services = [self.service()]
        feed.remember(services, self.previous(2 * HOUR, 600), NOW)
        self.assertEqual(len(services[0]["history"]), 2)

    def test_points_older_than_a_week_are_dropped_and_the_list_is_capped(self):
        services = [self.service()]
        feed.remember(services, self.previous(8 * 24 * HOUR, 6 * 24 * HOUR), NOW)
        self.assertEqual([point["at"] for point in services[0]["history"]], [feed.stamp(NOW - 6 * 24 * HOUR), feed.stamp(NOW)])
        crowded = self.previous(*[index * 1500 + 1800 for index in range(400, 0, -1)])
        services = [self.service()]
        feed.remember(services, crowded, NOW)
        self.assertEqual(len(services[0]["history"]), feed.HISTORY_POINTS)

    def test_an_unchanged_reading_adds_nothing(self):
        services = [self.service(session=1.0, week=2.0)]
        previous = self.previous(9 * 24 * HOUR, 2 * HOUR)
        feed.remember(services, previous, NOW)
        self.assertEqual(services[0]["history"], previous["services"][0]["history"])

    def test_a_quiet_run_prints_the_same_output(self):
        first = [self.service()]
        feed.remember(first, None, NOW)
        before = feed.build(first)
        second = [self.service()]
        feed.remember(second, before, NOW + 8 * 24 * HOUR)
        self.assertEqual(feed.build(second), before)

    def test_an_unreadable_service_keeps_its_history_without_a_new_point(self):
        services = [{"id": "claude", "name": "Claude", "state": "expired"}]
        feed.remember(services, self.previous(2 * HOUR), NOW)
        self.assertEqual(len(services[0]["history"]), 1)

    def test_no_previous_data_starts_a_history(self):
        services = [self.service()]
        feed.remember(services, None, NOW)
        self.assertEqual(len(services[0]["history"]), 1)
        services = [self.service()]
        feed.remember(services, {"services": "broken"}, NOW)
        self.assertEqual(len(services[0]["history"]), 1)


if __name__ == "__main__":
    unittest.main()
