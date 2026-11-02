"""PNG metadata removal must preserve compressed pixels and unrelated metadata."""

import contextlib
import importlib.util
import io
from pathlib import Path
import stat
import struct
import tempfile
import unittest
import zlib


MODULE_PATH = Path(__file__).resolve().parents[2] / "scripts/maintenance/png_metadata.py"
SPEC = importlib.util.spec_from_file_location("png_metadata", MODULE_PATH)
PNG = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PNG)


def chunk(kind: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)


HEADER = chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0))
IMAGE_DATA = zlib.compress(b"\0\x11\x22\x33\x80")
PIXELS = chunk(b"IDAT", IMAGE_DATA[:3]) + chunk(b"IDAT", IMAGE_DATA[3:])
END = chunk(b"IEND", b"")
COLOR = chunk(b"sRGB", b"\0") + chunk(b"gAMA", struct.pack(">I", 45455))
OTHER = (
    chunk(b"tEXt", b"License\0Synthetic fixture license")
    + chunk(b"tEXt", b"Software\0Fixture encoder")
    + chunk(b"eXIf", b"II*\0\x08\0\0\0\0\0\0\0\0\0")
    + chunk(b"caBX", b"Synthetic provenance fixture")
)
SENSITIVE = (
    chunk(b"tEXt", b"Author\0Synthetic fixture author")
    + chunk(b"iTXt", b"Description\0\0\0\0\0Synthetic fixture prompt")
    + chunk(b"zTXt", b"Creation Time\0\0" + zlib.compress(b"Fixture date"))
    + chunk(b"iTXt", b"XML:com.adobe.xmp\0\0\0\0\0<fixture/>")
)


def png(metadata: bytes = b"") -> bytes:
    return PNG.PNG_SIGNATURE + HEADER + COLOR + metadata + PIXELS + END


class PngMetadataTest(unittest.TestCase):
    def test_selected_keywords_removed_from_all_text_encodings(self):
        original = png(SENSITIVE + OTHER)
        self.assertEqual(PNG.sensitive_png_keywords(original), sorted(PNG.SENSITIVE_KEYWORDS))
        cleaned = PNG.sanitize_png(original)
        self.assertEqual(cleaned, png(OTHER))
        self.assertEqual(PNG.sensitive_png_keywords(cleaned), [])
        self.assertEqual(PNG.sanitize_png(cleaned), cleaned)

    def test_original_idat_alpha_color_and_unrelated_chunks_are_unchanged(self):
        original = png(SENSITIVE + OTHER)
        cleaned = PNG.sanitize_png(original)
        for raw in [HEADER, COLOR, OTHER, PIXELS, END]:
            self.assertIn(raw, cleaned)
        self.assertEqual(zlib.decompress(IMAGE_DATA), b"\0\x11\x22\x33\x80")

    def test_crc_failure_is_rejected_by_both_public_functions(self):
        corrupt = bytearray(png(SENSITIVE))
        corrupt[len(PNG.PNG_SIGNATURE) + len(HEADER) + 9] ^= 1
        for function in [PNG.sensitive_png_keywords, PNG.sanitize_png]:
            with self.subTest(function=function.__name__), self.assertRaisesRegex(ValueError, "CRC"):
                function(bytes(corrupt))

    def test_invalid_signature_length_header_and_end_are_rejected(self):
        invalid_header = chunk(b"IHDR", struct.pack(">IIBBBBB", 0, 1, 8, 6, 0, 0, 0))
        invalid = [
            b"not a PNG",
            PNG.PNG_SIGNATURE + struct.pack(">I", 0x80000000) + b"IHDR" + b"\0" * 4,
            PNG.PNG_SIGNATURE + chunk(b"IHDR", b"short") + PIXELS + END,
            PNG.PNG_SIGNATURE + invalid_header + PIXELS + END,
            PNG.PNG_SIGNATURE + HEADER + HEADER + PIXELS + END,
            PNG.PNG_SIGNATURE + HEADER + PIXELS,
            PNG.PNG_SIGNATURE + HEADER + PIXELS + chunk(b"IEND", b"x"),
            png() + b"trailing bytes",
            png()[:-1],
        ]
        for data in invalid:
            with self.subTest(length=len(data)), self.assertRaises(ValueError):
                PNG.sanitize_png(data)

    def test_cli_only_replaces_owned_icons_and_preserves_mode(self):
        with tempfile.TemporaryDirectory(prefix="tagshelf-png-test-") as directory:
            root = Path(directory)
            selected = root / "assets/images/icon/icon.png"
            excluded = [root / "assets/images/samples/sample.png", root / "patches/third_party/icon.png"]
            for path in [selected, *excluded]:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(png(SENSITIVE + OTHER))
            selected.chmod(0o640)
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(PNG.main(["--repo", directory]), 1)
                self.assertEqual(PNG.main(["--repo", directory, "--apply"]), 0)
                self.assertEqual(PNG.main(["--repo", directory]), 0)
            self.assertEqual(selected.read_bytes(), png(OTHER))
            self.assertEqual(stat.S_IMODE(selected.stat().st_mode), 0o640)
            for path in excluded:
                self.assertEqual(path.read_bytes(), png(SENSITIVE + OTHER))
            self.assertEqual(list(selected.parent.glob(".*.privacy-*")), [])

    def test_cli_validates_all_files_before_any_replacement(self):
        with tempfile.TemporaryDirectory(prefix="tagshelf-png-test-") as directory:
            root = Path(directory)
            first = root / "assets/images/icon/icon.png"
            broken = root / "web/favicon.png"
            for path in [first, broken]:
                path.parent.mkdir(parents=True, exist_ok=True)
            first.write_bytes(png(SENSITIVE))
            broken.write_bytes(png()[:-1])
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(PNG.main(["--repo", directory, "--apply"]), 1)
            self.assertEqual(first.read_bytes(), png(SENSITIVE))

    def test_cli_refuses_a_symlink_to_sample_images(self):
        with tempfile.TemporaryDirectory(prefix="tagshelf-png-test-") as directory:
            root = Path(directory)
            samples = root / "assets/images/samples"
            samples.mkdir(parents=True)
            sample = samples / "sample.png"
            sample.write_bytes(png(SENSITIVE))
            (root / "assets/images/icon").symlink_to(samples, target_is_directory=True)
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(PNG.main(["--repo", directory, "--apply"]), 1)
            self.assertEqual(sample.read_bytes(), png(SENSITIVE))

    def test_cli_does_not_pass_an_empty_or_wrong_repository(self):
        with tempfile.TemporaryDirectory(prefix="tagshelf-png-test-") as directory:
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(PNG.main(["--repo", directory]), 1)


if __name__ == "__main__":
    unittest.main()
