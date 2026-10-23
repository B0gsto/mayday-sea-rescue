#!/usr/bin/env python3
"""Unit tests for tools/liveops.py: message validation, request building and the schedule/cancel
order, on a fake transport. Run: python3 tools/test_liveops.py"""
import json
import os
import sys
import unittest
from types import SimpleNamespace

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import liveops

NOW = 1792800000  # 2026-10-24 00:00:00 UTC
UNIVERSE = 10771468869


class FakeTransport:
    def __init__(self):
        self.calls = []

    def call(self, method, path, body=None, allow_404=False):
        self.calls.append((method, path, body))
        return {}


class LiveOpsTests(unittest.TestCase):
    def test_times_are_utc(self):
        self.assertEqual(liveops.parse_at("2026-10-25 18:00"), NOW + 42 * 3600)
        self.assertEqual(liveops.parse_at("2026-10-25T18:00Z"), NOW + 42 * 3600)
        self.assertEqual(liveops.parse_at("2026-10-24"), NOW)
        with self.assertRaises(SystemExit):
            liveops.parse_at("tomorrow at six")

    def test_message_rules_match_the_game(self):
        msg = liveops.build_message("GoldenHour", NOW + 3600, 60, now=NOW, nonce="n1")
        self.assertEqual(msg, {"event": "GoldenHour", "startsAt": NOW + 3600,
                               "duration": 3600, "nonce": "n1"})
        self.assertEqual(liveops.build_message("goldenhour", NOW, 1, now=NOW, nonce="n").get("event"),
                         "GoldenHour")
        with self.assertRaises(SystemExit):
            liveops.build_message("Nope", NOW + 60, 60, now=NOW)
        with self.assertRaises(SystemExit):
            liveops.build_message("CalmSeas", NOW + 60, 181, now=NOW)
        with self.assertRaises(SystemExit):
            liveops.build_message("CalmSeas", NOW + 60, 0, now=NOW)
        with self.assertRaises(SystemExit):
            liveops.build_message("CalmSeas", NOW - 3600, 60, now=NOW)
        with self.assertRaises(SystemExit):
            liveops.build_message("CalmSeas", NOW + 7 * 86400 + 1, 60, now=NOW)
        with self.assertRaises(SystemExit):
            liveops.build_message("CalmSeas", NOW + 60, 60, now=NOW, nonce="x" * 65)

    def test_publish_body_is_the_message_json_under_1kb(self):
        msg = liveops.build_message("CalmSeas", NOW + 60, 30, now=NOW, nonce="abc")
        method, path, body = liveops.publish_request(UNIVERSE, msg)
        self.assertEqual(method, "POST")
        self.assertEqual(path, f"/messaging-service/v1/universes/{UNIVERSE}/topics/LiveOps")
        self.assertEqual(json.loads(body["message"]), msg)
        self.assertLess(len(body["message"].encode()), 1024)

    def test_write_updates_the_sorted_map_with_a_ttl(self):
        msg = liveops.build_message("GoldenHour", NOW + 3600, 60, now=NOW, nonce="d")
        method, path, body = liveops.write_request(UNIVERSE, msg, now=NOW)
        self.assertEqual(method, "PATCH")
        self.assertIn(f"/memory-store/sorted-maps/LiveOpsActive/items/active", path)
        self.assertIn("allowMissing=true", path)
        self.assertEqual(json.loads(body["value"]), msg)
        ttl = int(body["ttl"].rstrip("s"))
        self.assertEqual(ttl, 3600 + 3600 + 86400)
        self.assertLessEqual(ttl, 45 * 86400)

    def test_schedule_writes_the_map_before_publishing(self):
        args = SimpleNamespace(event="GoldenHour", at="2026-10-25 18:00", minutes=60,
                               nonce="n1", send=True, universe=UNIVERSE)
        created = []

        def make(key):
            transport = FakeTransport()
            created.append(transport)
            return transport

        original = liveops.Transport
        liveops.Transport = make
        try:
            liveops.schedule(args, now=NOW)
        finally:
            liveops.Transport = original
        self.assertEqual([c[0] for c in created[0].calls], ["PATCH", "POST"])
        msg = json.loads(created[0].calls[0][2]["value"])
        self.assertEqual(msg["event"], "GoldenHour")
        self.assertEqual(json.loads(created[0].calls[1][2]["message"]), msg)

    def test_cancel_deletes_then_publishes(self):
        fake = FakeTransport()
        msg = liveops.cancel_message(now=NOW, nonce="c1")
        liveops.execute(fake, [liveops.delete_request(UNIVERSE),
                               liveops.publish_request(UNIVERSE, msg)])
        self.assertEqual([c[0] for c in fake.calls], ["DELETE", "POST"])
        self.assertTrue(fake.calls[0][1].endswith("/memory-store/sorted-maps/LiveOpsActive/items/active"))
        self.assertEqual(json.loads(fake.calls[1][2]["message"])["event"], "Cancel")

    def test_describe_prints_requests_but_no_key(self):
        msg = liveops.build_message("CalmSeas", NOW + 60, 60, now=NOW, nonce="x")
        text = liveops.describe([
            liveops.publish_request(UNIVERSE, msg),
            liveops.write_request(UNIVERSE, msg, now=NOW),
        ])
        self.assertIn(f"/universes/{UNIVERSE}/topics/LiveOps", text)
        self.assertIn("memory-store/sorted-maps/LiveOpsActive", text)
        self.assertNotIn("x-api-key", text.lower())


if __name__ == "__main__":
    unittest.main()
