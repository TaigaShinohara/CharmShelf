"""Release-content checks must fail closed without exposing the matched values."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import struct
import tempfile
import unittest
from unittest.mock import patch
import zipfile

MAINTENANCE = Path(__file__).resolve().parents[2] / "scripts/maintenance"
sys.path.insert(0, str(MAINTENANCE))
SPEC = importlib.util.spec_from_file_location("check_private_content", MAINTENANCE / "check_private_content.py")
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)


class ContentPrivacyTest(unittest.TestCase):
    def make_sources(self, root, address):
        (root / 'template_config.yaml').write_text(f'company:\n  email: "{address}"\n')
        for lang in ('ja', 'en'):
            path = root / f'lib/l10n_src/{lang}/template.arb'
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps({key: address for key in CHECK.POLICY_KEYS}))
        for name in CHECK.PUBLIC_DOCS:
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(address)

    def test_paths_and_tokens_in_utf8_and_utf16_but_not_route_or_ci_path(self):
        value = "/Users/privacy-fixture/Documents/photo.jpg"
        for encoding in ("utf-8", "utf-16le", "utf-16be"):
            with self.subTest(encoding=encoding):
                self.assertIn("personal-home-path", CHECK.blob_issues(value.encode(encoding)))
        self.assertFalse(CHECK.blob_issues(b"/home/library/book /Users/runner/work/public-project"))
        token = "ghp_" + "A" * 36
        self.assertIn("github-token", CHECK.blob_issues(token.encode()))
        self.assertFalse(CHECK.blob_issues(("_symbol_" + token + "_symbol").encode()))

    def test_escaped_service_account_key_and_generic_json_credentials(self):
        key = '-----BEGIN PRIVATE KEY-----\n' + 'A' * 100 + '\n-----END PRIVATE KEY-----'
        data = json.dumps({'private_key': key}).encode()
        self.assertIn('private-key', CHECK.blob_issues(data))
        self.assertIn('embedded-credential-value', CHECK.json_credential_issues(data))
        self.assertIn('embedded-credential-value', CHECK.json_credential_issues(json.dumps({'apiKey': 'synthetic opaque credential'}).encode()))
        self.assertFalse(CHECK.json_credential_issues(json.dumps({'password': '${PASSWORD}', 'private_key': 'op://fixture/item/field'}).encode()))

    def test_copy_inventory_includes_untracked_generated_sources_and_assets(self):
        address = 'public+support@example.test'
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.make_sources(root, address)
            (root / 'lib/local.dart').write_text('"' + 'ghp_' + 'A' * 36 + '"')
            (root / 'assets').mkdir()
            (root / 'assets/local.json').write_text(json.dumps({'password': 'synthetic private value'}))
            # Simulate Git listing none of these working-tree/generated files.
            listed = __import__('subprocess').CompletedProcess([], 0, stdout=b'', stderr=b'')
            with patch.object(CHECK.subprocess, 'run', return_value=listed):
                issues, _ = CHECK.source_issues(root, address)
            self.assertIn(('lib/local.dart', 'github-token'), issues)
            self.assertIn(('assets/local.json', 'embedded-credential-value'), issues)

    def test_first_party_contact_gate_and_narrow_vendor_filename_exceptions(self):
        address = 'public+support@example.test'
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.make_sources(root, address)
            (root / 'lib/private.dart').write_text('"person@gmail.com" "090' + '12345678"')
            issues, _ = CHECK.source_issues(root, address)
            self.assertIn(('lib/private.dart', 'unapproved-contact-address'), issues)
            self.assertIn(('lib/private.dart', 'personal-phone-shape'), issues)
        self.assertTrue(CHECK.approved_contact('Icon-App-20x20@2x.png', address, 'drive.log'))
        self.assertTrue(CHECK.approved_contact('sales@syncfusion.com', address, 'docs/release/LICENSE_AUDIT_2026-08-31.md'))
        self.assertFalse(CHECK.approved_contact('sales@syncfusion.com', address, 'lib/feature.dart'))

    def test_directory_links_and_tracked_descendants_never_read_outside_root(self):
        address = 'public@example.test'
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            root = parent / 'project'
            root.mkdir()
            self.make_sources(root, address)
            outside = parent / 'outside'
            outside.mkdir()
            (outside / 'private.json').write_text(json.dumps({'password': 'synthetic private value'}))
            (root / 'assets').mkdir()
            (root / 'assets/private_link').symlink_to(outside, target_is_directory=True)
            listed = __import__('subprocess').CompletedProcess([], 0, stdout=b'assets/private_link/private.json\0', stderr=b'')
            with patch.object(CHECK.subprocess, 'run', return_value=listed):
                issues, _ = CHECK.source_issues(root, address)
            self.assertIn(('assets/private_link', 'unchecked-source-symlink'), issues)
            self.assertIn(('assets/private_link/private.json', 'unchecked-source-symlink'), issues)
            self.assertFalse(CHECK.safe_source(root, 'assets/private_link/private.json'))
            with self.assertRaises(ValueError):
                CHECK.source_bytes(root, 'assets/private_link/private.json')

    def test_diagnostic_location_masks_value_and_control_characters(self):
        secret = 'ghp_' + 'A' * 36
        location = CHECK.safe_location('assets/person@gmail.com/' + secret + '\nfile.json')
        self.assertNotIn(secret, location)
        self.assertNotIn('person@gmail.com', location)
        self.assertNotIn('\n', location)

    def test_malformed_policy_and_encrypted_archive_fail_without_traceback(self):
        output = io.StringIO()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.make_sources(root, 'public@example.test')
            policy = root / 'lib/l10n_src/en/template.arb'
            values = json.loads(policy.read_text())
            values[CHECK.POLICY_KEYS[0]] = 42
            policy.write_text(json.dumps(values))
            with patch.object(sys, 'argv', ['check_private_content.py', '--root', directory]), \
                    contextlib.redirect_stderr(output):
                self.assertEqual(CHECK.main(), 2)
            archive = root / 'encrypted.zip'
            secret = 'ghp_' + 'A' * 36
            with zipfile.ZipFile(archive, 'w') as out:
                out.writestr(secret, 'fixture')
            data = bytearray(archive.read_bytes())
            struct.pack_into('<H', data, 6, 1)
            central = data.index(b'PK\x01\x02')
            struct.pack_into('<H', data, central + 8, 1)
            archive.write_bytes(data)
            with patch.object(sys, 'argv', ['check_private_content.py', '--archive', str(archive)]), \
                    patch.object(CHECK, 'configured_email', return_value='public@example.test'), \
                    patch.object(CHECK, 'source_issues', return_value=([], 0)), \
                    contextlib.redirect_stderr(output), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(CHECK.main(), 2)
            self.assertNotIn(secret, output.getvalue())
        self.assertNotIn('Traceback', output.getvalue())

    def test_secret_filenames_and_explicit_template_exception(self):
        for path in ("assets/.env", "base/.env.production", "assets/signing.p8", "foo/upload.keystore"):
            self.assertTrue(CHECK.sensitive_filename(path))
        self.assertFalse(CHECK.sensitive_filename("auth/.env.example"))

    def test_archive_checks_all_abis_and_requires_configured_contact(self):
        address = "public+support@example.test"
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "fixture.aab"
            with zipfile.ZipFile(archive, "w") as out:
                out.writestr("base/lib/arm64-v8a/libapp.so", address)
                out.writestr("base/lib/x86_64/libisar.so", "/Users/privacy-fixture/src/lib.rs")
                out.writestr("base/assets/upload.jks", b"fixture")
            issues, count = CHECK.archive_issues(archive, address)
            self.assertEqual(count, 3)
            self.assertIn(("base/lib/x86_64/libisar.so", "personal-home-path"), issues)
            self.assertIn(("base/assets/upload.jks", "secret-file"), issues)
            self.assertNotIn((archive.name, "configured-contact-missing"), issues)
            issues, _ = CHECK.archive_issues(archive, "other@example.test")
            self.assertIn((archive.name, "configured-contact-missing"), issues)

    def test_policy_contact_drift_and_old_representative_field(self):
        address = "public+support@example.test"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for lang in ("ja", "en"):
                path = root / f"lib/l10n_src/{lang}/template.arb"
                path.parent.mkdir(parents=True)
                path.write_text(json.dumps({key: address for key in CHECK.POLICY_KEYS}))
            for name in CHECK.PUBLIC_DOCS:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(address)
            self.assertFalse(CHECK.policy_issues(root, address))
            path = root / "lib/l10n_src/en/template.arb"
            values = json.loads(path.read_text())
            values[CHECK.POLICY_KEYS[0]] = "old@example.test"
            values[CHECK.POLICY_KEYS[1]] += "\nRepresentative: synthetic fixture"
            path.write_text(json.dumps(values))
            issues = CHECK.policy_issues(root, address)
            self.assertTrue(any(label == "public-contact-mismatch" for _, label in issues))
            self.assertTrue(any(label == "personal-representative-field" for _, label in issues))

    def test_cli_does_not_print_sensitive_value_or_traceback(self):
        secret = "synthetic-secret-value"
        output = io.StringIO()
        with patch.object(sys, "argv", ["check_private_content.py"]), \
                patch.object(CHECK, "configured_email", side_effect=ValueError(secret)), \
                contextlib.redirect_stderr(output):
            self.assertEqual(CHECK.main(), 2)
        self.assertNotIn(secret, output.getvalue())
        self.assertNotIn("Traceback", output.getvalue())


if __name__ == "__main__":
    unittest.main()
