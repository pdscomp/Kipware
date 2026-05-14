#!/usr/bin/env python3
"""Generate Kipware release notes for date-tagged install image releases."""

from __future__ import annotations

import argparse
import os
import re
import subprocess
from pathlib import Path
from typing import Iterable

DATE_TAG_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def run_git(args: list[str], check: bool = True) -> str:
    result = subprocess.run(["git", *args], check=check, text=True, capture_output=True)
    return result.stdout.strip()


def ref_exists(ref: str) -> bool:
    return subprocess.run(["git", "rev-parse", "--verify", f"{ref}^{{commit}}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


def date_tags() -> list[str]:
    tags = run_git(["tag", "--list"], check=False).splitlines()
    return sorted(tag for tag in tags if DATE_TAG_RE.match(tag))


def previous_date_tag(current_tag: str) -> str | None:
    tags = [tag for tag in date_tags() if tag != current_tag]
    before_current = [tag for tag in tags if tag < current_tag]
    if before_current:
        return before_current[-1]
    return tags[-1] if tags else None


def git_file(ref: str | None, path: str) -> str:
    if ref:
        result = subprocess.run(["git", "show", f"{ref}:{path}"], text=True, capture_output=True)
        return result.stdout if result.returncode == 0 else ""
    p = Path(path)
    return p.read_text() if p.exists() else ""


def parse_package_manifest(text: str) -> set[str]:
    packages: set[str] = set()
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        packages.add(stripped)
    return packages


def parse_config_packages(text: str) -> set[str]:
    packages: set[str] = set()
    for line in text.splitlines():
        match = re.match(r"^CONFIG_PACKAGE_(.+)=m$", line.strip())
        if match:
            packages.add(match.group(1))
    return packages


def bullet_list(items: Iterable[str], empty: str = "None detected.") -> str:
    values = sorted(set(items))
    if not values:
        return f"- {empty}"
    return "\n".join(f"- `{item}`" for item in values)


def commit_lines(previous_tag: str | None, end_ref: str) -> list[str]:
    if previous_tag:
        rev_range = f"{previous_tag}..{end_ref}"
    else:
        rev_range = end_ref
    out = run_git(["log", "--oneline", "--no-merges", rev_range], check=False)
    return [line.strip() for line in out.splitlines() if line.strip()]


def target_summary(target_dir: Path) -> str:
    if not target_dir.exists():
        return "- No target configs found."
    lines: list[str] = []
    for env_file in sorted(target_dir.glob("*.env")):
        data: dict[str, str] = {}
        for line in env_file.read_text().splitlines():
            stripped = line.strip()
            if not stripped or stripped.startswith("#") or "=" not in stripped:
                continue
            key, value = stripped.split("=", 1)
            data[key] = value.strip().strip('"')
        tid = data.get("TARGET_ID", env_file.stem)
        display = data.get("TARGET_DISPLAY_NAME", tid)
        kip_target = data.get("KIP_TARGET", "unknown")
        lines.append(f"- **{display}** (`{tid}`): installs to `{kip_target}` and exposes `/kip` as a symlink.")
    return "\n".join(lines) if lines else "- No target configs found."


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", required=True, help="Release tag/date, e.g. 2026-05-14")
    parser.add_argument("--package-list", default="release/kipware-install-packages.txt")
    parser.add_argument("--target-dir", default="release/targets")
    parser.add_argument("--config", default="configs/armv7hf-5.4.config")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    if not DATE_TAG_RE.match(args.tag):
        raise SystemExit(f"tag must match YYYY-MM-DD: {args.tag}")

    end_ref = args.tag if ref_exists(args.tag) else "HEAD"
    prev_tag = previous_date_tag(args.tag)

    current_manifest = parse_package_manifest(git_file(None, args.package_list))
    previous_manifest = parse_package_manifest(git_file(prev_tag, args.package_list)) if prev_tag else set()
    added_image_packages = current_manifest - previous_manifest
    removed_image_packages = previous_manifest - current_manifest

    current_config = parse_config_packages(git_file(None, args.config))
    previous_config = parse_config_packages(git_file(prev_tag, args.config)) if prev_tag else set()
    added_feed_packages = current_config - previous_config
    removed_feed_packages = previous_config - current_config

    commits = commit_lines(prev_tag, end_ref)

    release_title = f"Kipware {args.tag}"
    previous_text = prev_tag or "the beginning of tracked release history"

    content = f"""# {release_title}

Kipware is an optimized port of Entware for armv7l 3D printers built around the Allwinner R528/T113 family, including Elegoo Centauri Carbon-class systems.

## Release assets

- `kipware-cc1-{args.tag}.tar.gz` — Elegoo Centauri Carbon 1 image (`/user-resource/.kipware` with `/kip` symlink)
- `kipware-cc2-{args.tag}.tar.gz` — Elegoo Centauri Carbon 2 image (`/opt/usr/.kipware` with `/kip` symlink)
- `kipware-install-images-{args.tag}.sha256` — SHA256 checksums for release tarballs

## Install image targets

{target_summary(Path(args.target_dir))}

Both stock target locations are expected to have roughly 6GB free. If installing manually on another armv7l platform, ensure the target partition has adequate free space; at least several hundred MB is recommended for the base package set, and more if installing additional packages.

## Manual install

Manual install is also supported using the generic installer:

https://pdscomp.github.io/Kipware/kip/armv7hf-k5.4/installer/generic.sh

For nonstandard layouts, create `/kip` as a symlink or bind mount to the desired install location before running `generic.sh`. On many embedded targets, installing `wget-ssl` and `ca-certificates` is necessary before `opkg` can fetch HTTPS package updates reliably.

## Changes since {previous_text}

### Install image package set

Added to image manifest:
{bullet_list(added_image_packages)}

Removed from image manifest:
{bullet_list(removed_image_packages)}

### Kipware feed package config

Added feed packages:
{bullet_list(added_feed_packages)}

Removed feed packages:
{bullet_list(removed_feed_packages)}

### Build/runtime changes

"""
    if commits:
        content += "\n".join(f"- {line}" for line in commits)
    else:
        content += "- None detected."

    content += """

## Known notes

- Do **not** add `/kip/lib` to global `LD_LIBRARY_PATH` on firmware environments with their own glibc loader. Use `/kip/bin` and `/kip/sbin` in `PATH`; Kipware packages carry their own interpreter/RPATH metadata.
- Release artifacts are already gzip-compressed tarballs; do not wrap them in zip files.
"""

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(content)
    print(f"Wrote {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
