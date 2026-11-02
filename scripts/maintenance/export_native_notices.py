#!/usr/bin/env python3
"""Rebuild the pinned Isar/Rust/PDFium license snapshot from explicit inputs.

No network, authentication, build, or global configuration changes are performed.
Native inputs are normally needed only when native dependencies are updated.
"""

import argparse
import hashlib
import json
from pathlib import Path
import tarfile
import tomllib

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "assets/licenses/native_notices.json"
INPUTS = ROOT / "assets/licenses/native_inputs"
ISAR_COMMIT = "6643d064abf22606b6c6a741ea873e4781115ef4"
MDBX_COMMIT = "53177e483c18adf5109aed7a5895915e9798ee24"
PREFIXES = ("LICENSE", "LICENCE", "COPYING", "COPYRIGHT", "NOTICE")
SUPPLEMENTS = {"jni-sys-macros": "jni-sys-macros", "ndk-context": "ndk-context", "malloc_buf": "malloc_buf", "winapi-i686-pc-windows-gnu": "winapi", "winapi-x86_64-pc-windows-gnu": "winapi"}
DECLARED_MIT_ONLY = {"block", "objc-foundation", "objc_id"}


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def decode(raw: bytes) -> str:
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return raw.decode("cp1252")


def notice_files(root: Path) -> list[Path]:
    result = []
    for path in root.iterdir():
        if path.is_file() and path.name.upper().startswith(PREFIXES):
            result.append(path)
        elif path.is_dir() and path.name.lower() in {"licenses", "licences"}:
            result.extend(p for p in path.rglob("*") if p.is_file())
    return sorted(result)


def original_files(root: Path, paths: list[Path], checksums: dict | None = None) -> tuple[str, list[dict]]:
    texts, files = [], []
    for path in paths:
        raw = path.read_bytes()
        rel = path.relative_to(root).as_posix()
        if checksums is not None and checksums.get(rel) != sha256(raw):
            raise ValueError(f"Cached crate license does not match original checksum: {root.name}/{rel}")
        files.append({"file": rel, "sha256": sha256(raw)})
        texts.append(f"--- {rel} ---\n{decode(raw)}")
    return "\n\n".join(texts), files


