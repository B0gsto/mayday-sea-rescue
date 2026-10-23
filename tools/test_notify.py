#!/usr/bin/env python3
"""Unit tests for tools/notify.py: the 24 h decision, due listing and the request body, on a fake
transport. Run: python3 tools/test_notify.py"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import notify

NOW = 1790000000
UNIVERSE = 10771468869
TEMPLATES = {"crate_ready": "id-crate", "storm_soon": "id-storm"}


class FakeTransport:
    def __init__(self, entries=None, throttle=False):
        self.entries = entries or {}
        self.throttle = throttle
        self.calls = []

    def get(self, path):
        self.calls.append(("GET", path, None))
        if "/entries?" in path:
            return {"dataStoreEntries": [{"id": uid} for uid in self.entries]}
        for uid, value in self.entries.items():
            if path.endswith("/entries/" + uid):
                return {"value": value}
        raise AssertionError(path)

    def post(self, path, body):
        self.calls.append(("POST", path, body))
        if self.throttle:
            raise notify.ApiError("429", status=429)
        return {"id": "notification-id"}

    def patch(self, path, body):
        self.calls.append(("PATCH", path, body))
        return {}


class NotifyTests(unittest.TestCase):
    def test_notification_body_matches_the_open_cloud_shape(self):
        self.assertEqual(
            notify.notification_body(UNIVERSE, "id-crate", "crate_ready"),
            {
                "source": {"universe": f"universes/{UNIVERSE}"},
                "payload": {"message_id": "id-crate", "type": "MOMENT"},
                "join_experience": {"launch_data": "panel=dailycrate"},
                "analytics_data": {"category": "crate_ready"},
            },
        )

    def test_kind_and_the_one_per_day_cap(self):
        self.assertEqual(notify.kind_for({"c": NOW, "b": NOW, "l": 0}, NOW), "crate_ready")
        self.assertIsNone(notify.kind_for({"c": NOW + 1, "b": NOW, "l": 0}, NOW))  # legacy strongbox "b" is ignored
        self.assertTrue(notify.can_send({"c": NOW, "b": NOW, "l": NOW - notify.DAY}, NOW))
        self.assertFalse(notify.can_send({"c": NOW, "b": NOW, "l": NOW - notify.DAY + 1}, NOW))
        self.assertFalse(notify.can_send({"c": NOW, "b": NOW, "l": NOW + 60}, NOW))

    def test_list_due_reads_only_players_inside_the_cap(self):
        transport = FakeTransport(
            {
                "111": {"c": NOW - 10, "b": NOW + 10, "l": 0},
                "222": {"c": NOW + 10, "b": NOW + 10, "l": 0},
                "333": {"c": NOW - 10, "b": NOW + 10, "l": NOW - 60},
            }
        )
        due = notify.list_due(transport, UNIVERSE, NOW)
        self.assertEqual([(uid, kind) for uid, _, kind in due], [("111", "crate_ready")])

    def test_send_posts_then_records_last_notified(self):
        transport = FakeTransport({"111": {"c": NOW - 10, "b": NOW + 10, "l": 0}})
        due = notify.list_due(transport, UNIVERSE, NOW)
        transport.calls.clear()
        sent, throttled, failed = notify.execute(transport, UNIVERSE, TEMPLATES, due, NOW)
        self.assertEqual((sent, throttled, failed), (1, 0, 0))
        self.assertEqual([c[0] for c in transport.calls], ["POST", "PATCH"])
        self.assertEqual(transport.calls[0][1], "/cloud/v2/users/111/notifications")
        self.assertEqual(transport.calls[0][2]["payload"]["message_id"], "id-crate")
        self.assertEqual(transport.calls[1][2]["value"]["l"], NOW)
        self.assertEqual(transport.calls[1][2]["value"]["c"], NOW - 10)

    def test_a_429_is_not_repeated_today(self):
        transport = FakeTransport({"111": {"c": NOW - 10, "b": NOW + 10, "l": 0}}, throttle=True)
        due = notify.list_due(transport, UNIVERSE, NOW)
        sent, throttled, failed = notify.execute(transport, UNIVERSE, TEMPLATES, due, NOW)
        self.assertEqual((sent, throttled, failed), (0, 1, 0))
        patched = [c for c in transport.calls if c[0] == "PATCH"]
        self.assertEqual(patched[0][2]["value"]["l"], NOW)

    def test_send_is_refused_while_any_template_is_todo(self):
        self.assertEqual(notify.missing_templates(TEMPLATES), [])
        self.assertEqual(notify.missing_templates({"crate_ready": "TODO", "storm_soon": "y"}), ["crate_ready"])
        self.assertEqual(notify.missing_templates({}), list(notify.TEMPLATE_KEYS))


if __name__ == "__main__":
    unittest.main()
