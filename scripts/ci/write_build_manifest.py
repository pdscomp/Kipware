#!/usr/bin/env python3
"""Write published build and IPK manifests for the staged feed."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
from datetime import datetime, timezone
from typing import Any


SCHEMA = 1


def sha256_file(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def collect_outputs(feed_dir: pathlib.Path) -> dict[str, Any]:
    ipks = []
    for path in sorted(feed_dir.glob("*.ipk")):
        filename = path.name
        package_name = filename.split("_", 1)[0]
        ipks.append(
            {
                "filename": filename,
                "package": package_name,
                "size": path.stat().st_size,
                "sha256": sha256_file(path),
            }
        )

    outputs: dict[str, Any] = {
        "packages_count": len(ipks),
        "ipks": ipks,
        "ipk_manifest_sha256": "",
    }
    packages = feed_dir / "Packages"
    packages_gz = feed_dir / "Packages.gz"
    outputs["packages_sha256"] = sha256_file(packages) if packages.exists() else ""
    outputs["packages_gz_sha256"] = sha256_file(packages_gz) if packages_gz.exists() else ""
    outputs["ipk_manifest_sha256"] = "sha256:" + hashlib.sha256(
        json.dumps(ipks, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()
    return outputs


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--feed-dir", default="pages/armv7hf-k5.4", type=pathlib.Path)
    parser.add_argument("--fingerprint", default=".ci/build-fingerprint.json", type=pathlib.Path)
    parser.add_argument("--decision", default=".ci/build-decision.json", type=pathlib.Path)
    parser.add_argument("--manifest-output", default=None, type=pathlib.Path)
    parser.add_argument("--ipk-output", default=None, type=pathlib.Path)
    args = parser.parse_args(argv)

    fingerprint = json.loads(args.fingerprint.read_text(encoding="utf-8"))
    decision = json.loads(args.decision.read_text(encoding="utf-8")) if args.decision.exists() else {}
    outputs = collect_outputs(args.feed_dir)
    run_id = os.environ.get("GITHUB_RUN_ID", "")
    repo = os.environ.get("GITHUB_REPOSITORY", "")
    sha = os.environ.get("GITHUB_SHA", "")
    ref = os.environ.get("GITHUB_REF", "")
    manifest = {
        "schema": SCHEMA,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "github_run_id": run_id,
        "repo": {"owner_repo": repo, "sha": sha, "ref": ref},
        "decision": decision,
        **fingerprint,
        "outputs": {k: v for k, v in outputs.items() if k != "ipks"},
    }

    manifest_output = args.manifest_output or (args.feed_dir / "build-manifest.json")
    ipk_output = args.ipk_output or (args.feed_dir / "ipk-manifest.json")
    manifest_output.parent.mkdir(parents=True, exist_ok=True)
    manifest_output.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    ipk_output.write_text(json.dumps(outputs["ipks"], indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"manifest": str(manifest_output), "ipk_manifest": str(ipk_output), "packages_count": outputs["packages_count"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
