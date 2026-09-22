#!/usr/bin/env python3
"""Run every LazyEmacs ERT suite, with no package downloads or user state writes."""
import argparse
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--offline-only", action="store_true", help="Check syntax and startup contracts without installed packages")
parser.add_argument("--emacs", default=os.environ.get("EMACS", "emacs"), help="Emacs executable (default: EMACS or emacs)")
args = parser.parse_args()
environment = {**os.environ, "LAZYEMACS_OFFLINE": "1"}


def run(script, suite=None):
    env = {**environment}
    if suite:
        env["LAZYEMACS_TEST_SUITE"] = suite.name
    print(f"Checking {suite.name if suite else script}", flush=True)
    result = subprocess.run([args.emacs, "-Q", "--batch", "--load", script], cwd=ROOT, env=env)
    if result.returncode:
        raise SystemExit(result.returncode)


run("scripts/check.el")
if not args.offline_only:
    for suite in sorted((ROOT / "tests").glob("*-tests.el")):
        if suite.name != "distribution-tests.el":
            run("scripts/integration.el", suite)
print("All requested checks passed.", flush=True)
