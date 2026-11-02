#!/usr/bin/env python3
"""iOSがSwiftPM単独で全ネイティブプラグインを解決することを検査する。"""

import argparse
import json
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GENERATED = ROOT / "ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift"
RESOLVED_VERSIONS = {
    "libwebp-xcode": "1.5.0",
    "mantle": "2.2.0",
    "sdwebimage": "5.21.7",
}
CANONICAL_LOCKS = (
    ROOT / "ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved",
    ROOT / "ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved",
)


def check_resolved(path: Path) -> None:
    data = json.loads(path.read_text())
    pins = data.get("pins") or data.get("object", {}).get("pins", [])
    resolved = {}
    for pin in pins:
        identity = (pin.get("identity") or pin.get("package") or "").lower()
        resolved[identity] = pin.get("state", {}).get("version")
    if resolved != RESOLVED_VERSIONS:
        raise ValueError(f"Unexpected SwiftPM resolution: {resolved}")
    print(f"SwiftPM lock: {len(resolved)} remote packages pinned")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--resolved", type=Path, action="append", default=[])
    args = parser.parse_args()

    forbidden = [ROOT / "ios/Podfile", ROOT / "ios/Podfile.lock"]
    if any(path.exists() for path in forbidden):
        raise ValueError("CocoaPods files must not exist")
    for relative in (
        "ios/Runner.xcodeproj/project.pbxproj",
        "ios/Runner.xcworkspace/contents.xcworkspacedata",
        "ios/Flutter/Debug.xcconfig",
        "ios/Flutter/Release.xcconfig",
    ):
        text = (ROOT / relative).read_text()
        if any(token in text for token in ("Pods", "PODS_", "[CP]")):
            raise ValueError(f"CocoaPods reference remains: {relative}")

    dependencies = json.loads((ROOT / ".flutter-plugins-dependencies").read_text())
    if dependencies.get("swift_package_manager_enabled", {}).get("ios") is not True:
        raise ValueError("Flutter SwiftPM integration is not enabled for iOS")
    generated = GENERATED.read_text()
    manifests: set[Path] = set()
    native_plugins = 0
    for plugin in dependencies["plugins"]["ios"]:
        if not plugin.get("native_build"):
            continue
        native_plugins += 1
        platform = "darwin" if plugin.get("shared_darwin_source") else "ios"
        manifest = Path(plugin["path"]) / platform / plugin["name"] / "Package.swift"
        if not manifest.is_file():
            raise ValueError(f"Missing SwiftPM manifest: {plugin['name']}")
        if f'package(name: "{plugin["name"]}"' not in generated:
            raise ValueError(f"Generated SwiftPM package omits: {plugin['name']}")
        manifests.add(manifest)

    manifests.update((ROOT / "patches" / name / "Package.swift") for name in (
        "SDWebImageWebPCoder",
    ))
    module_cache = ROOT / "build/swiftpm-manifest-module-cache"
    module_cache.mkdir(parents=True, exist_ok=True)
    environment = os.environ.copy()
    environment["CLANG_MODULE_CACHE_PATH"] = str(module_cache)
    for manifest in sorted(manifests):
        subprocess.run(
            ["swift", "package", "dump-package", "--package-path", str(manifest.parent)],
            check=True,
            stdout=subprocess.DEVNULL,
            env=environment,
        )
    print(f"SwiftPM manifests: {len(manifests)} parsed; native plugins: {native_plugins}")
    locks = list(dict.fromkeys(path.resolve() for path in (*CANONICAL_LOCKS, *args.resolved)))
    lock_contents = []
    for lock in locks:
        if not lock.is_file():
            raise ValueError(f"Missing SwiftPM lock: {lock}")
        check_resolved(lock)
        lock_contents.append(json.loads(lock.read_text()))
    if any(lock != lock_contents[0] for lock in lock_contents[1:]):
        raise ValueError("SwiftPM lock files do not match")


if __name__ == "__main__":
    main()
