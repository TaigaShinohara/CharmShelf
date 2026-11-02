#!/usr/bin/env python3
"""Archiveの実物を検査する。署名・実機動作・ストア審査の代用ではない。"""

import argparse
import json
from pathlib import Path
import plistlib
import re
import subprocess
from urllib.parse import unquote, urljoin, urlparse


def read_strings(path: Path) -> dict:
    # Xcode compiles .strings into binary plists; sources use the text format.
    result = subprocess.run(
        ["plutil", "-convert", "json", "-o", "-", "--", str(path)],
        check=True, text=True, capture_output=True,
    )
    return json.loads(result.stdout)


def inspect_purpose_strings(app: Path, repo: Path, info: dict) -> list[str]:
    required = {
        "NSCameraUsageDescription", "NSMicrophoneUsageDescription",
        "NSPhotoLibraryUsageDescription",
        "NSPhotoLibraryAddUsageDescription", "NSFaceIDUsageDescription",
    }
    locales = ["en", "ja"]
    for locale in locales:
        relative = Path(f"{locale}.lproj/InfoPlist.strings")
        expected = read_strings(repo / "ios/Runner" / relative)
        bundled = read_strings(app / relative)
        if not required.issubset(expected) or any(
            not isinstance(expected[key], str) or not expected[key].strip()
            for key in required
        ):
            raise ValueError(f"Missing purpose strings in source: {locale}")
        if bundled != expected:
            raise ValueError(f"Bundled purpose strings differ from source: {locale}")
        if locale == "en" and any(info.get(key) != expected[key] for key in required):
            raise ValueError("Info.plist purpose strings must use the English fallback")
    if info.get("CFBundleDevelopmentRegion") != "en":
        raise ValueError("Expected English bundle development region")
    return locales


def inspect_app(app: Path) -> dict:
    repo = Path(__file__).resolve().parents[2]
    info = plistlib.loads((app / "Info.plist").read_bytes())
    if info["CFBundleIdentifier"] != "org.charmshelf.opensource":
        raise ValueError("Unexpected Bundle ID")
    sdk = re.fullmatch(r"iphoneos(\d+)(?:\.\d+)*", info["DTSDKName"])
    if not sdk or int(sdk[1]) < 26:
        raise ValueError("App Store requires iOS SDK 26 or later")
    for key in ("UIFileSharingEnabled", "LSSupportsOpeningDocumentsInPlace",
                "FlutterDeepLinkingEnabled"):
        if info.get(key) is not False:
            raise ValueError(f"Unexpected privacy/deep-link setting: {key}")
    purpose_string_locales = inspect_purpose_strings(app, repo, info)

    # 実際に解決済みのIsar Dartバインディングから、必要なFFI関数を列挙する。
    config_path = repo / ".dart_tool/package_config.json"
    config = json.loads(config_path.read_text())
    package = next(p for p in config["packages"] if p["name"] == "isar")
    package_uri = urljoin(config_path.as_uri(), package["rootUri"])
    parsed = urlparse(package_uri)
    if parsed.scheme != "file":
        raise ValueError("Isar must resolve to a local package")
    bindings = Path(unquote(parsed.path)) / "lib/src/native/bindings.dart"
    required = set(re.findall(r"['\"](isar_[a-zA-Z0-9_]+)['\"]", bindings.read_text()))
    if "isar_version" not in required:
        raise ValueError("Could not identify Isar FFI requirements")
    result = subprocess.run(
        ["nm", "-gU", str(app / info["CFBundleExecutable"])],
        check=True, text=True, capture_output=True,
    )
    exported = set(re.findall(r"\b_isar_[a-zA-Z0-9_]+\b", result.stdout))
    missing = sorted(name for name in required if "_" + name not in exported)
    if missing:
        raise ValueError("Missing Isar runtime symbols: " + ", ".join(missing))

    manifests = list(app.rglob("PrivacyInfo.xcprivacy"))
    if not (app / "PrivacyInfo.xcprivacy").is_file():
        raise ValueError("Missing app privacy manifest")
    for manifest in manifests:
        plistlib.loads(manifest.read_bytes())
    license_path = "assets/licenses/ios_native_licenses.json"
    bundled_licenses = json.loads(
        (app / "Frameworks/App.framework/flutter_assets" / license_path).read_text()
    )
    expected_licenses = json.loads((repo / license_path).read_text())
    if not expected_licenses or bundled_licenses != expected_licenses:
        raise ValueError("Bundled iOS native licenses do not match the reviewed asset")
    return {
        "version": info["CFBundleShortVersionString"],
        "build": info["CFBundleVersion"],
        "sdk": info["DTSDKName"],
        "bundle_id": info["CFBundleIdentifier"],
        "device_family": info["UIDeviceFamily"],
        "isar_symbols": len(required),
        "privacy_manifests": len(manifests),
        "native_license_entries": len(bundled_licenses),
        "purpose_string_locales": purpose_string_locales,
    }


