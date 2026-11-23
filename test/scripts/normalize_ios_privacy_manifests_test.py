import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / "scripts/maintenance/normalize_ios_privacy_manifests.py"
SPEC = importlib.util.spec_from_file_location("normalize_privacy", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class NormalizePrivacyManifestsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.archive = Path(self.temp.name) / "Runner.xcarchive"
        self.app = self.archive / "Products/Applications/Runner.app"
        self.app.mkdir(parents=True)

    def manifest(self, name, values, fmt=plistlib.FMT_XML):
        bundle = self.app / (name + ".bundle")
        bundle.mkdir()
        (bundle / "Info.plist").write_bytes(plistlib.dumps({"CFBundlePackageType": "BNDL"}))
        path = bundle / "PrivacyInfo.xcprivacy"
        path.write_bytes(plistlib.dumps(values, fmt=fmt, sort_keys=False))
        return path

    def test_only_removes_empty_accessed_types(self):
        fields = {"NSPrivacyAccessedAPITypes": [], "NSPrivacyTracking": False, "NSPrivacyCollectedDataTypes": []}
        empty = self.manifest("empty", fields, plistlib.FMT_BINARY)
        reason = {"NSPrivacyAccessedAPITypes": [{
            "NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults",
            "NSPrivacyAccessedAPITypeReasons": ["CA92.1"],
        }]}
        nonempty = self.manifest("declared", reason)
        original = nonempty.read_bytes()
        self.assertEqual(MODULE.normalize(self.archive), ["empty.bundle/PrivacyInfo.xcprivacy"])
        self.assertTrue(empty.read_bytes().startswith(b"bplist00"))
        self.assertEqual(plistlib.loads(empty.read_bytes()),
                         {"NSPrivacyTracking": False, "NSPrivacyCollectedDataTypes": []})
        self.assertEqual(nonempty.read_bytes(), original)
        self.assertEqual(MODULE.normalize(self.archive), [])

    def test_validation_precedes_modification_and_preserves_signed_bundle(self):
        first = self.manifest("a-unsigned", {"NSPrivacyAccessedAPITypes": []})
        signed = self.manifest("z-signed", {"NSPrivacyAccessedAPITypes": []})
        (signed.parent / "_CodeSignature").mkdir()
        with self.assertRaisesRegex(ValueError, "resource bundle is signed"):
            MODULE.normalize(self.archive)
        self.assertEqual(plistlib.loads(first.read_bytes()), {"NSPrivacyAccessedAPITypes": []})
        self.assertEqual(plistlib.loads(signed.read_bytes()), {"NSPrivacyAccessedAPITypes": []})

    def test_signed_app_is_rejected(self):
        (self.app / "_CodeSignature").mkdir()
        with self.assertRaisesRegex(ValueError, "app bundle is signed"):
            MODULE.normalize(self.archive)


if __name__ == "__main__":
    unittest.main()
