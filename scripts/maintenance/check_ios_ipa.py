#!/usr/bin/env python3
"""書き出したIPAの署名・プロファイル・Release内容を検査する。送信はしない。"""

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path, PurePosixPath
import plistlib
import re
import stat
import subprocess
import tempfile
import zipfile

from check_ios_archive import inspect_app


def run(*command: str) -> bytes:
    result = subprocess.run(command, capture_output=True)
    if result.returncode:
        raise ValueError(f"{command[0]} failed: {result.stderr.decode(errors='replace').strip()}")
    return result.stdout


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def binary_uuids(path: Path) -> list[str]:
    output = run("xcrun", "dwarfdump", "--uuid", str(path)).decode()
    uuids = sorted(re.findall(r"UUID: ([0-9A-F-]+)", output))
    require(bool(uuids), f"Missing Mach-O UUID: {path.name}")
    return uuids


def verify(ipa: Path, archive: Path, export_options: Path) -> dict:
    options = plistlib.loads(export_options.read_bytes())
    require(options.get("method") == "app-store-connect", "Expected App Store export method")
    require(options.get("destination") == "export", "Export options must not upload")
    require(options.get("signingStyle") == "manual", "Expected explicit manual signing")
    expected_certificate = options["signingCertificate"].upper()
    require(bool(re.fullmatch(r"[0-9A-F]{40}", expected_certificate)), "Expected certificate SHA-1")
    team = options["teamID"]
    bundle_id = "org.charmshelf.opensource"
    app_identifier = f"{team}.{bundle_id}"
    expected_profile = options["provisioningProfiles"][bundle_id]
    archive_info = plistlib.loads((archive / "Info.plist").read_bytes())
    original_app = archive / "Products" / archive_info["ApplicationProperties"]["ApplicationPath"]
    original_info = plistlib.loads((original_app / "Info.plist").read_bytes())

    # 自分で作ったIPAのみを対象とし、展開先外へのパスとシンボリックリンクを拒否する。
    with zipfile.ZipFile(ipa) as package:
        for entry in package.infolist():
            path = PurePosixPath(entry.filename)
            require(not path.is_absolute() and ".." not in path.parts and "\\" not in entry.filename,
                    "Unsafe ZIP path")
            require(not stat.S_ISLNK(entry.external_attr >> 16), "Symlink ZIP entry is not supported")
        require(package.testzip() is None, "IPA ZIP checksum failed")

    with tempfile.TemporaryDirectory(prefix="tagshelf-ipa-check-") as temporary:
        working = Path(temporary)
        extracted = working / "extracted"
        run("ditto", "-x", "-k", str(ipa), str(extracted))
        applications = list((extracted / "Payload").glob("*.app"))
        require(len(applications) == 1, "Expected exactly one app in IPA")
        app = applications[0]
        info = plistlib.loads((app / "Info.plist").read_bytes())
        for key in ("CFBundleIdentifier", "CFBundleShortVersionString", "CFBundleVersion",
                    "UIDeviceFamily", "DTSDKName"):
            require(info[key] == original_info[key], f"Archive/IPA mismatch: {key}")
        result = inspect_app(app)  # 書き出し後もIsarの全FFI関数が残っていることを確認。
        run("codesign", "--verify", "--deep", "--strict", "--verbose=2", str(app))
        entitlements = plistlib.loads(run("codesign", "-d", "--entitlements", ":-", str(app)))
        require(entitlements.get("application-identifier") == app_identifier, "Signed app ID mismatch")
        require(entitlements.get("com.apple.developer.team-identifier") == team, "Signed team mismatch")
        require(entitlements.get("get-task-allow") is False, "Debugging must be disabled")

        profile = plistlib.loads(run("security", "cms", "-D", "-i", str(app / "embedded.mobileprovision")))
        require(profile["Name"] == expected_profile, "Unexpected embedded profile")
        require(profile["TeamIdentifier"] == [team], "Profile team mismatch")
        profile_entitlements = profile["Entitlements"]
        require(profile_entitlements.get("application-identifier") == app_identifier, "Profile app ID mismatch")
        require(profile_entitlements.get("get-task-allow") is False, "Development profile is not allowed")
        require(profile_entitlements.get("beta-reports-active") is True, "Expected App Store profile")
        require("ProvisionedDevices" not in profile and not profile.get("ProvisionsAllDevices", False),
                "Device-limited or enterprise profile is not allowed")
        expiry = profile["ExpirationDate"].replace(tzinfo=timezone.utc)
        require(expiry > datetime.now(timezone.utc), "Provisioning profile has expired")
        profile_certificates = [hashlib.sha1(cert).hexdigest().upper()
                                for cert in profile["DeveloperCertificates"]]
        require(expected_certificate in profile_certificates, "Profile does not include expected signer")

        # 証明書の公開部分だけを抽出する。秘密鍵の出力やキーチェーン設定変更はしない。
        prefix = working / "signing-certificate-"
        run("codesign", "-d", f"--extract-certificates={prefix}", str(app))
        actual_certificate = hashlib.sha1(Path(str(prefix) + "0").read_bytes()).hexdigest().upper()
        require(actual_certificate == expected_certificate, "IPA signing certificate mismatch")

        matched_uuids = {}
        for binary in ("Runner", "Frameworks/App.framework/App"):
            actual = binary_uuids(app / binary)
            require(actual == binary_uuids(original_app / binary), f"Archive/IPA UUID mismatch: {binary}")
            matched_uuids[binary] = actual

        result.update({
            "ipa": str(ipa),
            "ipa_sha256": hashlib.sha256(ipa.read_bytes()).hexdigest(),
            "ipa_bytes": ipa.stat().st_size,
            "signature_valid": True,
            "signing_certificate_sha1": actual_certificate,
            "team": team,
            "profile_name": profile["Name"],
            "profile_uuid": profile["UUID"],
            "profile_expires_utc": expiry.isoformat(),
            "get_task_allow": False,
            "matching_archive_uuids": matched_uuids,
            "upload_performed_by_this_check": False,
            "device_qa": "not_performed_by_this_check",
        })
        return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa", type=Path)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--export-options", type=Path,
                        default=Path(__file__).resolve().parents[1] / "ios_export_options.plist")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    try:
        report = verify(args.ipa.resolve(), args.archive.resolve(), args.export_options.resolve())
        text = json.dumps(report, indent=2) + "\n"
        if args.report:
            args.report.write_text(text)
        print(text, end="")
    except (ValueError, KeyError, OSError, StopIteration, zipfile.BadZipFile,
            subprocess.CalledProcessError) as error:
        parser.exit(1, f"IPA check failed: {error}\n")