def check_debug_symbols(archive: Path, app: Path, dsym_log: Path | None = None) -> None:
    # DWARF構造検査だけでは欠けたモジュールを検出できないため、生成ログも確認する。
    build_log = archive.parent / "archive.log"
    if dsym_log is not None:
        # 正常終了したCAS付き再生成ログ。元の一時的な生成結果と区別する。
        if not dsym_log.is_file():
            raise ValueError("dSYM再生成ログがありません")
        if re.search(r"(?im)^\s*(?:warning|error):", dsym_log.read_text(errors="replace")):
            raise ValueError("dSYM再生成に警告またはエラーがあります")
    elif build_log.is_file() and any(
        "warning:" in line and "llvmcas://" in line and "No such file or directory" in line
        for line in build_log.read_text(errors="replace").splitlines()
    ):
        raise ValueError("dSYMのキャッシュ参照が欠落しています。IPA書き出しを中止します。")
    symbol_pairs = [
        (app / "Runner", "Runner.app.dSYM"),
        (app / "Frameworks/App.framework/App", "App.framework.dSYM"),
    ]
    objc_binary = app / "Frameworks/objective_c.framework/objective_c"
    if objc_binary.is_file():
        symbol_pairs.append((objc_binary, "objective_c.framework.dSYM"))
    for binary, bundle in symbol_pairs:
        dsym = archive / "dSYMs" / bundle
        if not dsym.is_dir():
            raise ValueError(f"dSYMがありません: {bundle}")
        uuids = []
        for path in (binary, dsym):
            output = subprocess.run(
                ["xcrun", "dwarfdump", "--uuid", str(path)],
                check=True, text=True, capture_output=True,
            ).stdout
            uuids.append(set(re.findall(r"UUID: ([0-9A-Fa-f-]+) \(([^)]+)\)", output)))
        if not uuids[0] or uuids[0] != uuids[1]:
            raise ValueError(f"バイナリとdSYMのUUIDが一致しません: {bundle}")
        if bundle == "objective_c.framework.dSYM":
            # objective_c 9.3.0 produced a UUID-matching but empty dSYM.
            # UUID equality alone cannot prove crash symbolication works.
            debug_info = subprocess.run(
                ["xcrun", "dwarfdump", "--debug-info", str(dsym)],
                check=True, text=True, capture_output=True,
            ).stdout
            if "DW_TAG_compile_unit" not in debug_info:
                raise ValueError(f"dSYMにデバッグ情報がありません: {bundle}")
        # App.frameworkはキャッシュ無効候補でも範囲エラーが再現するため、
        # ここでの構造検査はネイティブRunnerに限定し、Dart側はUUIDを検査する。
        if bundle in ("Runner.app.dSYM", "objective_c.framework.dSYM"):
            subprocess.run(
                ["xcrun", "dwarfdump", "--verify", "--quiet", str(dsym)],
                check=True, text=True, capture_output=True,
            )


def check(archive: Path, dsym_log: Path | None = None) -> None:
    metadata = plistlib.loads((archive / "Info.plist").read_bytes())
    relative_app = metadata["ApplicationProperties"]["ApplicationPath"]
    result = inspect_app(archive / "Products" / relative_app)
    check_debug_symbols(archive, archive / "Products" / relative_app, dsym_log)
    print(f"Archive: {archive}")
    print(f"Version: {result['version']} ({result['build']})")
    print(f"SDK: {result['sdk']}; Isar symbols: {result['isar_symbols']} OK")
    print(f"Privacy manifests: {result['privacy_manifests']} parsed")
    print(f"Native licenses: {result['native_license_entries']} matched")
    print(f"Permission purpose strings: {', '.join(result['purpose_string_locales'])} matched")
    print("dSYM: Runner・App・同梱objective_cのUUID一致 / ネイティブDWARF検証OK")
    print("Archive structure: OK (signing and device QA are separate gates)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--dsym-log", type=Path, help="正常終了したCAS付きdSYM再生成のログ")
    args = parser.parse_args()
    try:
        check(args.archive.resolve(), args.dsym_log)
    except (ValueError, KeyError, OSError, StopIteration, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Archive check failed: {error}\n")
