#!/usr/bin/env python3
"""Check optional distribution configuration without loading credentials or building."""

import argparse
from pathlib import Path
import plistlib
import re

ROOT = Path(__file__).resolve().parents[1]


def require_distribution_config(platform: str, root: Path | None = None) -> None:
    root = root or ROOT
    try:
        if platform == "android":
            fingerprint = (root / "android/upload_certificate.sha256").read_text().strip()
            if not re.fullmatch(r"(?:[0-9A-F]{2}:){31}[0-9A-F]{2}", fingerprint):
                raise ValueError()
        elif platform == "ios":
            options = plistlib.loads((root / "scripts/ios_export_options.plist").read_bytes())
            if (options.get("method"), options.get("destination"), options.get("signingStyle")) != (
                "app-store-connect", "export", "manual"
            ):
                raise ValueError()
            if not re.fullmatch(r"[A-Z0-9]{10}", options.get("teamID", "")):
                raise ValueError()
            if not re.fullmatch(r"[0-9A-F]{40}", options.get("signingCertificate", "")):
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


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("platform", choices=("android", "ios"))
    args = parser.parse_args()
    require_distribution_config(args.platform)
    print(f"{args.platform} distribution configuration present; signing and upload permission remain unverified.")


if __name__ == "__main__":
    main()
