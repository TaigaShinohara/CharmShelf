#!/usr/bin/env python3
"""Check optional distribution configuration without building or uploading."""

import argparse
from pathlib import Path
import plistlib
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def require_distribution_config(
    platform: str,
    root: Path | None = None,
    *,
    android_upload_certificate: Path | None = None,
    ios_export_options: Path | None = None,
    check_installed_signing: bool = False,
) -> None:
    root = root or ROOT
    try:
        if platform == "android":
            certificate_path = root / (android_upload_certificate or "android/upload_certificate.sha256")
            fingerprint = certificate_path.read_text().strip()
            if not re.fullmatch(r"(?:[0-9A-F]{2}:){31}[0-9A-F]{2}", fingerprint):
                raise ValueError()
        elif platform == "ios":
            options_path = ios_export_options or root / "scripts/ios_export_options.plist"
            options = plistlib.loads(options_path.read_bytes())
            if (options.get("method"), options.get("destination"), options.get("signingStyle")) != (
                "app-store-connect", "export", "manual"
            ):
                raise ValueError()
            if not re.fullmatch(r"[A-Z0-9]{10}", options.get("teamID", "")):
                raise ValueError()
            certificate = options.get("signingCertificate", "")
            if not re.fullmatch(r"[0-9A-F]{40}", certificate):
                raise ValueError()
            profile = options["provisioningProfiles"]["org.charmshelf.opensource"]
            if not isinstance(profile, str) or not profile.strip() or profile.startswith("YOUR_"):
                raise ValueError()
        else:
            raise ValueError()
    except (OSError, ValueError, TypeError, KeyError, AttributeError, plistlib.InvalidFileException):
        raise SystemExit(
            f"DISTRIBUTION_NOT_CONFIGURED: Configure your own {platform} distribution settings; "
            "see auth/README.md. No signing or upload was attempted."
        ) from None

    if platform == "ios" and check_installed_signing:
        require_installed_ios_identity(certificate)


def require_installed_ios_identity(certificate: str) -> None:
    try:
        result = subprocess.run(
            ["security", "find-identity", "-v", "-p", "codesigning"],
            check=True, capture_output=True, text=True, timeout=20,
        )
        identity = rf'^\s*\d+\)\s+{certificate}\s+"(?:Apple|iPhone) Distribution:'
        if re.search(identity, result.stdout, re.MULTILINE):
            return
    except (OSError, subprocess.SubprocessError):
        pass
    raise SystemExit(
        "IOS_DISTRIBUTION_IDENTITY_UNAVAILABLE: The configured distribution certificate and its "
        "private key were not found in the active Keychain search list. No signing or upload was attempted."
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("platform", choices=("android", "ios"))
    parser.add_argument("--android-upload-certificate", type=Path)
    parser.add_argument("--ios-export-options", type=Path)
    parser.add_argument("--check-installed-signing", action="store_true")
    args = parser.parse_args()
    if args.platform != "android" and args.android_upload_certificate:
        parser.error("--android-upload-certificate requires the android platform")
    if args.platform != "ios" and (args.ios_export_options or args.check_installed_signing):
        parser.error("iOS signing options require the ios platform")
    require_distribution_config(
        args.platform, ios_export_options=args.ios_export_options,
        android_upload_certificate=args.android_upload_certificate,
        check_installed_signing=args.check_installed_signing,
    )
    if args.check_installed_signing:
        print("iOS distribution configuration and installed signing identity verified; no archive was exported or uploaded.")
    else:
        print(f"{args.platform} distribution configuration present; signing and upload permission remain unverified.")


if __name__ == "__main__":
    main()
