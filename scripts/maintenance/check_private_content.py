#!/usr/bin/env python3
"""Check first-party sources and release archives without printing sensitive values."""

import argparse
import contextlib
import json
import os
import re
import subprocess
import sys
import zipfile
from pathlib import Path, PurePosixPath

from png_metadata import sensitive_png_keywords

ROOT = Path(__file__).resolve().parents[2]
EMAIL = re.compile(r"(?<![\w.+-])[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}")
HOME = re.compile(rb"(?:/Users/(?!runner/|builder/|Shared/)[A-Za-z0-9_.-]{2,}/|[A-Z]:\\Users\\[^\\\x00\r\n]+\\|/home/[^/\x00\r\n]+/\.(?:cargo|rustup)/)")
SECRETS = {
    "private-key": re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----[\r\n]+[A-Za-z0-9+/=\r\n]{80,}"),
    "github-token": re.compile(rb"(?<![A-Za-z0-9_])(?:gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{60,})(?![A-Za-z0-9_])"),
    "google-api-key": re.compile(rb"(?<![A-Za-z0-9_])AIza[A-Za-z0-9_-]{35}(?![A-Za-z0-9_-])"),
    "google-oauth-secret": re.compile(rb"GOCSPX-[A-Za-z0-9_-]{20,}"),
    "aws-access-key": re.compile(rb"(?<![A-Z0-9])(?:AKIA|ASIA)[A-Z0-9]{16}(?![A-Z0-9])"),
    "service-token": re.compile(rb"(?<![A-Za-z0-9_])(?:sk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{32,}|xox[baprs]-[A-Za-z0-9-]{20,})"),
}
POLICY_KEYS = ("helpContent", "termsOfServiceContent", "privacyPolicyContent", "privacyPolicyCurrentContent")
PUBLIC_DOCS = ("docs/PRIVACY_POLICY.md", "docs/TERMS_OF_SERVICE.md", "docs/release/TERMS_OF_SERVICE_CURRENT_2026-09-30.md")
SAMPLE_DOMAIN = re.compile(r"(?:^|\.)(?:example\.(?:com|org|net)|example|test|invalid|localhost)$", re.I)
VENDOR_CONTACT_DOCS = frozenset({"docs/release/IOS_RELEASE_READINESS.md", "docs/release/LICENSE_AUDIT_2026-08-31.md", "docs/release/SYNCFUSION_APPLICATION_DRAFT.md"})
COPY_ROOTS = ("lib", "assets", "docs", "scripts", ".github", ".vscode", "web")
COPY_EXCLUDED = frozenset({".git", ".dart_tool", "build", "coverage", "__pycache__", ".DS_Store"})


def safe_source(root: Path, name: str) -> bool:
    relative = PurePosixPath(name)
    if relative.is_absolute() or ".." in relative.parts:
        return False
    path = root
    for component in relative.parts:
        path = path / component
        if path.is_symlink():
            return False
    return path.resolve().is_relative_to(root.resolve())


def source_bytes(root: Path, name: str) -> bytes:
    if not safe_source(root, name):
        raise ValueError("Unchecked source link or path")
    return (root / name).read_bytes()


def configured_email(root: Path) -> str:
    text = source_bytes(root, "template_config.yaml").decode("utf-8")
    block = re.search(r"(?m)^company:\s*\n((?:[ \t]+[^\n]*\n|\n)*)", text)
    match = re.search(r"(?m)^\s+email:\s*[\"']?([^\s\"'#]+)", block.group(1) if block else "")
    if not match or EMAIL.fullmatch(match.group(1)) is None:
        raise ValueError("company.email must contain one valid public contact address")
    return match.group(1)


def blob_issues(data: bytes) -> set[str]:
    issues = {label for label, pattern in SECRETS.items() if pattern.search(data)}
    if b"PRIVATE KEY-----" in data and b"\\n" in data:
        unescaped = data.replace(b"\\r", b"\r").replace(b"\\n", b"\n")
        if SECRETS["private-key"].search(unescaped):
            issues.add("private-key")
    if HOME.search(data):
        issues.add("personal-home-path")
    # UTF-16 literals can occur in compiled Dart strings and native resources.
    for encoding in ("utf-16le", "utf-16be"):
        if b"\x00" not in data:
            break
        for offset in (0, 1):
            decoded = data[offset:].decode(encoding, errors="ignore").encode("utf-8")
            if HOME.search(decoded):
                issues.add("personal-home-path")
            issues.update(label for label, pattern in SECRETS.items() if pattern.search(decoded))
    return issues


def safe_location(name: str) -> str:
    data = EMAIL.sub("[address]", name).encode("utf-8", errors="replace")
    data = HOME.sub(b"[private-home]/", data)
    for pattern in SECRETS.values():
        data = pattern.sub(b"[credential]", data)
    return json.dumps(data.decode("utf-8", errors="replace"), ensure_ascii=True)


