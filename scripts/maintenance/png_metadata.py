#!/usr/bin/env python3
"""Remove selected authoring metadata from first-party PNG icons without re-encoding."""

import argparse
import os
from pathlib import Path
import stat
import struct
import sys
import tempfile
import zlib


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
SENSITIVE_KEYWORDS = frozenset(
    {"Author", "Description", "Creation Time", "XML:com.adobe.xmp"}
)
TEXT_CHUNKS = frozenset({b"tEXt", b"iTXt", b"zTXt"})
ROOT = Path(__file__).resolve().parents[2]


def _text_keyword(kind: bytes, payload: bytes) -> str:
    separator = payload.find(b"\0")
    if not 1 <= separator <= 79:
        raise ValueError("PNG text keyword is invalid")
    keyword = payload[:separator]
    if (
        any(not (32 <= byte <= 126 or 161 <= byte <= 255) for byte in keyword)
        or keyword.startswith(b" ")
        or keyword.endswith(b" ")
        or b"  " in keyword
    ):
        raise ValueError("PNG text keyword is invalid")
    remaining = payload[separator + 1 :]
    if kind == b"zTXt" and (not remaining or remaining[0] != 0):
        raise ValueError("PNG compressed text header is invalid")
    if kind == b"iTXt":
        if len(remaining) < 4 or remaining[0] not in (0, 1) or remaining[1] != 0:
            raise ValueError("PNG international text header is invalid")
        language_end = remaining.find(b"\0", 2)
        if language_end < 0 or remaining.find(b"\0", language_end + 1) < 0:
            raise ValueError("PNG international text header is incomplete")
    return keyword.decode("latin-1")


