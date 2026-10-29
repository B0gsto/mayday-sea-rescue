#!/usr/bin/env python3
"""Keeps one machine-wide heavy slot for the life of a Studio window (user CLAUDE.md: 16 GB Mac, at most 2 Studio or
Blender at once). Run detached under `locks.py run heavy -- hold_window.py PATTERN READY`: it touches READY once the
slot is held, waits up to 10 min for a process matching PATTERN (pgrep -f) to appear, then until it is gone.
heavy_slot() below starts it for smoke.py / play.py / publish_studio.py."""
import os
import subprocess
import sys
import time

TOOLS = os.path.expanduser("~/RobloxProjects/tools")
HERE = os.path.abspath(__file__)


def alive(pattern):
    return subprocess.run(["pgrep", "-f", pattern], capture_output=True).returncode == 0


def heavy_slot(pattern, owner, ready, say=print, priority=0):
    """Queue for a heavy slot before opening the window matching `pattern`; returns once a detached holder has it."""
    if alive(pattern):
        return  # that window is already open, so its holder already has a slot
    if os.path.exists(ready):
        os.remove(ready)
    env = {k: v for k, v in os.environ.items() if k != "ROBLOX_LOCKS_HELD"}
    subprocess.Popen([sys.executable, os.path.join(TOOLS, "locks.py"), "run", "--owner", owner, "--cap", "7200",
                      "--timeout", "7200", "--priority", str(priority), "--quiet", "heavy", "--", sys.executable, HERE, pattern, ready],
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True, env=env)
    t0, said = time.time(), 0.0
    while not os.path.exists(ready):
        if time.time() - t0 > 7200:
            sys.exit("no free heavy slot in 2 h (locks.py status shows the holders)")
        if time.time() - said > 120:
            say("[heavy] waiting for a free Studio/Blender slot (2 per machine) ...", flush=True)
            said = time.time()
        time.sleep(5)


if __name__ == "__main__":
    pattern, ready = sys.argv[1], sys.argv[2]
    open(ready, "w").close()
    t0 = time.time()
    while not alive(pattern):
        if time.time() - t0 > 600:
            sys.exit(0)
        time.sleep(5)
    while alive(pattern):
        time.sleep(10)