def approved_contact(found: str, address: str, name: str) -> bool:
    return (
        found == address
        or SAMPLE_DOMAIN.search(found.rsplit("@", 1)[1]) is not None
        or re.fullmatch(r"[A-Za-z0-9_.-]+@\d+x\.png", found) is not None
        or name in VENDOR_CONTACT_DOCS and found.lower() == "sales@syncfusion.com"
    )


def json_credential_issues(data: bytes) -> set[str]:
    try:
        value = json.loads(data)
    except (ValueError, UnicodeError):
        return set()
    fields = {"privatekey", "clientsecret", "apisecret", "apikey", "secretkey", "accesstoken", "refreshtoken", "password"}
    def contains(item):
        if isinstance(item, dict):
            for key, child in item.items():
                if key.lower().replace("_", "").replace("-", "") in fields and isinstance(child, str) and child.strip():
                    if not child.startswith(("op://", "${", "<")) and child.lower() not in {"example", "placeholder"}:
                        return True
                if contains(child):
                    return True
        elif isinstance(item, list):
            return any(contains(child) for child in item)
        return False
    return {"embedded-credential-value"} if contains(value) else set()


def sensitive_filename(name: str) -> bool:
    p = PurePosixPath(name)
    lower = p.name.lower()
    if lower in (".env.example", ".env.sample", ".env.template"):
        return False
    return lower in (".env", "key.properties", "google_play_service_account.json") or lower.startswith(".env.") or p.suffix.lower() in (".jks", ".keystore", ".p8", ".p12", ".pem")


def is_first_party_icon(name: str) -> bool:
    return name.endswith(".png") and (
        name.startswith("assets/images/icon/")
        or name.startswith("android/app/src/") and "/res/" in name
        or name.startswith(("ios/Runner/Assets.xcassets/AppIcon", "macos/Runner/Assets.xcassets/AppIcon", "web/icons/"))
        or name == "web/favicon.png"
    )


def policy_issues(root: Path, address: str) -> list[tuple[str, str]]:
    issues = []
    for lang in ("ja", "en"):
        relative = f"lib/l10n_src/{lang}/template.arb"
        values = json.loads(source_bytes(root, relative))
        for key in POLICY_KEYS:
            value = values[key]
            if not isinstance(value, str):
                raise ValueError("Public policy content must be a string")
            contacts = EMAIL.findall(value)
            if not contacts or set(contacts) != {address}:
                issues.append((relative + ":" + key, "public-contact-mismatch"))
            if re.search(r"(?:代表|Representative)\s*:", value):
                issues.append((relative + ":" + key, "personal-representative-field"))
    for relative in PUBLIC_DOCS:
        contacts = EMAIL.findall(source_bytes(root, relative).decode("utf-8"))
        if not contacts or set(contacts) != {address}:
            issues.append((relative, "public-contact-mismatch"))
    return issues


def source_issues(root: Path, address: str) -> tuple[list[tuple[str, str]], int]:
    issues = policy_issues(root, address)
    listing = subprocess.run(["git", "-c", "core.fsmonitor=false", "ls-files", "-z"], cwd=root, capture_output=True)
    if listing.returncode == 0:
        paths = set(listing.stdout.decode().split("\0"))
    else:
        # Downloaded/exported templates need the same check without a .git directory.
        paths = {item.name for item in root.iterdir() if item.is_file()}
    # Flutter and the template generator consume the working tree, including
    # ignored generated Dart and untracked assets, rather than only Git's index.
    for directory in COPY_ROOTS:
        if (root / directory).is_symlink():
            paths.add(directory)
            continue
        for base, dirs, files in os.walk(root / directory):
            linked = [name for name in dirs if (Path(base) / name).is_symlink()]
            paths.update(str((Path(base) / name).relative_to(root)) for name in linked)
            # App assets/lib/web can contain arbitrarily named subdirectories;
            # do not hide an asset merely because its directory is named build.
            excluded = COPY_EXCLUDED if directory not in {"lib", "assets", "web"} else {".git"}
            dirs[:] = [name for name in dirs if name not in excluded and name not in linked]
            paths.update(str((Path(base) / name).relative_to(root)) for name in files if name not in excluded and (directory in {"lib", "assets", "web"} or not name.endswith(".pyc")))
    count = 0
    for name in filter(None, paths):
        path = root / name
        if not safe_source(root, name):
            issues.append((name, "unchecked-source-symlink"))
            continue
        if not path.is_file():
            continue
        if sensitive_filename(name):
            issues.append((name, "secret-file"))
        # Third-party package sources retain their upstream notices and examples.
        # Synthetic regression fixtures deliberately contain token/path shapes.
        first_party = not name.startswith(("patches/", ".git/", "test/", "integration_test/", "test_driver/"))
        native = name.startswith("patches/isar_flutter_libs/android/") and name.endswith(".so")
        if not first_party and not native:
            continue
        count += 1
        data = source_bytes(root, name)
        if path.suffix.lower() in (".png", ".jpg", ".jpeg", ".mp3", ".wav", ".mp4", ".otf", ".ttf"):
            if is_first_party_icon(name):
                try:
                    if sensitive_png_keywords(data):
                        issues.append((name, "unnecessary-image-metadata"))
                except ValueError:
                    issues.append((name, "invalid-png"))
            continue
        for label in blob_issues(data):
            issues.append((name, label))
        if path.suffix == ".json":
            issues.extend((name, label) for label in json_credential_issues(data))
        if not name.startswith("assets/licenses/") and path.suffix in (".dart", ".arb", ".yaml", ".md", ".log", ".json", ".txt"):
            text = data.decode("utf-8", errors="replace")
            if re.search(r"(?<!\d)0[789]0[- ]?\d{4}[- ]?\d{4}(?!\d)", text):
                issues.append((name, "personal-phone-shape"))
            for found in EMAIL.findall(text):
                if not approved_contact(found, address, name):
                    issues.append((name, "unapproved-contact-address"))
                    break
    return issues, count


