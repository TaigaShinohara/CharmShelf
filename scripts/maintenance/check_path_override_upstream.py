#!/usr/bin/env python3
"""主要path overrideの上流一致または理由付き移植の実装ハッシュを検査する。"""

import hashlib
import json
from pathlib import Path

from check_flutter_secure_storage_patch import main as check_secure_storage_patch

ROOT = Path(__file__).resolve().parents[2]
BASELINE = Path(__file__).with_name("path_override_upstream_hashes.json")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def implementation_files(root: Path, roots: list[str] | None = None) -> set[str]:
    files: set[str] = set()
    for relative_root in map(Path, roots or ["android/src/main", "lib"]):
        directory = root / relative_root
        if directory.is_file():
            files.add(directory.relative_to(root).as_posix())
            continue
        files.update(
            path.relative_to(root).as_posix()
            for path in directory.rglob("*")
            # SwiftPM manifest検査で生成されるcacheは原版source集合に含めない。
            if path.is_file() and ".build" not in path.relative_to(root).parts
        )
    return files


def main() -> None:
    baseline = json.loads(BASELINE.read_text())
    for package, metadata in baseline.items():
        root = ROOT / "patches" / package
        expected = metadata["files"]
        patched = metadata.get("patched_files", {})
        added = metadata.get("new_files", {})
        overlap = set(expected) & set(added)
        if overlap:
            raise ValueError(f"{package} added files overlap upstream baseline: {sorted(overlap)}")
        for relative, addition in added.items():
            if not addition.get("reason") or not addition.get("sha256"):
                raise ValueError(f"{package} added file requires reason and sha256: {relative}")
        for relative, patch in patched.items():
            if relative not in expected or patch["upstream_sha256"] != expected[relative]:
                raise ValueError(f"{package} invalid upstream baseline for patch: {relative}")
            if not patch.get("reason"):
                raise ValueError(f"{package} missing patch reason: {relative}")
        actual_files = implementation_files(root, metadata.get("implementation_roots"))
        declared_files = set(expected) | set(added)
        if actual_files != declared_files:
            missing = sorted(declared_files - actual_files)
            extra = sorted(actual_files - declared_files)
            raise ValueError(f"{package} file set changed: missing={missing}, extra={extra}")
        mismatches = [
            relative
            for relative, expected_hash in expected.items()
            if digest(root / relative)
            != patched.get(relative, {}).get("patched_sha256", expected_hash)
        ]
        if mismatches:
            raise ValueError(f"{package} implementation hash mismatch ({metadata['version']}): {mismatches}")
        added_mismatches = [
            relative for relative, addition in added.items()
            if digest(root / relative) != addition["sha256"]
        ]
        if added_mismatches:
            raise ValueError(f"{package} added file hash mismatch: {added_mismatches}")
        print(
            f"{package} {metadata['version']}: "
            f"upstream match ({len(expected) - len(patched)} files), "
            f"reviewed patches ({len(patched)} files), "
            f"local additions ({len(added)} files)"
        )
    check_secure_storage_patch()


if __name__ == "__main__":
    main()
