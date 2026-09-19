import importlib.util
import sys
import unittest
from pathlib import Path

sys.dont_write_bytecode = True

FEED = Path(__file__).resolve().parents[2] / "examples" / "widgets" / "agents" / "feed.py"
spec = importlib.util.spec_from_file_location("agents_feed", FEED)
feed = importlib.util.module_from_spec(spec)
spec.loader.exec_module(feed)

NOW = 1_800_000_000.0


def at(seconds):
    return feed.stamp(NOW + seconds)


def prompt(text, seconds, **extra):
    return dict({"type": "user", "timestamp": at(seconds), "message": {"content": text}}, **extra)


def tool_result(seconds):
    return {"type": "user", "timestamp": at(seconds), "message": {"content": [{"type": "tool_result", "content": "ok"}]}}


def assistant(stop, seconds, **extra):
    return dict({"type": "assistant", "timestamp": at(seconds), "message": {"stop_reason": stop, "content": []}}, **extra)


class ClaudeSessions(unittest.TestCase):
    def test_a_finished_turn_waits_since_the_answer(self):
        info = feed.classify_claude([prompt("fix it", -600), assistant("tool_use", -500), tool_result(-400), assistant("end_turn", -300)], NOW)
        self.assertEqual((info["state"], info["since"]), ("waiting", NOW - 300))

    def test_a_running_tool_works_since_the_prompt(self):
        info = feed.classify_claude([prompt("fix it", -600), assistant("tool_use", -500), tool_result(-400), assistant("tool_use", -90)], NOW)
        self.assertEqual((info["state"], info["since"]), ("working", NOW - 600))

    def test_a_fresh_prompt_is_work(self):
        info = feed.classify_claude([assistant("end_turn", -900), prompt("next", -5)], NOW)
        self.assertEqual((info["state"], info["since"]), ("working", NOW - 5))

    def test_subagents_and_bookkeeping_do_not_decide_the_state(self):
        entries = [
            prompt("go", -600),
            assistant("end_turn", -300),
            assistant("tool_use", -100, isSidechain=True),
            {"type": "last-prompt", "timestamp": at(-50)},
            {"type": "system", "subtype": "stop_hook_summary", "timestamp": at(-40)},
        ]
        self.assertEqual(feed.classify_claude(entries, NOW)["state"], "waiting")

    def test_tool_results_and_meta_prompts_are_not_prompts(self):
        self.assertFalse(feed.is_prompt(tool_result(0)))
        self.assertFalse(feed.is_prompt(prompt("caveat", 0, isMeta=True)))
        self.assertTrue(feed.is_prompt({"type": "user", "message": {"content": [{"type": "text", "text": "hi"}]}}))

    def test_project_branch_and_title_come_from_the_latest_entries(self):
        entries = [
            prompt("go", -600, cwd="/Users/me/old", gitBranch="main"),
            {"type": "ai-title", "aiTitle": "First title"},
            {"type": "ai-title", "aiTitle": "Ship the gallery"},
            assistant("end_turn", -300, cwd="/Users/me/Projects/agent-widgets", gitBranch="feat/gallery"),
        ]
        info = feed.classify_claude(entries, NOW)
        self.assertEqual((info["project"], info["branch"], info["title"]), ("agent-widgets", "feat/gallery", "Ship the gallery"))

    def test_nothing_to_say_about_a_transcript_without_messages(self):
        self.assertIsNone(feed.classify_claude([{"type": "attachment"}], NOW))


class CodexSessions(unittest.TestCase):
    def event(self, kind, seconds):
        return {"type": "event_msg", "timestamp": at(seconds), "payload": {"type": kind}}

    def test_a_completed_task_waits(self):
        entries = [
            {"type": "session_meta", "payload": {"cwd": "/Users/me/api", "git": {"branch": "main"}}},
            self.event("task_started", -400),
            self.event("token_count", -200),
            self.event("task_complete", -100),
        ]
        info = feed.classify_codex(entries, NOW)
        self.assertEqual((info["state"], info["since"], info["project"], info["branch"]), ("waiting", NOW - 100, "api", "main"))

    def test_a_started_task_works_since_its_start(self):
        info = feed.classify_codex([self.event("task_complete", -900), self.event("task_started", -400), self.event("token_count", -30)], NOW)
        self.assertEqual((info["state"], info["since"]), ("working", NOW - 400))

    def test_a_rollout_without_events_is_skipped(self):
        self.assertIsNone(feed.classify_codex([{"type": "session_meta", "payload": {"cwd": "/x"}}], NOW))


