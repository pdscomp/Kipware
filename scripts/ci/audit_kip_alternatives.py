#!/usr/bin/env python3
"""Audit Kipware .ipk packages for stale /opt paths.

Kipware packages are installed under /kip. Entware packages can silently retain
/opt in opkg Alternatives, conffiles, maintainer scripts, or archive paths. This
script fails kip builds before publishing such packages.
"""

from __future__ import annotations

import argparse
import io
import re
import sys
import tarfile
from dataclasses import dataclass
from pathlib import Path

AR_MAGIC = b"!<arch>\n"
ALT_RE = re.compile(r"(?P<priority>\d+):(?P<link>[^:\s,]+):(?P<target>[^\s,]+)")


@dataclass(frozen=True)
class ArMember:
    name: str
    data: bytes


@dataclass(frozen=True)
class Alternative:
    priority: int
    link: str
    target: str


def read_ipk_members(path: Path) -> dict[str, bytes]:
    data = path.read_bytes()
    if data.startswith(AR_MAGIC):
        pos = len(AR_MAGIC)
        members: dict[str, bytes] = {}
        while pos < len(data):
            if pos + 60 > len(data):
                raise ValueError(f"{path}: truncated ar header at byte {pos}")
            header = data[pos : pos + 60]
            pos += 60
            raw_name = header[0:16].decode("utf-8", "replace").strip()
            if raw_name.endswith("/"):
                raw_name = raw_name[:-1]
            try:
                size = int(header[48:58].decode("ascii").strip())
            except ValueError as exc:
                raise ValueError(f"{path}: invalid ar member size for {raw_name!r}") from exc
            payload = data[pos : pos + size]
            if len(payload) != size:
                raise ValueError(f"{path}: truncated ar member {raw_name!r}")
            pos += size
            if pos % 2:
                pos += 1
            members[raw_name] = payload
        return members

    # Entware/OpenWrt .ipk files may also be gzip-compressed tar archives
    # containing debian-binary, control.tar.*, and data.tar.* directly.
    members = {}
    try:
        with tarfile.open(name=str(path), mode="r:*") as tf:
            for member in tf.getmembers():
                if not member.isfile():
                    continue
                extracted = tf.extractfile(member)
                if extracted is None:
                    continue
                members[Path(member.name).name] = extracted.read()
    except tarfile.TarError as exc:
        raise ValueError(f"{path}: not an ar or tar .ipk archive") from exc
    return members


def open_tar_bytes(name: str, payload: bytes) -> tarfile.TarFile:
    # tarfile auto-detects gzip/xz/bzip2 with mode r:*.
    return tarfile.open(name=name, mode="r:*", fileobj=io.BytesIO(payload))


def find_member(members: dict[str, bytes], prefix: str) -> tuple[str, bytes] | None:
    for name, payload in members.items():
        if name.startswith(prefix):
            return name, payload
    return None


