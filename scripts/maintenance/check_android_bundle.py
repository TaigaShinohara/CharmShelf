#!/usr/bin/env python3
"""APK/AAB内のネイティブELFとpath overrideプラグインを検査する。"""

import argparse
import struct
import zipfile
from pathlib import Path

MINIMUM_ALIGNMENT = 0x4000
EXPECTED_ABIS = {"arm64-v8a", "armeabi-v7a", "x86_64"}
PLUGIN_REGISTRATIONS = {
    b"com.oodrive.downloadsfolder.DownloadsfolderPlugin": "downloadsfolder",
    b"org.jezequel.secure_application.SecureApplicationPlugin": "secure_application",
    b"xyz.justsoft.video_thumbnail.VideoThumbnailPlugin": "video_thumbnail",
}


def load_alignments(data: bytes) -> list[int]:
    if data[:4] != b"\x7fELF" or data[4] not in (1, 2):
        raise ValueError("ELF header is missing")
    endian = "<" if data[5] == 1 else ">" if data[5] == 2 else None
    if endian is None:
        raise ValueError("unsupported ELF byte order")
    is_64 = data[4] == 2
    offset = struct.unpack_from(endian + ("Q" if is_64 else "I"), data, 32 if is_64 else 28)[0]
    entry_size, count = struct.unpack_from(endian + "HH", data, 54 if is_64 else 42)
    minimum_size = 56 if is_64 else 32
    if entry_size < minimum_size:
        raise ValueError("ELF program header is too short")
    alignments = []
    for index in range(count):
        entry = offset + index * entry_size
        if entry + minimum_size > len(data):
            raise ValueError("ELF program header is truncated")
        if struct.unpack_from(endian + "I", data, entry)[0] == 1:
            alignments.append(
                struct.unpack_from(endian + ("Q" if is_64 else "I"), data, entry + (48 if is_64 else 28))[0]
            )
    return alignments


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path)
    args = parser.parse_args()

    with zipfile.ZipFile(args.bundle) as archive:
        is_apk = args.bundle.suffix.lower() == ".apk"
        prefix = "lib/" if is_apk else "base/lib/"
        libraries = [name for name in archive.namelist() if name.startswith(prefix) and name.endswith(".so")]
        if not libraries:
            raise ValueError("AABにネイティブライブラリがありません")
        isar_abis = set()
        for name in libraries:
            data = archive.read(name)
            alignments = load_alignments(data)
            abi = name[len(prefix):].split("/")[0]
            # Android's 16KB requirement applies to 64-bit devices. ARMv7
            # remains a 4KB architecture; do not reject a valid 32-bit PDFium.
            minimum = MINIMUM_ALIGNMENT if abi in {"arm64-v8a", "x86_64"} else 0x1000
            if not alignments or any(value < minimum for value in alignments):
                actual = ", ".join(f"0x{value:x}" for value in alignments)
                raise ValueError(f"{name}: PT_LOAD alignment={actual}")
            if name.endswith("/libisar.so"):
                isar_abis.add(abi)
                if b"3.1.0+1" not in data:
                    raise ValueError(f"{name}: Isar version marker missing")
        if isar_abis != EXPECTED_ABIS:
            raise ValueError(f"Unexpected Isar ABIs: {sorted(isar_abis)}")

        dex = b"".join(archive.read(name) for name in archive.namelist() if name.endswith(".dex") and (name.startswith("classes") if is_apk else name.startswith("base/dex/")))
        missing = [label for registration, label in PLUGIN_REGISTRATIONS.items() if registration not in dex]
        if missing:
            raise ValueError(f"AABにpath overrideプラグインがありません: {', '.join(missing)}")

    print(f"Android {'APK' if is_apk else 'AAB'}: {len(libraries)} ELF files checked; 64-bit libraries are 16KB aligned")
    print(f"Android {'APK' if is_apk else 'AAB'}: downloadsfolder, secure_application, video_thumbnail included")


if __name__ == "__main__":
    main()
