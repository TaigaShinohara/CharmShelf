#!/usr/bin/env python3
"""Run production notification callback logic against synthetic native adapters.

No Apple permission service, application data, simulator, or authorization UI is
used. A main-queue callback must not be awaited synchronously by the strategy.
The retained upstream XCTest separately exercises the real Flutter plugin path.
"""

from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess
import sys
import tempfile


PACKAGE = Path(__file__).resolve().parents[1]
ROOT = PACKAGE.parents[1]


def main() -> None:
    if sys.platform != "darwin":
        raise SystemExit("This native callback check requires macOS")
    sys.path.insert(0, str(ROOT / "scripts/maintenance"))
    from check_local_auth_swift_compatibility import check_resources

    check_resources()
    native = PACKAGE / "ios/permission_handler_apple/Sources/permission_handler_apple"
    fixtures = PACKAGE / "test/native"
    inputs = sorted(set(native.rglob("*.h")) | {
        native / "strategies/NotificationPermissionStrategy.m",
        fixtures / "notification_callbacks.m",
    } | set((fixtures / "include").rglob("*.h")))
    before = {path: hashlib.sha256(path.read_bytes()).hexdigest() for path in inputs}
    clang = subprocess.check_output(["xcrun", "--find", "clang"], text=True).strip()
    apple_sdk = subprocess.check_output(
        ["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True
    ).strip()
    with tempfile.TemporaryDirectory(prefix="tagshelf-notification-callbacks-") as directory:
        executable = Path(directory) / "notification_callbacks"
        subprocess.run([
            clang, "-fobjc-arc", "-fblocks", "-Werror", "-framework", "Foundation",
            "-framework", "CoreFoundation", "-isysroot", apple_sdk,
            "-DPERMISSION_NOTIFICATIONS=1", "-I", str(fixtures / "include"),
            "-I", str(native), "-I", str(native / "strategies"),
            str(native / "strategies/NotificationPermissionStrategy.m"),
            str(fixtures / "notification_callbacks.m"), "-o", str(executable),
        ], check=True)
        subprocess.run([str(executable)], check=True, timeout=20)
    after = {path: hashlib.sha256(path.read_bytes()).hexdigest() for path in inputs}
    if after != before:
        raise RuntimeError("Production or test source changed during verification")
    print("Original source SHA-256 guard: unchanged")


if __name__ == "__main__":
    main()