def _chunks(data: bytes) -> list[tuple[bytes, bytes, bytes]]:
    """Return validated (type, payload, original chunk bytes) tuples."""
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError("PNG signature is missing")
    chunks = []
    offset = len(PNG_SIGNATURE)
    seen_idat = False
    after_idat = False
    seen_palette = False
    color_type = None
    bit_depth = None
    while offset < len(data):
        if len(data) - offset < 12:
            raise ValueError("PNG chunk header is truncated")
        length = struct.unpack_from(">I", data, offset)[0]
        if length > 0x7FFFFFFF or length > len(data) - offset - 12:
            raise ValueError("PNG chunk length is invalid")
        kind = data[offset + 4 : offset + 8]
        if any(not (65 <= byte <= 90 or 97 <= byte <= 122) for byte in kind):
            raise ValueError("PNG chunk type is invalid")
        if not 65 <= kind[2] <= 90:
            raise ValueError("PNG chunk reserved bit is invalid")
        end = offset + 12 + length
        payload = data[offset + 8 : end - 4]
        expected_crc = struct.unpack_from(">I", data, end - 4)[0]
        if zlib.crc32(kind + payload) & 0xFFFFFFFF != expected_crc:
            raise ValueError("PNG chunk CRC does not match")
        if not chunks and kind != b"IHDR":
            raise ValueError("PNG must begin with IHDR")
        if kind == b"IHDR":
            if chunks or length != 13:
                raise ValueError("PNG IHDR is invalid")
            width, height, bit_depth, color_type, compression, filtering, interlace = (
                struct.unpack(">IIBBBBB", payload)
            )
            depths = {0: {1, 2, 4, 8, 16}, 2: {8, 16}, 3: {1, 2, 4, 8}, 4: {8, 16}, 6: {8, 16}}
            if (
                not 0 < width <= 0x7FFFFFFF
                or not 0 < height <= 0x7FFFFFFF
                or bit_depth not in depths.get(color_type, set())
                or compression != 0
                or filtering != 0
                or interlace not in (0, 1)
            ):
                raise ValueError("PNG IHDR fields are invalid")
        elif kind == b"PLTE":
            if seen_palette or seen_idat or not length or length % 3 or length > 768:
                raise ValueError("PNG palette is invalid")
            if color_type in (0, 4) or (color_type == 3 and length // 3 > 1 << bit_depth):
                raise ValueError("PNG palette does not match IHDR")
            seen_palette = True
        elif kind == b"IDAT":
            if after_idat or (color_type == 3 and not seen_palette):
                raise ValueError("PNG image data order is invalid")
            seen_idat = True
        elif kind == b"IEND":
            if length or not seen_idat or end != len(data):
                raise ValueError("PNG IEND is invalid")
        elif seen_idat:
            after_idat = True
        if kind in TEXT_CHUNKS:
            _text_keyword(kind, payload)
        chunks.append((kind, payload, data[offset:end]))
        offset = end
        if kind == b"IEND":
            return chunks
    raise ValueError("PNG IEND is missing")


def sensitive_png_keywords(data: bytes) -> list[str]:
    """Return only the selected keyword names; never return metadata values."""
    return sorted(
        {
            _text_keyword(kind, payload)
            for kind, payload, _ in _chunks(data)
            if kind in TEXT_CHUNKS and _text_keyword(kind, payload) in SENSITIVE_KEYWORDS
        }
    )


def sanitize_png(data: bytes) -> bytes:
    """Remove selected text chunks, preserving every other chunk byte for byte."""
    return PNG_SIGNATURE + b"".join(
        raw
        for kind, payload, raw in _chunks(data)
        if not (kind in TEXT_CHUNKS and _text_keyword(kind, payload) in SENSITIVE_KEYWORDS)
    )


def firstparty_icon_paths(root: Path) -> list[Path]:
    """Select owned icon resources only, excluding samples and dependency assets."""
    root = root.resolve()
    paths = set((root / "assets/images/icon").glob("*.png"))
    paths.update((root / "web/icons").glob("*.png"))
    favicon = root / "web/favicon.png"
    if favicon.exists():
        paths.add(favicon)
    for platform in ("ios", "macos"):
        paths.update((root / f"{platform}/Runner/Assets.xcassets").glob("AppIcon*.appiconset/*.png"))
    launcher_names = {
        "ic_launcher.png", "ic_launcher_foreground.png", "ic_launcher_background.png",
        "launcher_icon.png", "launcher_icon_round.png",
    }
    paths.update(
        path
        for path in (root / "android/app/src").glob("*/res/*/*.png")
        if path.name in launcher_names and path.parent.name.startswith(("mipmap", "drawable"))
    )
    for path in paths:
        current = root
        for part in path.relative_to(root).parts:
            current /= part
            if current.is_symlink():
                raise ValueError("Refusing a symlink in the first-party icon selection")
        if not path.resolve().is_relative_to(root):
            raise ValueError("Refusing an icon path outside the repository")
    return sorted(path for path in paths if path.is_file())


def _replace_atomically(path: Path, original: bytes, sanitized: bytes) -> None:
    mode = stat.S_IMODE(path.stat().st_mode)
    if path.read_bytes() != original:
        raise ValueError("Icon changed while metadata was being checked")
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(prefix=f".{path.name}.privacy-", dir=path.parent, delete=False) as output:
            temporary = Path(output.name)
            os.fchmod(output.fileno(), mode)
            output.write(sanitized)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
        temporary = None
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=ROOT, help="Repository containing first-party icon resources")
    parser.add_argument("--apply", action="store_true", help="Atomically replace icons after all selected PNGs validate")
    args = parser.parse_args(argv)
    try:
        paths = firstparty_icon_paths(args.repo)
        if not paths:
            raise ValueError("No first-party PNG icons were found")
        changes = []
        # Validate the whole selection before replacing any file.
        for path in paths:
            original = path.read_bytes()
            sanitized = sanitize_png(original)
            if sanitized != original:
                changes.append((path, original, sanitized))
        if args.apply:
            for path, original, sanitized in changes:
                _replace_atomically(path, original, sanitized)
        print(f"PNG metadata: inspected={len(paths)} affected={len(changes)} mode={'apply' if args.apply else 'check'}")
        for path, _, _ in changes:
            print(path.relative_to(args.repo.resolve()).as_posix())
        return 0 if args.apply or not changes else 1
    except (OSError, ValueError) as error:
        print(f"PNG metadata: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