@contextlib.contextmanager
def artifact_blobs(path: Path):
    if path.is_dir():
        def files():
            for item in sorted(path.rglob("*")):
                if item.is_symlink():
                    raise ValueError("Release app must not contain unchecked symlinks")
                if item.is_file():
                    yield item.relative_to(path).as_posix(), item.read_bytes()
        yield files()
    else:
        with zipfile.ZipFile(path) as archive:
            yield ((info.filename, archive.read(info)) for info in archive.infolist() if not info.is_dir())


def archive_issues(path: Path, address: str) -> tuple[list[tuple[str, str]], int]:
    issues = []
    count = 0
    contact_present = False
    with artifact_blobs(path) as blobs:
        for name, data in blobs:
            count += 1
            if sensitive_filename(name):
                issues.append((name, "secret-file"))
            if any(address.encode(encoding) in data for encoding in ("utf-8", "utf-16le", "utf-16be")):
                contact_present = True
            # Random compressed pixels and signatures are not textual credentials.
            suffix = PurePosixPath(name).suffix.lower()
            if suffix in (".png", ".jpg", ".jpeg", ".car", ".ttf", ".otf", ".mp3", ".wav", ".mp4", ".rsa", ".sf", ".mobileprovision") or "/_CodeSignature/" in name:
                if name.endswith("/assets/images/icon/icon.png"):
                    try:
                        if sensitive_png_keywords(data):
                            issues.append((name, "unnecessary-image-metadata"))
                    except ValueError:
                        issues.append((name, "invalid-png"))
                continue
            # License emails are intentional third-party attribution. App binaries
            # are still scanned for home paths and token formats.
            issues.extend((name, label) for label in blob_issues(data))
            if suffix == ".json" and "/assets/licenses/" not in name:
                issues.extend((name, label) for label in json_credential_issues(data))
            if name.endswith(("/libapp.so", "/App.framework/App")):
                for match in re.finditer(rb"(?<![\w.+-])[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}", data):
                    found = match.group().decode("ascii", errors="ignore")
                    domain = found.rsplit("@", 1)[-1].lower()
                    if domain in ("gmail.com", "yahoo.co.jp", "outlook.com", "inkboxmail.com") and found != address:
                        issues.append((name, "unapproved-personal-contact"))
                        break
    if not contact_present:
        issues.append((path.name, "configured-contact-missing"))
    return issues, count


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--archive", action="append", type=Path, default=[])
    parser.add_argument("--sources-only", action="store_true")
    args = parser.parse_args()
    try:
        address = configured_email(args.root)
        issues, count = source_issues(args.root, address)
        print(f"Source privacy check: {count} first-party/native paths")
        if not args.sources_only:
            for archive in args.archive:
                found, entries = archive_issues(archive, address)
                issues.extend((archive.name + "!" + name, label) for name, label in found)
                print(f"Archive privacy check: {safe_location(archive.name)}: {entries} entries")
        for name, label in sorted(set(issues)):
            print(f"FAIL [{label}] {safe_location(name)}")
        print(f"Privacy check: {'FAIL' if issues else 'PASS'} ({len(set(issues))} issues; values redacted)")
        return 1 if issues else 0
    except Exception as error:
        print(f"Privacy check could not complete ({type(error).__name__}; values redacted)", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