class Lifetimes(unittest.TestCase):
    def info(self, state):
        return {"state": state, "since": NOW - 5000, "project": "p", "branch": None, "title": None}

    def test_recent_work_stays_work(self):
        self.assertEqual(feed.settle(self.info("working"), NOW - 60, NOW)["state"], "working")

    def test_work_that_went_quiet_is_silent_since_the_last_write(self):
        settled = feed.settle(self.info("working"), NOW - 1300, NOW)
        self.assertEqual((settled["state"], settled["since"]), ("silent", NOW - 1300))

    def test_long_dead_work_disappears(self):
        self.assertIsNone(feed.settle(self.info("working"), NOW - feed.SILENT_FOR - 1, NOW))

    def test_waiting_survives_longer_then_disappears(self):
        self.assertEqual(feed.settle(self.info("waiting"), NOW - 2 * 3600, NOW)["state"], "waiting")
        self.assertIsNone(feed.settle(self.info("waiting"), NOW - feed.WAITING_FOR - 1, NOW))


class Payload(unittest.TestCase):
    def row(self, state, seconds):
        return {"id": f"{state}{seconds}", "agent": "claude", "project": "p", "branch": None, "title": None, "state": state, "since": at(seconds)}

    def test_those_who_need_you_come_first(self):
        rows = [self.row("working", -10), self.row("silent", -900), self.row("waiting", -700), self.row("waiting", -60)]
        payload = feed.build(rows, 9, [])
        self.assertEqual([row["id"] for row in payload["sessions"]], ["waiting-60", "waiting-700", "silent-900", "working-10"])
        self.assertEqual((payload["working"], payload["waiting"], payload["silent"], payload["today"]), (1, 2, 1, 9))

    def test_the_list_is_capped_but_the_counts_are_not(self):
        payload = feed.build([self.row("working", -index) for index in range(1, 10)], 9, [])
        self.assertEqual(len(payload["sessions"]), feed.LIMIT)
        self.assertEqual(payload["working"], 9)

    def test_the_activity_travels_with_the_payload(self):
        self.assertEqual(feed.build([], 0, [{"hour": at(0), "sessions": 2}])["activity"], [{"hour": at(0), "sessions": 2}])


class Activity(unittest.TestCase):
    HOUR = 3600
    MOMENT = NOW + 1500

    def counts(self, buckets):
        return [item["sessions"] for item in buckets]

    def test_twelve_aligned_hours_end_with_the_current_one(self):
        buckets = feed.activity([], None, self.MOMENT)
        self.assertEqual(len(buckets), feed.HOURS)
        self.assertEqual(buckets[-1]["hour"], at(0))
        self.assertEqual(buckets[0]["hour"], at(-11 * self.HOUR))
        self.assertEqual(self.counts(buckets), [0] * feed.HOURS)

    def test_a_first_run_counts_sessions_by_their_last_write(self):
        touched = [NOW + 60, NOW + 900, NOW - 10, NOW - 2 * self.HOUR - 5, NOW - 40 * self.HOUR]
        buckets = feed.activity(touched, None, self.MOMENT)
        self.assertEqual(self.counts(buckets)[-4:], [1, 0, 1, 2])
        self.assertEqual(sum(self.counts(buckets)), 4)

    def test_an_hour_keeps_the_sessions_it_has_already_seen(self):
        earlier = feed.activity([NOW - 100, NOW - 200, NOW - 300], None, NOW - 50)
        self.assertEqual(self.counts(earlier)[-1], 3)
        later = feed.activity([NOW + 100, NOW + 200, NOW - 300], earlier, self.MOMENT)
        self.assertEqual(self.counts(later)[-2:], [3, 2])

    def test_old_hours_roll_off_and_a_broken_memory_is_ignored(self):
        earlier = feed.activity([NOW - 11 * self.HOUR + 5], None, NOW + 10)
        self.assertEqual(self.counts(earlier)[0], 1)
        later = feed.activity([], earlier, NOW + self.HOUR + 10)
        self.assertEqual(self.counts(later), [0] * feed.HOURS)
        for broken in ("nope", [1, "x", {"hour": 5}], {"hour": at(0)}):
            self.assertEqual(self.counts(feed.activity([], broken, self.MOMENT)), [0] * feed.HOURS)


if __name__ == "__main__":
    unittest.main()
