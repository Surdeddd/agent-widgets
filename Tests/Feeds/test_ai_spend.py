import importlib.util
import json
import os
import sys
import tempfile
import time
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
os.environ["TZ"] = "UTC"
time.tzset()

FEED = Path(__file__).resolve().parents[2] / "examples" / "widgets" / "ai-spend" / "feed.py"
spec = importlib.util.spec_from_file_location("ai_spend_feed", FEED)
feed = importlib.util.module_from_spec(spec)
spec.loader.exec_module(feed)

TODAY = "2026-09-19"
NOON = "2026-09-19T09:00:00Z"


def usage(**tokens):
    return dict({"input_tokens": 0, "output_tokens": 0, "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0}, **tokens)


def line(message_id, request_id, model, tokens, timestamp=NOON, kind="assistant"):
    return json.dumps({"type": kind, "requestId": request_id, "timestamp": timestamp, "message": {"id": message_id, "model": model, "usage": tokens}})


class Prices(unittest.TestCase):
    def test_the_longest_known_prefix_wins(self):
        self.assertEqual(feed.price_for("claude-fable-5-1")[0], "Fable 5.1")
        self.assertEqual(feed.price_for("claude-fable-5")[0], "Fable 5")
        self.assertEqual(feed.price_for("claude-haiku-4-5-20251001")[1:], (1.0, 5.0, 0.1))
        self.assertEqual(feed.price_for("claude-opus-4-8")[1:], (5.0, 25.0, 0.1))
        self.assertEqual(feed.price_for("claude-opus-4-1-20250805")[1:], (15.0, 75.0, 0.1))
        self.assertEqual(feed.price_for("claude-opus-4-20250514")[1:], (15.0, 75.0, 0.1))
        self.assertEqual(feed.price_for("claude-sonnet-4-5")[1:], (3.0, 15.0, 0.1))
        self.assertIsNone(feed.price_for("gpt-5.6-sol"))
        self.assertIsNone(feed.price_for(None))

    def test_a_million_of_each_token_kind(self):
        tokens = {"input": 1_000_000, "output": 1_000_000, "write5m": 1_000_000, "write1h": 1_000_000, "read": 1_000_000}
        self.assertAlmostEqual(feed.cost_of(tokens, feed.price_for("claude-opus-5")), 5 + 25 + 6.25 + 10 + 0.5)
        self.assertAlmostEqual(feed.cost_of(tokens, feed.price_for("claude-fable-5-1")), 10 + 50 + 12.5 + 20 + 0.25)
        self.assertAlmostEqual(feed.cost_of(tokens, feed.price_for("claude-sonnet-5")), 2 + 10 + 2.5 + 4 + 0.2)

    def test_cache_writes_split_by_lifetime_when_the_log_says_so(self):
        plain = feed.tokens_of(usage(cache_creation_input_tokens=900))
        self.assertEqual((plain["write5m"], plain["write1h"]), (900, 0))
        split = feed.tokens_of(usage(cache_creation_input_tokens=900, cache_creation={"ephemeral_5m_input_tokens": 100, "ephemeral_1h_input_tokens": 800}))
        self.assertEqual((split["write5m"], split["write1h"]), (100, 800))


class Logs(unittest.TestCase):
    def test_a_message_logged_per_content_block_counts_once(self):
        tokens = usage(output_tokens=1000)
        with tempfile.TemporaryDirectory() as folder:
            first = Path(folder) / "a.jsonl"
            second = Path(folder) / "b.jsonl"
            first.write_text("\n".join([
                line("msg_1", "req_1", "claude-opus-5", tokens),
                line("msg_1", "req_1", "claude-opus-5", tokens),
                line("msg_2", "req_2", "claude-opus-5", tokens),
                "not json with \"usage\" and \"assistant\"",
                line("msg_3", "req_3", "claude-opus-5", tokens, kind="user"),
            ]) + "\n")
            second.write_text(line("msg_1", "req_1", "claude-opus-5", tokens) + "\n")
            found = list(feed.claude_messages([first, second, Path(folder) / "missing.jsonl"]))
        self.assertEqual(len(found), 2)

    def test_messages_without_ids_are_all_kept(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "a.jsonl"
            path.write_text("\n".join([line(None, None, "claude-opus-5", usage(output_tokens=1))] * 3) + "\n")
            self.assertEqual(len(list(feed.claude_messages([path]))), 3)


class Summary(unittest.TestCase):
    def messages(self):
        million = usage(output_tokens=1_000_000)
        return [
            ("claude-opus-5", million, "2026-09-19T09:00:00Z"),
            ("claude-sonnet-5", million, "2026-09-15T09:00:00Z"),
            ("claude-sonnet-5", million, "2026-08-25T09:00:00Z"),
            ("claude-opus-5", million, "2026-08-01T09:00:00Z"),
            ("gpt-5.6-sol", usage(output_tokens=500), "2026-09-19T09:00:00Z"),
            ("<synthetic>", usage(output_tokens=700), "2026-09-19T09:00:00Z"),
            ("claude-opus-5", million, "not a date"),
        ]

    def test_today_week_and_month_are_windows_ending_today(self):
        payload = feed.summarize(self.messages(), TODAY, 200.0)
        self.assertEqual((payload["todayUsd"], payload["weekUsd"], payload["monthUsd"]), (25.0, 35.0, 45.0))
        self.assertEqual(payload["leverage"], 0.2)
        self.assertEqual(payload["unpricedTokens"], 500)

    def test_the_chart_is_fourteen_days_ending_today(self):
        chart = feed.summarize(self.messages(), TODAY, None)["days"]
        self.assertEqual(len(chart), 14)
        self.assertEqual((chart[0]["date"], chart[-1]["date"]), ("2026-09-06", TODAY))
        self.assertEqual((chart[-1]["usd"], chart[-5]["usd"], chart[0]["usd"]), (25.0, 10.0, 0.0))

    def test_models_are_ranked_by_money_and_the_plan_is_optional(self):
        payload = feed.summarize(self.messages(), TODAY, None)
        self.assertEqual([model["label"] for model in payload["byModel"]], ["Opus 5", "Sonnet 5"])
        self.assertEqual(payload["byModel"][1]["usd"], 20.0)
        self.assertIsNone(payload["leverage"])

    def test_nothing_logged_is_a_valid_payload(self):
        payload = feed.summarize([], TODAY, 200.0)
        self.assertEqual((payload["monthUsd"], payload["byModel"], len(payload["days"])), (0.0, [], 14))


if __name__ == "__main__":
    unittest.main()