def parse_control_fields(control_text: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    current_key: str | None = None
    for line in control_text.splitlines():
        if not line:
            current_key = None
            continue
        if line[0].isspace() and current_key:
            fields[current_key] += " " + line.strip()
            continue
        if ":" not in line:
            current_key = None
            continue
        key, value = line.split(":", 1)
        current_key = key
        fields[key] = value.strip()
    return fields


def read_control(ipk: Path) -> dict[str, str]:
    members = read_ipk_members(ipk)
    control_member = find_member(members, "control.tar")
    if control_member is None:
        raise ValueError(f"{ipk}: missing control.tar.* member")
    name, payload = control_member
    with open_tar_bytes(name, payload) as tf:
        for member in tf.getmembers():
            if Path(member.name).name == "control":
                extracted = tf.extractfile(member)
                if extracted is None:
                    raise ValueError(f"{ipk}: control member is not a file")
                return parse_control_fields(extracted.read().decode("utf-8", "replace"))
    raise ValueError(f"{ipk}: missing ./control inside {name}")


def control_text_members(ipk: Path) -> dict[str, str]:
    members = read_ipk_members(ipk)
    control_member = find_member(members, "control.tar")
    if control_member is None:
        raise ValueError(f"{ipk}: missing control.tar.* member")
    name, payload = control_member
    out: dict[str, str] = {}
    with open_tar_bytes(name, payload) as tf:
        for member in tf.getmembers():
            if not member.isfile():
                continue
            extracted = tf.extractfile(member)
            if extracted is None:
                continue
            data = extracted.read()
            try:
                out[member.name] = data.decode("utf-8")
            except UnicodeDecodeError:
                out[member.name] = data.decode("utf-8", "replace")
    return out


def data_paths(ipk: Path) -> set[str]:
    members = read_ipk_members(ipk)
    data_member = find_member(members, "data.tar")
    if data_member is None:
        return set()
    name, payload = data_member
    paths: set[str] = set()
    with open_tar_bytes(name, payload) as tf:
        for member in tf.getmembers():
            normalized = member.name.removeprefix("./")
            paths.add("/" + normalized.lstrip("/"))
    return paths


def parse_alternatives(raw: str) -> list[Alternative]:
    alternatives: list[Alternative] = []
    for match in ALT_RE.finditer(raw):
        alternatives.append(
            Alternative(
                priority=int(match.group("priority")),
                link=match.group("link"),
                target=match.group("target"),
            )
        )
    return alternatives


def audit_ipk(
    ipk: Path,
    require_target_payload: bool,
    forbid_opt: bool,
    forbid_opt_payload_paths: bool,
) -> list[str]:
    errors: list[str] = []
    fields = read_control(ipk)
    raw = fields.get("Alternatives", "")
    package = fields.get("Package", ipk.name)
    payload_paths = data_paths(ipk) if (require_target_payload or forbid_opt_payload_paths) else set()

    if forbid_opt:
        for name, text in control_text_members(ipk).items():
            if "/opt" in text:
                errors.append(f"{package}: stale /opt reference in control member {name}")
    if forbid_opt_payload_paths:
        for path in sorted(payload_paths):
            if path == "/opt" or path.startswith("/opt/"):
                errors.append(f"{package}: stale /opt payload path: {path}")

    if not raw:
        return errors

    alternatives = parse_alternatives(raw)
    if not alternatives:
        errors.append(f"{package}: Alternatives field exists but could not be parsed: {raw!r}")
        return errors

    for alt in alternatives:
        for label, value in (("link", alt.link), ("target", alt.target)):
            if "/opt/" in value or value == "/opt":
                errors.append(
                    f"{package}: stale /opt alternative {label}: "
                    f"{alt.priority}:{alt.link}:{alt.target}"
                )
            if value.startswith("/") and not value.startswith("/kip/"):
                errors.append(
                    f"{package}: Kipware alternative {label} must be under /kip: "
                    f"{alt.priority}:{alt.link}:{alt.target}"
                )
        if require_target_payload and alt.target.startswith("/kip/") and alt.target not in payload_paths:
            errors.append(
                f"{package}: alternative target is not present in package payload: "
                f"{alt.target} ({alt.priority}:{alt.link}:{alt.target})"
            )
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--packages-dir",
        required=True,
        type=Path,
        help="Directory containing built .ipk files",
    )
    parser.add_argument(
        "--require-target-payload",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Require each alternative target to exist in the same .ipk payload (default: true)",
    )
    parser.add_argument(
        "--forbid-opt",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Fail on /opt references in control metadata or maintainer scripts (default: true)",
    )
    parser.add_argument(
        "--forbid-opt-payload-paths",
        action=argparse.BooleanOptionalAction,
        default=False,
        help="Also fail on /opt paths inside data.tar.* payload member names (default: false; useful for manual audits)",
    )
    args = parser.parse_args()

    if not args.packages_dir.is_dir():
        raise SystemExit(f"packages directory not found: {args.packages_dir}")

    ipks = sorted(args.packages_dir.glob("*.ipk"))
    if not ipks:
        raise SystemExit(f"no .ipk files found in {args.packages_dir}")

    all_errors: list[str] = []
    packages_with_alternatives = 0
    for ipk in ipks:
        fields = read_control(ipk)
        if fields.get("Alternatives"):
            packages_with_alternatives += 1
        all_errors.extend(
            audit_ipk(
                ipk,
                args.require_target_payload,
                args.forbid_opt,
                args.forbid_opt_payload_paths,
            )
        )

    if all_errors:
        print("Kipware package prefix audit failed:", file=sys.stderr)
        for error in all_errors:
            print(f"  - {error}", file=sys.stderr)
        print(
            "\nFix the package Makefile/local-patch so kip builds publish /kip paths, "
            "then rebuild before publishing the kip feed.",
            file=sys.stderr,
        )
        return 1

    print(
        f"Kipware package prefix audit passed: {len(ipks)} packages scanned, "
        f"{packages_with_alternatives} packages declare alternatives."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