def native_entries(args) -> list[dict]:
    expected_lock = (ROOT / "scripts/maintenance/isar_android.Cargo.lock").read_bytes()
    if (args.isar_source / "Cargo.lock").read_bytes() != expected_lock:
        raise ValueError("Native source lock differs from the committed build lock")
    lock = tomllib.loads(expected_lock.decode())
    registries = list((args.cargo_cache / "registry/src").glob("*"))
    entries = []
    for package in lock["package"]:
        name, version = package["name"], package["version"]
        if package.get("source", "").startswith("registry+"):
            candidates = [r / f"{name}-{version}" for r in registries if (r / f"{name}-{version}").is_dir()]
            if len(candidates) != 1:
                raise ValueError(f"Expected one exact crate input: {name}@{version}")
            source = candidates[0]
            archives = list((args.cargo_cache / "registry/cache").glob(f"*/{name}-{version}.crate"))
            if len(archives) != 1:
                raise ValueError(f"Expected one exact crate archive: {name}@{version}")
            if sha256(archives[0].read_bytes()) != package["checksum"]:
                raise ValueError(f"Registry archive checksum differs: {name}@{version}")
            raw_manifest = (source / "Cargo.toml").read_bytes()
            paths = notice_files(source)
            checksums = {}
            with tarfile.open(archives[0], "r:gz") as archive:
                for path in [source / "Cargo.toml", *paths]:
                    rel = path.relative_to(source).as_posix()
                    member = archive.extractfile(f"{name}-{version}/{rel}")
                    if member is None:
                        raise ValueError(f"Crate archive lacks input file: {name}/{rel}")
                    checksums[rel] = sha256(member.read())
            if sha256(raw_manifest) != checksums["Cargo.toml"]:
                raise ValueError(f"Crate manifest differs from original: {name}@{version}")
            metadata = tomllib.loads(raw_manifest.decode())["package"]
            text, files = original_files(source, paths, checksums)
            note = None
            supplemental_source = None
            if not paths and name in SUPPLEMENTS:
                key = SUPPLEMENTS[name]
                license_file = INPUTS / f"{key}.txt"
                text = license_file.read_text()
                supplemental_source = json.loads((INPUTS / f"{key}.source.json").read_text())["url"]
                files = [{"file": f"upstream-supplement/{key}.txt", "sha256": sha256(license_file.read_bytes())}]
                note = "The published crate omits a standalone license file. The declared license is supplemented with the upstream repository's license text; for dual-licensed crates the Apache-2.0 option is used."
            elif not paths and name in DECLARED_MIT_ONLY:
                if metadata.get("license") != "MIT":
                    raise ValueError(f"Expected MIT declaration: {name}")
                # Preserve the upstream grant and author metadata without inventing
                # a copyright year or attributing our project's notice to a crate.
                mit = (ROOT / "LICENSE").read_text().split("Permission is hereby granted", 1)[1]
                text = "MIT License\n\nDeclared license: MIT\nAuthors (upstream Cargo.toml): " + ", ".join(metadata.get("authors", [])) + "\n\nPermission is hereby granted" + mit
                files = [{"file": "Cargo.toml", "sha256": sha256(raw_manifest)}]
                note = "Upstream declares MIT in Cargo.toml but does not include a standalone license or copyright notice. Author metadata and standard MIT terms are reproduced; no copyright year has been inferred."
            elif not paths:
                raise ValueError(f"Unresolved native license: {name}@{version}")
            if name.startswith("winapi-"):
                header = (source / "src/lib.rs").read_text().splitlines()
                copyright_lines = [line.removeprefix("// ") for line in header[:8] if "Copyright" in line]
                if copyright_lines:
                    text = "\n".join(copyright_lines) + "\n\n" + text
            entry = {"package": name, "version": version, "category": "rust-lock", "license": metadata.get("license", metadata.get("license-file", "See included license")), "source": f"https://crates.io/crates/{name}/{version}", "archive_sha256": package["checksum"], "files": files, "text": text}
            if note:
                entry["note"] = note
            if supplemental_source:
                entry["supplemental_source"] = supplemental_source
            entries.append(entry)
        else:
            text, files = original_files(args.isar_source, notice_files(args.isar_source))
            entries.append({"package": name, "version": version, "category": "rust-lock", "license": "Apache-2.0", "source": f"https://github.com/isar/isar/tree/{ISAR_COMMIT}", "files": files, "text": text, "note": "Local workspace crate covered by the Isar source distribution's root license."})
    text, files = original_files(args.libmdbx_source, [args.libmdbx_source / "LICENSE", args.libmdbx_source / "COPYRIGHT"])
    entries.append({"package": "libmdbx", "version": "0.12.4", "category": "native", "license": "OLDAP-2.8", "source": f"https://github.com/erthink/libmdbx/tree/{MDBX_COMMIT}", "files": files, "text": text})
    pdfium = json.loads((INPUTS / "pdfium-android.json").read_text())
    if len(pdfium["files"]) < 20:
        raise ValueError("Incomplete PDFium license input")
    entries.append({"package": "PDFium and bundled third-party libraries", "version": "chromium/8125", "category": "native", "source": pdfium["source"], "archive_sha256": pdfium["archive_sha256"], "files": [{k: v for k, v in f.items() if k != "text"} for f in pdfium["files"]], "text": "\n\n".join(f"--- {f['file']} ---\n{f['text']}" for f in pdfium["files"]), "note": "Unmodified license texts from the exact non-V8 PDFium binary release used by pdfium_dart 0.4.1. The matching Darwin XCFramework uses the same chromium/8125 source revision; its release archive does not ship license files, so these upstream PDFium license texts accompany it too."})
    entries.sort(key=lambda e: (e["category"], e["package"], e.get("version", "")))
    return entries


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--isar-source", type=Path, required=True)
    parser.add_argument("--cargo-cache", type=Path, required=True)
    parser.add_argument("--libmdbx-source", type=Path, required=True)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    entries = native_entries(args)
    content = json.dumps(entries, ensure_ascii=False, indent=2) + "\n"
    if args.check:
        if OUTPUT.read_text() != content:
            raise ValueError("Native license snapshot differs from pinned source inputs")
    else:
        OUTPUT.write_text(content)
    print(f"{'Verified' if args.check else 'Exported'} {len(entries)} native notices")


if __name__ == "__main__":
    main()
