#!/usr/bin/env python3
"""Compile the local-auth fork against real Flutter frameworks without running an app.

iOS checks use the package's minimum deployment target. macOS checks run the
upstream Swift Testing suite with stub authentication contexts in a temporary,
dependency-free SwiftPM package. Original sources and SDK caches are never edited.
Run through scripts/quiet_check.sh because compiler/test output can be verbose.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[2]
PLUGIN = ROOT / "patches/local_auth_darwin/darwin"
NATIVE = PLUGIN / "local_auth_darwin/Sources/local_auth_darwin"
MANIFEST = PLUGIN / "local_auth_darwin/Package.swift"
NATIVE_NAMES = ("LocalAuthPlugin.swift", "SystemWrappers.swift", "messages.g.swift")
MIN_FREE_BYTES = 5 * 1024**3


def output(message: str) -> None:
    print(message, flush=True)


def capture(command: list[str]) -> str:
    return subprocess.run(command, check=True, text=True, capture_output=True).stdout.strip()


def check_resources() -> None:
    """Refuse overlapping builds; never print process arguments or environment."""
    active: list[tuple[int, str]] = []
    # Query names first. Arguments are only inspected, without printing, for the
    # shared Java/Dart executables whose idle daemons/editors are not builds.
    for line in capture(["ps", "-axo", "pid=,comm="]).splitlines():
        parts = line.strip().split(maxsplit=1)
        if len(parts) != 2:
            continue
        pid, executable = int(parts[0]), Path(parts[1]).name
        lower = executable.lower()
        building = (
            lower in {"swift", "swiftc", "swift-frontend", "swift-build", "swift-test",
                      "xcodebuild", "xctest", "flutter_tester", "clang", "clang++", "ld",
                      "gradle", "gradlew", "kotlinc"}
            or lower.endswith(".xctest")
        )
        if lower in {"java", "dart", "dartaotruntime"}:
            # Processes can exit between ps calls; that is not a preflight error.
            query = subprocess.run(
                ["ps", "-p", str(pid), "-o", "args="], text=True, capture_output=True
            )
            arguments = query.stdout
            if lower == "java":
                building = any(token in arguments for token in (
                    "org.gradle.wrapper.GradleWrapperMain",
                    "org.gradle.launcher.GradleMain",
                    "org.gradle.launcher.bootstrap.GradleMain",
                    "org.gradle.process.internal.worker.GradleWorkerMain",
                ))
            else:
                building = (
                    ("flutter_tools.snapshot" in arguments
                     and re.search(r"\b(build|test|run|drive)\b", arguments) is not None)
                    or "frontend_server" in arguments
                    or "test.dart.snapshot" in arguments
                    or "build_runner" in arguments
                )
        if building:
            active.append((pid, executable))
    if active:
        for pid, name in active:
            output(f"Active build/test: pid={pid}, name={name}")
        raise RuntimeError("Another build/test is active; retry after it finishes")
    output("Active build/test: none detected")

    pressure = capture(["/usr/bin/memory_pressure", "-Q"])
    match = re.search(r"System-wide memory free percentage:\s*(\d+)%", pressure)
    if match is None:
        raise RuntimeError("Cannot determine available memory from memory_pressure -Q")
    free_percent = int(match.group(1))
    output(f"System-wide memory free: {free_percent}%")
    if free_percent < 20:
        raise RuntimeError("Less than 20% system memory is free")
    for path in (ROOT, Path(tempfile.gettempdir())):
        free = shutil.disk_usage(path).free
        output(f"Disk free at {path}: {free / 1024**3:.1f} GiB")
        if free < MIN_FREE_BYTES:
            raise RuntimeError(f"Less than 5 GiB free at {path}")


def source_hashes(paths: list[Path]) -> dict[str, str]:
    return {
        str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in paths
    }


def input_files() -> list[Path]:
    native = sorted(NATIVE.glob("*.swift"))
    if {path.name for path in native} != set(NATIVE_NAMES):
        raise RuntimeError("Expected exactly the three reviewed local_auth_darwin Swift sources")
    tests = sorted((PLUGIN / "Tests").glob("*.swift"))
    if not tests:
        raise RuntimeError("No upstream local_auth_darwin Swift tests found")
    manifest = MANIFEST.read_text()
    for required in ('// swift-tools-version: 5.9', '.iOS("13.0")', '.macOS("10.15")'):
        if required not in manifest:
            raise RuntimeError(f"Production SwiftPM compatibility baseline changed: {required}")
    return [MANIFEST, *native, *tests]


def copy_sources(work: Path, paths: list[Path]) -> None:
    for path in paths:
        if path == MANIFEST:
            continue
        directory = "Tests/local_auth_darwinTests" if path.parent.name == "Tests" else "Sources/local_auth_darwin"
        copied = work / directory / path.name
        copied.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, copied)
        if path.read_bytes() != copied.read_bytes():
            raise RuntimeError(f"Source copy differs: {path.relative_to(ROOT)}")


def validate_flutter(sdk: Path) -> None:
    version_file = sdk / "bin/cache/flutter.version.json"
    if not version_file.is_file():
        raise RuntimeError("Flutter cache metadata is missing; prepare the fixed SDK first")
    version = json.loads(version_file.read_text()).get("frameworkVersion")
    if version != "3.47.8":
        raise RuntimeError(f"Expected Flutter 3.47.8, found {version!r}")
    output(f"Flutter framework: {version}")


def ios_compile(sdk: Path, work: Path, version: str, environment: dict[str, str]) -> None:
    framework = sdk / "bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64/Flutter.framework"
    if not framework.is_dir():
        raise RuntimeError("Flutter iOS framework is not cached; no automatic download is attempted")
    apple_sdk = capture(["xcrun", "--sdk", "iphoneos", "--show-sdk-path"])
    compiler = capture(["xcrun", "--find", "swiftc"])
    command = [
        compiler, "-emit-object", "-whole-module-optimization", "-parse-as-library",
        "-module-name", "local_auth_darwin", "-o", str(work / "local_auth_darwin.o"),
        "-swift-version", version, "-strict-concurrency=complete", "-warnings-as-errors",
        "-target", "arm64-apple-ios13.0", "-sdk", apple_sdk,
        "-F", str(framework.parent), "-module-cache-path", str(work / "module-cache"),
        *(str(work / "Sources/local_auth_darwin" / name) for name in NATIVE_NAMES),
    ]
    output(f"iOS 13.0 strict object compilation, Swift {version}, real cached Flutter framework")
    subprocess.run(command, check=True, cwd=ROOT, env=environment)


def macos_tests(sdk: Path, work: Path, version: str, environment: dict[str, str]) -> None:
    framework = sdk / "bin/cache/artifacts/engine/darwin-x64/FlutterMacOS.xcframework/macos-arm64_x86_64/FlutterMacOS.framework"
    if not framework.is_dir():
        raise RuntimeError("Flutter macOS universal framework is not cached; no automatic download is attempted")
    # JSON string encoding also gives a quoted Swift string for these filesystem
    # paths; ensure_ascii=False avoids JSON-only \uXXXX Unicode escape syntax.
    framework_dir = json.dumps(str(framework.parent), ensure_ascii=False)
    module_cache = json.dumps(str(work / "module-cache"), ensure_ascii=False)
    manifest = f'''// swift-tools-version: 5.9
import PackageDescription

let strict: [SwiftSetting] = [.unsafeFlags([
  "-F", {framework_dir}, "-strict-concurrency=complete", "-warnings-as-errors",
  "-module-cache-path", {module_cache}
])]
let flutter: [LinkerSetting] = [
  .linkedFramework("FlutterMacOS"),
  .unsafeFlags(["-F", {framework_dir}, "-Xlinker", "-rpath", "-Xlinker", {framework_dir}])
]
let package = Package(
  name: "LocalAuthSwiftCompatibility",
  platforms: [.macOS("10.15")],
  products: [],
  dependencies: [],
  targets: [
    .target(name: "local_auth_darwin", swiftSettings: strict, linkerSettings: flutter),
    .testTarget(name: "local_auth_darwinTests", dependencies: ["local_auth_darwin"],
                swiftSettings: strict, linkerSettings: flutter)
  ],
  swiftLanguageVersions: [.version("{version}")]
)
'''
    (work / "Package.swift").write_text(manifest)
    output(f"macOS Swift Testing (manifest minimum 10.15), Swift {version}, jobs=2, no package dependencies")
    subprocess.run([
        "xcrun", "swift", "test", "--package-path", str(work), "--jobs", "2",
        "-Xswiftc", "-j2",
    ], check=True, cwd=ROOT, env=environment)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--flutter-sdk", type=Path, required=True)
    parser.add_argument("--mode", choices=("compile-ios", "test-macos"), required=True)
    parser.add_argument("--swift-version", choices=("5", "6"), required=True)
    args = parser.parse_args()
    if sys.platform != "darwin":
        parser.error("This check requires macOS and the installed Apple SDKs")
    sdk = args.flutter_sdk.expanduser().resolve()
    validate_flutter(sdk)
    check_resources()
    paths = input_files()
    before = source_hashes(paths)
    parent = ROOT / ".dart_tool/local_auth_swift_compatibility"
    parent.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix=f"{args.mode}-swift{args.swift_version}-", dir=parent))
    output(f"Isolated check directory: {work.relative_to(ROOT)}")
    environment = os.environ.copy()
    environment["CLANG_MODULE_CACHE_PATH"] = str(work / "module-cache")
    environment["SWIFTPM_MODULECACHE_OVERRIDE"] = str(work / "manifest-module-cache")
    try:
        copy_sources(work, paths)
        (work / "source_hashes.json").write_text(json.dumps(before, indent=2) + "\n")
        if args.mode == "compile-ios":
            ios_compile(sdk, work, args.swift_version, environment)
        else:
            macos_tests(sdk, work, args.swift_version, environment)
    finally:
        after_paths = input_files()
        if after_paths != paths or source_hashes(after_paths) != before:
            raise RuntimeError("Original local_auth_darwin sources changed during verification")
        output(f"Original source SHA-256 guard: {len(paths)} files unchanged")
    output(f"PASS: {args.mode}, Swift {args.swift_version}")


if __name__ == "__main__":
    main()
