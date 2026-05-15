#!/usr/bin/env python3
"""Compute a deterministic Kipware CI build fingerprint."""

from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import os
import pathlib
from typing import Any, Iterable


SCHEMA = 1
TARGET = {
    "board": "armv7-5.4",
    "cpu": "arm_cortex-a7+neon-vfpv4",
    "libc": "glibc-2.27",
    "gcc": "8.4.0",
}

CONFIG_PATTERNS = ["configs/armv7hf-5.4.config"]
FOUNDATION_PATTERNS = [
    ".github/workflows/build-armv7hf-5.4.yml",
    "bake_armv7hf.sh",
    "feeds.conf",
    "feeds.conf.default",
    "rules.mk",
    "include/**",
    "scripts/ci/**",
    "scripts/feeds",
    "toolchain/**",
]
GLOBAL_PACKAGING_PATTERNS = [
    "scripts/rstrip.sh",
    "scripts/stage-armv7hf-pages.sh",
    "scripts/ipkg-make-index.sh",
    "scripts/gen-index.py",
    "installers/**",
]
PACKAGE_INPUT_PATTERNS = [
    "configs/armv7hf-5.4.config",
    "package/**/Makefile",
    "local-patches/**",
]
OUTPUT_STAGING_PATTERNS = [
    "scripts/stage-armv7hf-pages.sh",
    "scripts/ipkg-make-index.sh",
    "scripts/gen-index.py",
    "installers/**",
]

EXCLUDE_DIRS = {".git", ".ccache", "build_dir", "staging_dir", "bin", "dl", "feeds", "tmp", "logs", "pages"}


def stable_json(data: Any) -> str:
    return json.dumps(data, sort_keys=True, separators=(",", ":"))


def stable_sha256(data: Any) -> str:
    return "sha256:" + hashlib.sha256(stable_json(data).encode("utf-8")).hexdigest()


def file_sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def _iter_files(root: pathlib.Path) -> Iterable[pathlib.Path]:
    for path in root.rglob("*"):
        if path.is_dir():
            continue
        rel_parts = path.relative_to(root).parts
        if any(part in EXCLUDE_DIRS for part in rel_parts):
            continue
        yield path


def _matches(rel: str, patterns: list[str]) -> bool:
    return any(fnmatch.fnmatch(rel, pat) for pat in patterns)


def hash_patterns(root: pathlib.Path, patterns: list[str]) -> dict[str, Any]:
    files = []
    for path in _iter_files(root):
        rel = path.relative_to(root).as_posix()
        if _matches(rel, patterns):
            files.append({"path": rel, "sha256": file_sha256(path)})
    files.sort(key=lambda item: item["path"])
    return {"sha256": stable_sha256(files), "files": files}


def prefix_for_branch(branch: str) -> str:
    return "/kip" if branch == "kip" else "/opt"


def compute_fingerprint(root: pathlib.Path, feed_lock: dict[str, Any], branch: str = "main") -> dict[str, Any]:
    root = root.resolve()
    components = {
        "feed_lock_sha": stable_sha256(feed_lock),
        "config_sha": hash_patterns(root, CONFIG_PATTERNS)["sha256"],
        "foundation_sha": hash_patterns(root, FOUNDATION_PATTERNS)["sha256"],
        "global_packaging_sha": hash_patterns(root, GLOBAL_PACKAGING_PATTERNS)["sha256"],
        "package_input_sha": hash_patterns(root, PACKAGE_INPUT_PATTERNS)["sha256"],
        "output_staging_sha": hash_patterns(root, OUTPUT_STAGING_PATTERNS)["sha256"],
    }
    # Host/toolchain caches should be conservative: config can affect target/toolchain selections.
    components["toolchain_cache_sha"] = stable_sha256(
        {
            "foundation_sha": components["foundation_sha"],
            "config_sha": components["config_sha"],
            "target": TARGET,
        }
    )
    fingerprint_input = {
        "schema": SCHEMA,
        "branch": branch,
        "target": {**TARGET, "prefix": prefix_for_branch(branch)},
        "components": components,
    }
    return {
        **fingerprint_input,
        "build_fingerprint": stable_sha256(fingerprint_input),
    }


def write_github_output(values: dict[str, str]) -> None:
    output = os.environ.get("GITHUB_OUTPUT")
    if not output:
        return
    with open(output, "a", encoding="utf-8") as fh:
        for key, value in values.items():
            fh.write(f"{key}={value}\n")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", type=pathlib.Path)
    parser.add_argument("--feed-lock", default=".ci/feed-lock.json", type=pathlib.Path)
    parser.add_argument("--branch", default=os.environ.get("GITHUB_REF_NAME", "main"))
    parser.add_argument("--output", default=".ci/build-fingerprint.json", type=pathlib.Path)
    args = parser.parse_args(argv)

    feed_lock = json.loads(args.feed_lock.read_text(encoding="utf-8"))
    fingerprint = compute_fingerprint(args.root, feed_lock, branch=args.branch)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(fingerprint, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    outputs = {
        "build_fingerprint": fingerprint["build_fingerprint"],
        "feed_lock_sha": fingerprint["components"]["feed_lock_sha"],
        "foundation_sha": fingerprint["components"]["foundation_sha"],
        "global_packaging_sha": fingerprint["components"]["global_packaging_sha"],
        "package_input_sha": fingerprint["components"]["package_input_sha"],
        "toolchain_cache_sha": fingerprint["components"]["toolchain_cache_sha"],
    }
    write_github_output(outputs)
    print(json.dumps(outputs, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
