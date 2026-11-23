#!/usr/bin/env python3
"""Normalize invalid empty API arrays in unsigned iOS SDK resource bundles."""

import argparse
from pathlib import Path
import plistlib
import stat
import sys
import tempfile

ACCESSED_TYPES = "NSPrivacyAccessedAPITypes"


def normalize(archive: Path) -> list[str]:
    app = archive / "Products/Applications/Runner.app"
    if not archive.is_dir() or archive.suffix != ".xcarchive" or not app.is_dir():
        raise ValueError("Expected Runner.app in an Xcode archive.")
    if archive.resolve() not in app.resolve().parents:
        raise ValueError("Runner.app must be inside the archive.")
    if (app / "_CodeSignature").exists():
        raise ValueError("The app bundle is signed. Normalize a fresh unsigned archive.")

    changes = []
    for manifest in sorted(app.glob("*.bundle/PrivacyInfo.xcprivacy")):
        bundle = manifest.parent
        if bundle.is_symlink() or manifest.is_symlink():
            raise ValueError(f"Unexpected linked SDK privacy manifest: {bundle.name}")
        raw = manifest.read_bytes()
        values = plistlib.loads(raw)
        if not isinstance(values, dict):
            raise ValueError(f"Invalid SDK privacy manifest root: {bundle.name}")
        if values.get(ACCESSED_TYPES) != []:
            continue
        if (bundle / "_CodeSignature").exists():
            raise ValueError(f"SDK resource bundle is signed: {bundle.name}")
        info = plistlib.loads((bundle / "Info.plist").read_bytes())
        if info.get("CFBundlePackageType") != "BNDL" or info.get("CFBundleExecutable"):
            raise ValueError(f"Expected a resource-only bundle: {bundle.name}")
        del values[ACCESSED_TYPES]
        fmt = plistlib.FMT_BINARY if raw.startswith(b"bplist00") else plistlib.FMT_XML
        changes.append((manifest, plistlib.dumps(values, fmt=fmt, sort_keys=False)))

    for path, data in changes:
        with tempfile.TemporaryDirectory(dir=path.parent) as temp:
            replacement = Path(temp) / path.name
            replacement.write_bytes(data)
            replacement.chmod(stat.S_IMODE(path.stat().st_mode))
            replacement.replace(path)

    return [str(path.relative_to(app)) for path, _ in changes]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()
    try:
        changed = normalize(args.archive)
    except (ValueError, OSError, TypeError, plistlib.InvalidFileException) as exc:
        print(f"Privacy manifest normalization failed: {exc}", file=sys.stderr)
        return 1
    for path in changed:
        print(f"Removed empty {ACCESSED_TYPES}: {path}")
    print(f"Normalized {len(changed)} SDK privacy manifests before export.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
