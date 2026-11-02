#!/usr/bin/env python3
"""Validate upstream storage sources and separately recorded local migration code."""

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "patches" / "flutter_secure_storage"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    baseline = json.loads((PATCH / "UPSTREAM_SHA256.json").read_text())
    reviewed = json.loads((PATCH / "PATCHES.json").read_text())
    if baseline["version"] != "11.2.0" or reviewed["upstream_version"] != "11.2.0":
        raise ValueError("Unexpected storage upstream version")
    upstream = baseline["sha256"]
    changes = reviewed["files"]
    original = changed = local = 0
    for relative, expected in upstream.items():
        actual = digest(PATCH / relative)
        review = changes.get(relative)
        if review is None:
            if actual != expected:
                raise ValueError(f"Unreviewed storage upstream change: {relative}")
            original += 1
        else:
            if review["upstream_sha256"] != expected or not review.get("reason"):
                raise ValueError(f"Invalid storage patch provenance: {relative}")
            if actual != review["patched_sha256"]:
                raise ValueError(f"Storage patch hash mismatch: {relative}")
            changed += 1
    for relative, review in changes.items():
        if relative in upstream:
            continue
        if review["upstream_sha256"] is not None or not review.get("reason"):
            raise ValueError(f"Local storage file has false upstream provenance: {relative}")
        if digest(PATCH / relative) != review["patched_sha256"]:
            raise ValueError(f"Local storage file hash mismatch: {relative}")
        local += 1
    actual_runtime = {
        path.relative_to(PATCH).as_posix()
        for folder in ("lib", "android/src/main")
        for path in (PATCH / folder).rglob("*")
        if path.is_file()
    }
    expected_runtime = {
        name for name in set(upstream) | set(changes)
        if name.startswith(("lib/", "android/src/main/"))
    }
    if actual_runtime != expected_runtime:
        raise ValueError("Storage runtime file set differs from reviewed provenance")
    print(f"flutter_secure_storage 11.2.0: {original} upstream files, "
          f"{changed} reviewed changes, {local} separately recorded local files")


if __name__ == "__main__":
    main()
