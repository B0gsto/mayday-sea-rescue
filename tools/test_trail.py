#!/usr/bin/env python3
"""Unit tests for tools/trail.py summaries. Run: python3 tools/test_trail.py"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import trail


class Summaries(unittest.TestCase):
    def test_shown_and_outcome_are_one_prompt(self):
        s = trail.robux_summary(["176 custom RobuxPrompt 1 Wheel Spin15 Shown", "179 custom RobuxPrompt 1 Wheel Spin15 Cancelled"])
        self.assertIn("1 prompts shown, 0 purchases", s)

    def test_older_trails_log_only_the_outcome(self):
        s = trail.robux_summary(["45 custom RobuxPrompt 1 Store Spin1 Cancelled", "50 custom RobuxPrompt 49 Store Spin1 Purchased"])
        self.assertIn("2 prompts shown, 1 purchases, 49 R$", s)

    def test_prompt_left_open_counts_once(self):
        s = trail.robux_summary(["5 custom RobuxPrompt 1 Chip QuickLaunch Shown"])
        self.assertIn("1 prompts shown", s)

    def test_perf_by_device(self):
        s = trail.perf_summary(["13 custom SessionPerf 0 NotReady Unknown Touch", "90 custom SessionPerf 8 5-10s 20-30 Touch"])
        self.assertEqual(s, "Perf: Touch ready 5-10s:1 NotReady:1 fps 20-30:1 Unknown:1")


if __name__ == "__main__":
    unittest.main()
