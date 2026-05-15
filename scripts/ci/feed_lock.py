#!/usr/bin/env python3
"""Resolve Entware/OpenWrt feed inputs into a deterministic lock file."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import shlex
import subprocess
import sys
from typing import Any


SCHEMA = 1


def stable_json(data: Any) -> str:
    return json.dumps(data, sort_keys=True, separators=(",", ":"))


def stable_sha256(data: Any) -> str:
    return "sha256:" + hashlib.sha256(stable_json(data).encode("utf-8")).hexdigest()


def parse_feeds_conf(text: str) -> list[dict[str, str]]:
    feeds: list[dict[str, str]] = []
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        try:
            parts = shlex.split(line, comments=False, posix=True)
        except ValueError as exc:
            raise ValueError(f"invalid feeds.conf line: {raw_line!r}: {exc}") from exc
        if len(parts) < 3:
            continue
        method, name, location = parts[:3]
        if not method.startswith("src-git"):
            continue
        url, sep, ref = location.partition(";")
        feeds.append(
            {
                "method": method,
                "name": name,
                "url": url,
                "ref": ref if sep else "HEAD",
            }
        )
    return feeds


def _run_git_ls_remote(url: str, ref: str) -> str:
    candidates = [ref]
    if ref != "HEAD" and not ref.startswith("refs/"):
        candidates.extend([f"refs/heads/{ref}", f"refs/tags/{ref}"])

    last_error = ""
    for candidate in candidates:
        proc = subprocess.run(
            ["git", "ls-remote", url, candidate],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=120,
        )
        if proc.returncode == 0 and proc.stdout.strip():
            return proc.stdout.splitlines()[0].split()[0]
        last_error = (proc.stderr or proc.stdout).strip()
    raise RuntimeError(f"could not resolve {url} {ref}: {last_error}")


def resolve_feeds(feeds: list[dict[str, str]], offline: bool = False) -> list[dict[str, str]]:
    resolved = []
    for feed in feeds:
        item = dict(feed)
        if offline:
            item["sha"] = "offline"
        else:
            item["sha"] = _run_git_ls_remote(item["url"], item["ref"])
        resolved.append(item)
    return resolved


def write_github_output(values: dict[str, str]) -> None:
    output = os.environ.get("GITHUB_OUTPUT")
    if not output:
        return
    with open(output, "a", encoding="utf-8") as fh:
        for key, value in values.items():
            fh.write(f"{key}={value}\n")


def build_lock(feeds_conf: pathlib.Path, offline: bool = False) -> dict[str, Any]:
    feeds = parse_feeds_conf(feeds_conf.read_text(encoding="utf-8"))
    return {"schema": SCHEMA, "feeds": resolve_feeds(feeds, offline=offline)}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--feeds-conf", default="feeds.conf", type=pathlib.Path)
    parser.add_argument("--output", default=".ci/feed-lock.json", type=pathlib.Path)
    parser.add_argument("--offline", action="store_true", help="Do not contact remotes; useful for local syntax tests")
    args = parser.parse_args(argv)

    lock = build_lock(args.feeds_conf, offline=args.offline)
    lock_sha = stable_sha256(lock)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(lock, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    sha_path = args.output.with_suffix(args.output.suffix + ".sha256")
    sha_path.write_text(lock_sha + "\n", encoding="utf-8")
    write_github_output({"feed_lock_sha": lock_sha, "feed_count": str(len(lock["feeds"]))})
    print(json.dumps({"feed_lock_sha": lock_sha, "feed_count": len(lock["feeds"]), "output": str(args.output)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
