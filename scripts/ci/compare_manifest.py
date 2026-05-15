#!/usr/bin/env python3
"""Compare current build fingerprint with the previous published manifest."""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import sys
import urllib.error
import urllib.request
from typing import Any


WORLD_INVALIDATOR_COMPONENTS = {"foundation_sha", "global_packaging_sha", "toolchain_cache_sha"}


def load_json_path(path: pathlib.Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def load_json_url(url: str, timeout: int = 20) -> dict[str, Any] | None:
    if not url:
        return None
    try:
        with urllib.request.urlopen(url, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        print(f"Previous manifest unavailable from {url}: {exc}", file=sys.stderr)
        return None


def compare_fingerprints(current: dict[str, Any], previous: dict[str, Any] | None) -> dict[str, Any]:
    if not previous:
        return {
            "needs_build": True,
            "force_world_rebuild": True,
            "reason": "no previous manifest",
            "changed_components": [],
        }

    if current.get("build_fingerprint") == previous.get("build_fingerprint"):
        return {
            "needs_build": False,
            "force_world_rebuild": False,
            "reason": "build fingerprint matches previous successful manifest",
            "changed_components": [],
        }

    cur_components = current.get("components", {}) or {}
    prev_components = previous.get("components", {}) or {}
    changed = sorted(
        key for key in set(cur_components) | set(prev_components) if cur_components.get(key) != prev_components.get(key)
    )
    force_world = bool(WORLD_INVALIDATOR_COMPONENTS.intersection(changed))
    return {
        "needs_build": True,
        "force_world_rebuild": force_world,
        "reason": "build fingerprint changed",
        "changed_components": changed,
    }


def write_github_output(values: dict[str, Any]) -> None:
    output = os.environ.get("GITHUB_OUTPUT")
    if not output:
        return
    with open(output, "a", encoding="utf-8") as fh:
        for key, value in values.items():
            if isinstance(value, bool):
                text = "true" if value else "false"
            elif isinstance(value, (list, dict)):
                text = json.dumps(value, sort_keys=True)
            else:
                text = str(value)
            fh.write(f"{key}={text}\n")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--current", default=".ci/build-fingerprint.json", type=pathlib.Path)
    parser.add_argument("--previous", type=pathlib.Path)
    parser.add_argument("--previous-url", default="")
    parser.add_argument("--output", default=".ci/build-decision.json", type=pathlib.Path)
    args = parser.parse_args(argv)

    current = json.loads(args.current.read_text(encoding="utf-8"))
    previous = load_json_path(args.previous) if args.previous else None
    if previous is None and args.previous_url:
        previous = load_json_url(args.previous_url)
    decision = compare_fingerprints(current, previous)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(decision, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    write_github_output(decision)
    print(json.dumps(decision, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
