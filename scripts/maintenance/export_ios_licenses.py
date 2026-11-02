#!/usr/bin/env python3
"""SwiftPMで解決したiOS依存の許諾本文をアプリ内表示用に検査・出力する。"""

import argparse
import json
from pathlib import Path
from urllib.parse import unquote, urljoin, urlparse

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / "assets/licenses/ios_native_licenses.json"
LOCAL_SWIFT_PACKAGES = {
    "SDWebImageWebPCoder": ROOT / "patches/SDWebImageWebPCoder/LICENSE",
}
REMOTE_SWIFT_PACKAGES = {
    "Mantle": ("Mantle", ("LICENSE.md", "LICENSE")),
    "SDWebImage": ("SDWebImage", ("LICENSE",)),
    "libwebp": ("libwebp-Xcode", ("libwebp/COPYING", "COPYING", "LICENSE")),
}


def package_roots() -> dict[str, Path]:
    config_path = ROOT / ".dart_tool/package_config.json"
    config = json.loads(config_path.read_text())
    roots = {}
    for package in config["packages"]:
        parsed = urlparse(urljoin(config_path.as_uri(), package["rootUri"]))
        if parsed.scheme == "file":
            roots[package["name"]] = Path(unquote(parsed.path))
    return roots


def license_file(root: Path, candidates: tuple[str, ...] = ("LICENSE", "LICENSE.md")) -> Path:
    for candidate in candidates:
        path = root / candidate
        if path.is_file():
            return path
    raise FileNotFoundError(f"License file not found under {root}")


def create_entries(source_packages: Path) -> list[dict[str, str]]:
    dependencies = json.loads((ROOT / ".flutter-plugins-dependencies").read_text())
    plugin_names = {
        plugin["name"]
        for plugin in dependencies["plugins"]["ios"]
        if plugin.get("native_build")
    }
    roots = package_roots()
    sources: dict[str, Path] = {}
    for name in plugin_names:
        if name not in roots:
            raise ValueError(f"Resolved package missing: {name}")
        # Flutter 3.47 still links dev plugins on iOS (flutter/flutter#163874).
        # integration_test inherits the SDK license rather than shipping its own.
        sdk_root = roots["flutter"].parents[1] if "flutter" in roots else None
        if (name == "integration_test" and sdk_root is not None
                and roots[name].resolve() == (sdk_root / "packages/integration_test").resolve()):
            sources[name] = license_file(sdk_root)
        else:
            sources[name] = license_file(roots[name])
    sources.update(LOCAL_SWIFT_PACKAGES)
    for name, (checkout, candidates) in REMOTE_SWIFT_PACKAGES.items():
        sources[name] = license_file(source_packages / checkout, candidates)

    entries = [
        {"package": name, "text": sources[name].read_text()}
        for name in sorted(sources)
    ]
    if not entries or len({entry["package"] for entry in entries}) != len(entries):
        raise ValueError("ライセンス一覧が空か、パッケージ名が重複しています")
    return entries


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="同梱内容との一致だけを確認する")
    parser.add_argument("--source-packages", type=Path, required=True,
                        help="Xcode DerivedData内のSourcePackages/checkouts")
    args = parser.parse_args()
    entries = create_entries(args.source_packages)
    if args.check:
        if json.loads(TARGET.read_text()) != entries:
            raise ValueError("SwiftPM依存の著作権表示が変わっています。再出力してレビューしてください")
        print(f"{len(entries)}件のiOSライセンスがSwiftPM依存と一致しています")
        return
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    TARGET.write_text(json.dumps(entries, ensure_ascii=False, indent=2) + "\n")
    print(f"{len(entries)}件のiOSライセンスを保存: {TARGET.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
