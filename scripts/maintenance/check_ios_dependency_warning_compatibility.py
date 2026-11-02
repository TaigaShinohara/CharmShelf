#!/usr/bin/env python3
"""Compile patched iOS dependencies at their minimum and app OS targets.

Uses real cached Flutter headers, complete Objective-C object compilation and
Swift 5 object generation with warnings as errors. No app or review UI is run.
Run sequentially through scripts/quiet_check.sh on macOS.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from check_local_auth_swift_compatibility import check_resources, validate_flutter


ROOT = Path(__file__).resolve().parents[2]
PACKAGES = {
    "permission_handler_apple": ("ios", "12.0"),
    "flutter_local_notifications": ("ios", "13.0"),
    "open_file_ios": ("ios", "13.0"),
    "device_info_plus": ("ios", "13.0"),
    "in_app_review": ("ios", "12.0"),
    "audio_session": ("ios", "12.0"),
}
OBJC = (
    ("permission_handler_apple", "strategies/PhonePermissionStrategy.m", ("12.0", "15.0")),
    ("permission_handler_apple", "strategies/NotificationPermissionStrategy.m", ("12.0", "15.0")),
    ("flutter_local_notifications", "FlutterLocalNotificationsPlugin.m", ("13.0", "14.0", "15.0")),
    ("open_file_ios", "OpenFilePlugin.m", ("13.0", "15.0")),
    ("device_info_plus", "FPPDeviceInfoPlusPlugin.m", ("13.0", "15.0")),
    ("audio_session", "DarwinAudioSession.m", ("12.0", "14.5", "15.0", "16.0")),
)


def capture(command: list[str]) -> str:
    return subprocess.run(command, check=True, text=True, capture_output=True).stdout.strip()


def hashes(paths: list[Path]) -> dict[str, str]:
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}


def inputs() -> list[Path]:
    paths: list[Path] = []
    for package, (platform, minimum) in PACKAGES.items():
        directory = ROOT / "patches" / package / platform / package
        manifest = directory / "Package.swift"
        if f'.iOS("{minimum}")' not in manifest.read_text():
            raise RuntimeError(f"{package}: production minimum OS declaration changed")
        paths.append(manifest)
        paths.extend(p for p in (directory / "Sources" / package).rglob("*") if p.is_file())
    return sorted(paths)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--flutter-sdk", type=Path, required=True)
    args = parser.parse_args()
    if sys.platform != "darwin":
        parser.error("This check requires macOS and the installed Apple SDKs")
    sdk = args.flutter_sdk.expanduser().resolve()
    validate_flutter(sdk)
    framework = sdk / "bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64/Flutter.framework"
    if not framework.is_dir():
        raise RuntimeError("Prepare the fixed SDK's iOS framework first; no automatic download")
    check_resources()
    paths = inputs()
    before = hashes(paths)
    parent = ROOT / ".dart_tool/ios_dependency_warning_compatibility"
    parent.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix="ios-", dir=parent))
    print(f"Isolated check directory: {work.relative_to(ROOT)}", flush=True)
    apple_sdk = capture(["xcrun", "--sdk", "iphoneos", "--show-sdk-path"])
    clang = capture(["xcrun", "--find", "clang"])
    swift = capture(["xcrun", "--find", "swiftc"])
    print(f"Apple SDK: {apple_sdk}", flush=True)
    print(capture([swift, "--version"]), flush=True)
    environment = os.environ.copy()
    environment["CLANG_MODULE_CACHE_PATH"] = str(work / "module-cache")
    try:
        for path in paths:
            copied = work / path.relative_to(ROOT / "patches")
            copied.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, copied)
            if copied.read_bytes() != path.read_bytes():
                raise RuntimeError(f"Source copy differs: {path}")
        (work / "source_hashes.json").write_text(json.dumps(before, indent=2) + "\n")
        for package, source, versions in OBJC:
            native = work / package / "ios" / package / "Sources" / package
            for minimum in versions:
                print(f"Compile: {package}/{source}, iOS {minimum}, warnings as errors", flush=True)
                subprocess.run([
                    clang, "-c", "-fobjc-arc", "-fmodules", "-fblocks", "-Werror",
                    "-Wshorten-64-to-32", "-target", f"arm64-apple-ios{minimum}",
                    "-isysroot", apple_sdk, "-F", str(framework.parent),
                    "-I", str(native), "-I", str(native / "strategies"),
                    "-I", str(native / "util"), "-I", str(native / "include" / package),
                    "-DPERMISSION_NOTIFICATIONS=1", "-DAUDIO_SESSION_MICROPHONE=0", str(native / source),
                    "-o", str(work / f"{package}-{Path(source).stem}-{minimum}.o"),
                ], check=True, cwd=ROOT, env=environment)
        native = work / "in_app_review/ios/in_app_review/Sources/in_app_review"
        for minimum in ("12.0", "15.0"):
            print(f"Compile: in_app_review, Swift 5, iOS {minimum}, warnings as errors", flush=True)
            subprocess.run([
                swift, "-emit-object", "-whole-module-optimization", "-parse-as-library",
                "-module-name", "in_app_review", "-swift-version", "5", "-warnings-as-errors",
                "-target", f"arm64-apple-ios{minimum}", "-sdk", apple_sdk,
                "-F", str(framework.parent), "-module-cache-path", str(work / "module-cache"),
                str(native / "InAppReviewPlugin.swift"), "-o", str(work / f"review-{minimum}.o"),
            ], check=True, cwd=ROOT, env=environment)
    finally:
        if inputs() != paths or hashes(paths) != before:
            raise RuntimeError("Original dependency sources changed during verification")
        print(f"Original source SHA-256 guard: {len(paths)} files unchanged", flush=True)
    print("PASS: 17 native object compilations, package minima and app iOS 15", flush=True)


if __name__ == "__main__":
    main()
