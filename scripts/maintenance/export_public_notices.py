#!/usr/bin/env python3
"""Export resolved Dart and retained native license texts without network access.

Run after `flutter pub get`. The native input snapshot is checked in separately;
no local user paths, credentials, or build logs are included in generated files.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
from urllib.parse import unquote, urljoin, urlparse


ROOT = Path(__file__).resolve().parents[2]
LICENSE_DIR = ROOT / "assets/licenses"
OUTPUT = LICENSE_DIR / "third_party_notices.json"
INDEX_OUTPUT = ROOT / "THIRD_PARTY_NOTICES.md"
IOS_OUTPUT = LICENSE_DIR / "ios_native_licenses.json"
NATIVE_INPUT = LICENSE_DIR / "native_notices.json"
NOTICE_PREFIXES = ("LICENSE", "LICENCE", "COPYING", "COPYRIGHT", "NOTICE", "THIRD_PARTY_NOTICES")
SWIFT_EXTRA_NAMES = {"SDWebImageWebPCoder", "Mantle", "SDWebImage", "libwebp"}


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_license(path: Path) -> tuple[str, str]:
    raw = path.read_bytes()
    try:
        return raw.decode("utf-8"), digest(raw)
    except UnicodeDecodeError:
        return raw.decode("cp1252"), digest(raw)


def notice_files(root: Path) -> list[Path]:
    result = []
    for path in root.iterdir():
        if path.is_file() and path.name.upper().startswith(NOTICE_PREFIXES):
            result.append(path)
        elif path.is_dir() and path.name.lower() in {"licenses", "licences"}:
            result.extend(p for p in path.rglob("*") if p.is_file())
    return sorted(result)


def joined_files(root: Path, files: list[Path]) -> tuple[str, list[dict]]:
    texts, metadata = [], []
    for path in files:
        text, checksum = read_license(path)
        name = path.relative_to(root).as_posix()
        texts.append(f"--- {name} ---\n{text}")
        metadata.append({"file": name, "sha256": checksum})
    return "\n\n".join(texts), metadata


def package_roots() -> dict[str, Path]:
    config_path = ROOT / ".dart_tool/package_config.json"
    config = json.loads(config_path.read_text())
    result = {}
    for package in config["packages"]:
        parsed = urlparse(urljoin(config_path.as_uri(), package["rootUri"]))
        if parsed.scheme != "file":
            raise ValueError(f"Non-file package root: {package['name']}")
        result[package["name"]] = Path(unquote(parsed.path)).resolve()
    return result


def lock_versions() -> dict[str, str]:
    # Only the stable package-name/version subset of pubspec.lock is required.
    result, name = {}, None
    for line in (ROOT / "pubspec.lock").read_text().splitlines():
        if line.startswith("  ") and not line.startswith("   ") and line.endswith(":"):
            name = line.strip()[:-1]
        elif name and line.startswith("    version:"):
            result[name] = line.split(":", 1)[1].strip().strip('"\'')
    return result


def dart_entries(roots: dict[str, Path]) -> list[dict]:
    versions = lock_versions()
    flutter_root = roots["flutter"].parents[1]
    match = re.search(r"(?m)^  flutter:\s*([0-9]+\.[0-9]+\.[0-9]+)\s*$", (ROOT / "pubspec.yaml").read_text())
    if not match:
        raise ValueError("Pinned Flutter SDK version is missing")
    sdk_version = match.group(1)
    entries = []
    for name, root in sorted(roots.items()):
        if root == ROOT:
            continue
        if name.startswith("syncfusion"):
            raise ValueError("Removed proprietary dependency is still resolved")
        files = notice_files(root)
        note = None
        if not files and root.is_relative_to(flutter_root / "packages"):
            files = [flutter_root / "LICENSE"]
            text, metadata = joined_files(flutter_root, files)
            note = "This Flutter SDK package inherits the Flutter SDK license."
        elif files:
            text, metadata = joined_files(root, files)
        else:
            raise FileNotFoundError(f"No license text for resolved Dart package: {name}")
        is_sdk = root.is_relative_to(flutter_root)
        entry = {
            "package": name,
            "version": f"Flutter {sdk_version}" if is_sdk else versions[name],
            "category": "dart",
            "source": f"https://github.com/flutter/flutter/tree/{sdk_version}" if is_sdk else f"https://pub.dev/packages/{name}/versions/{versions[name]}",
            "files": metadata,
            "text": text,
        }
        if note:
            entry["note"] = note
        entries.append(entry)
    return entries


def retained_source_entries(roots: dict[str, Path]) -> list[dict]:
    referenced = {r.resolve() for r in roots.values()}
    entries = []
    for directory in sorted((ROOT / "patches").iterdir()):
        if not directory.is_dir() or directory.resolve() in referenced:
            continue
        if directory.name.startswith("syncfusion"):
            raise ValueError("Removed proprietary source remains in patches")
        files = notice_files(directory)
        if not files:
            raise FileNotFoundError(f"No license for retained source: {directory.name}")
        text, metadata = joined_files(directory, files)
        entries.append({"package": directory.name, "category": "retained-source", "source": f"patches/{directory.name}", "files": metadata, "text": text})
    gradle = ROOT / "android/flutter_gradle"
    if gradle.is_dir():
        text, metadata = joined_files(gradle, notice_files(gradle))
        entries.append({"package": "Flutter Gradle plugin local patch", "category": "retained-source", "source": "android/flutter_gradle", "files": metadata, "text": text})
    return entries


def ios_entries(roots: dict[str, Path]) -> list[dict]:
    previous = json.loads(IOS_OUTPUT.read_text())
    native_deps = json.loads((ROOT / ".flutter-plugins-dependencies").read_text())
    plugins = {p["name"] for p in native_deps["plugins"]["ios"] if p.get("native_build")}
    result = []
    for name in sorted(plugins):
        root = roots[name]
        candidates = [root / "LICENSE", root / "LICENSE.md"]
        if name == "integration_test":
            candidates.append(roots["flutter"].parents[1] / "LICENSE")
        files = [path for path in candidates if path.is_file()]
        if not files:
            raise FileNotFoundError(f"No iOS plugin license: {name}")
        result.append({"package": name, "text": read_license(files[0])[0]})
    for entry in previous:
        if entry["package"] in SWIFT_EXTRA_NAMES:
            result.append({"package": entry["package"], "text": entry["text"]})
    names = {e["package"] for e in result}
    if not SWIFT_EXTRA_NAMES <= names:
        raise ValueError("Required SwiftPM native notices are missing")
    return sorted(result, key=lambda e: e["package"])


def render_json(value: object) -> str:
    return json.dumps(value, ensure_ascii=False, indent=2) + "\n"


def save_or_check(path: Path, value: object, check: bool) -> None:
    expected = render_json(value)
    if check:
        if not path.is_file() or path.read_text() != expected:
            raise ValueError(f"License output is stale: {path.relative_to(ROOT)}")
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(expected)


def notice_index(entries: list[dict]) -> str:
    lines = [
        "# Third-party notices",
        "",
        "CharmShelf's own source code is covered by the root [MIT license](LICENSE). Third-party software keeps its original license; the root MIT license does not replace any upstream license.",
        "",
        "The complete license and attribution texts are distributed in [assets/licenses/third_party_notices.json](assets/licenses/third_party_notices.json) and displayed by the app's license screen. Keep that file and the applicable upstream license/notice files with redistributions. The index below identifies the corresponding source or retained source directory.",
        "",
        "The resolved Dart graph includes development and platform-specific dependencies. The retained Rust lock graph also includes build-time and target-specific crates; inclusion in this index does not mean every crate is linked into every platform binary. Entries explicitly identify the rare upstream crates that declare MIT without shipping a standalone license file; their declared grant and author metadata are preserved with standard MIT terms and no inferred copyright year.",
        "",
        "Native PDFium's bundled components and libmdbx's OpenLDAP license are included separately from the Dart wrappers and Isar's Apache license. MPL-2.0 components such as dbus and nm retain their own license and versioned source links. Source modifications to a dependency must keep the original notices and follow that dependency's license.",
        "",
        "Regenerate after dependency resolution with `python3 scripts/maintenance/export_public_notices.py`; verify with the same command and `--check`. Native inputs and update instructions are documented in [docs/NATIVE_PROVENANCE.md](docs/NATIVE_PROVENANCE.md). First-party media are documented in [docs/ASSET_LICENSES.md](docs/ASSET_LICENSES.md).",
        "",
        "| Component | Version | Group | Source |",
        "|---|---|---|---|",
    ]
    for entry in entries:
        name = entry["package"].replace("|", "\\|")
        source = entry["source"]
        lines.append(f"| {name} | {entry.get('version', '—')} | {entry['category']} | [source]({source}) |")
    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    roots = package_roots()
    dart = dart_entries(roots)
    ios = ios_entries(roots)
    native = json.loads(NATIVE_INPUT.read_text())
    for entry in native:
        if not entry.get("text") or not entry.get("source"):
            raise ValueError("Incomplete native notice")
    swift = [{**e, "category": "swiftpm", "source": "assets/licenses/ios_native_licenses.json"} for e in ios if e["package"] in SWIFT_EXTRA_NAMES]
    combined = dart + retained_source_entries(roots) + swift + native
    combined.sort(key=lambda e: (e["category"], e["package"], e.get("version", "")))
    ids = [(e["category"], e["package"], e.get("version", "")) for e in combined]
    if len(ids) != len(set(ids)):
        raise ValueError("Duplicate notice identity")
    save_or_check(IOS_OUTPUT, ios, args.check)
    save_or_check(OUTPUT, combined, args.check)
    index = notice_index(combined)
    if args.check:
        if INDEX_OUTPUT.read_text() != index:
            raise ValueError("Third-party notice index is stale")
    else:
        INDEX_OUTPUT.write_text(index)
    action = "Verified" if args.check else "Exported"
    print(f"{action} {len(combined)} notices ({len(dart)} Dart, {len(native)} native, {len(ios)} iOS registry entries)")


if __name__ == "__main__":
    main()
