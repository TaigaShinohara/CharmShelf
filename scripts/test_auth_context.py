"""Only synthetic profiles and empty temporary files; no credential access."""
import copy
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import project_auth as auth


class AuthContextTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.path = self.root / 'app-a' / 'signing.json'
        self.path.parent.mkdir()
        self.profile = {
            'service': 'fixture', 'environment': 'development',
            'local_auth': {'mode': 'desktop', 'account': 'account-a'},
            'secret_references': {'API_KEY': 'op://fixture/item/field'},
        }
        self.save()
        self.artifact = self.root / 'temporary-signing-file'
        self.artifact.touch()
        (self.root / 'run.py').touch()
        for platform in ('android', 'ios'):
            (self.root / (platform + '_signing.py')).touch()

    def save(self):
        self.path.write_text(json.dumps(self.profile))

    def environment(self, platform):
        env = {'CODEX_AUTH_HOME': str(self.root)}
        for name in auth.SIGNING_FIELDS[platform]:
            env[name] = 'fixture-metadata'
        env[auth.SIGNING_FIELDS[platform][0]] = str(self.artifact)
        env['CODEX_' + platform.upper() + '_SIGNING_V2_ID'] = auth.signing_identity(self.path, platform, env)
        return env

    def test_selector_defaults_and_json_order_are_normalized(self):
        original = auth.profile_identity(self.profile, self.path)
        self.profile['local_auth']['prompt_for_authentication'] = False
        self.assertEqual(original, auth.profile_identity(self.profile, self.path))
        self.profile = dict(reversed(list(self.profile.items())))
        self.assertEqual(original, auth.profile_identity(self.profile, self.path))
        self.profile['verification'] = 'documentation only'
        self.assertEqual(original, auth.profile_identity(self.profile, self.path))

    def test_each_auth_selector_change_requires_resolution(self):
        selectors = [
            {'mode': 'desktop', 'account': 'account-a'},
            {'mode': 'desktop', 'account': 'account-b'},
            {'mode': 'desktop'},
            {'mode': 'desktop', 'account': 'account-a', 'prompt_for_authentication': True},
            {'mode': 'service_account_keychain', 'keychain_service': 'service-a', 'keychain_account': 'account-a'},
            {'mode': 'service_account_keychain', 'keychain_service': 'service-b', 'keychain_account': 'account-a'},
            {'mode': 'service_account_keychain', 'keychain_service': 'service-a', 'keychain_account': 'account-b'},
        ]
        for before in selectors:
            for after in selectors:
                if before == after:
                    continue
                with self.subTest(before=before, after=after):
                    previous = copy.deepcopy(self.profile)
                    previous['local_auth'] = before
                    self.profile['local_auth'] = after
                    self.save()
                    env = {'API_KEY': 'synthetic', auth.PROFILE_MARKER: auth.profile_identity(previous, self.path), 'CODEX_AUTH_HOME': str(self.root)}
                    with patch.dict(os.environ, env, clear=True), patch.object(auth.subprocess, 'call', return_value=9) as call:
                        with self.assertRaises(SystemExit) as stop:
                            auth.ensure(self.path, ['fixture-command'])
                        self.assertEqual(stop.exception.code, 9)
                        self.assertIn('--context-version', call.call_args.args[0])

    def test_same_profile_in_another_project_is_not_reused(self):
        other = self.root / 'app-b' / 'signing.json'
        other.parent.mkdir()
        other.write_text(self.path.read_text())
        env = {'API_KEY': 'synthetic', auth.PROFILE_MARKER: auth.profile_identity(self.profile, self.path), 'CODEX_AUTH_HOME': str(self.root)}
        with patch.dict(os.environ, env, clear=True), patch.object(auth.subprocess, 'call', return_value=0) as call:
            with self.assertRaises(SystemExit):
                auth.ensure(other, ['fixture-command'])
            call.assert_called_once()
        for platform in ('android', 'ios'):
            self.assertFalse(auth.signing_ready(other, platform, self.environment(platform)))

    def test_legacy_marker_never_authorizes_v2_helper(self):
        env = {'API_KEY': 'synthetic', 'CODEX_AUTH_PROFILE_ID': auth.profile_identity(self.profile, self.path), 'CODEX_AUTH_HOME': str(self.root)}
        with patch.dict(os.environ, env, clear=True), patch.object(auth.subprocess, 'call', return_value=0) as call:
            with self.assertRaises(SystemExit):
                auth.ensure(self.path, ['fixture-command'])
            call.assert_called_once()

    def test_matching_signature_reuses_only_its_own_context(self):
        for platform in ('android', 'ios'):
            env = self.environment(platform)
            with patch.dict(os.environ, env, clear=True), patch.object(auth.subprocess, 'call') as call:
                auth.ensure_signing(self.path, platform, ['fixture-command'])
                call.assert_not_called()

    def test_file_without_provenance_reenters_signer_before_application(self):
        for platform in ('android', 'ios'):
            env = self.environment(platform)
            env.pop('CODEX_' + platform.upper() + '_SIGNING_V2_ID')
            with patch.dict(os.environ, env, clear=True), patch.object(auth.subprocess, 'call', return_value=7) as call:
                with self.assertRaises(SystemExit) as stop:
                    auth.ensure_signing(self.path, platform, ['fixture-command'])
                self.assertEqual(stop.exception.code, 7)
                self.assertEqual(call.call_args.args[0][-2:], ['--', 'fixture-command'])
                self.assertIn(platform + '_signing.py', call.call_args.args[0][1])
                self.assertIn('--context-version', call.call_args.args[0])

    def test_signature_account_reference_and_environment_changes_are_rejected(self):
        changes = [('local_auth', {'mode': 'desktop', 'account': 'account-b'}),
                   ('local_auth', {'mode': 'service_account_keychain', 'keychain_service': 'other', 'keychain_account': 'other'}),
                   ('service', 'other-project'), ('environment', 'production'),
                   ('secret_references', {'API_KEY': 'op://different/item/field'})]
        original = copy.deepcopy(self.profile)
        for platform in ('android', 'ios'):
            for field, value in changes:
                with self.subTest(platform=platform, field=field):
                    self.profile = copy.deepcopy(original)
                    self.save()
                    env = self.environment(platform)
                    self.profile[field] = value
                    self.save()
                    self.assertFalse(auth.signing_ready(self.path, platform, env))
        self.profile = original
        self.save()

    def test_changed_signing_path_and_ios_metadata_are_rejected(self):
        other = self.root / 'other-signing-file'
        other.touch()
        for platform in ('android', 'ios'):
            for name in auth.SIGNING_FIELDS[platform]:
                env = self.environment(platform)
                env[name] = str(other) if name == auth.SIGNING_FIELDS[platform][0] else 'different-metadata'
                self.assertFalse(auth.signing_ready(self.path, platform, env))

    def test_removed_material_and_invalid_profile_fail_closed(self):
        contexts = [(platform, self.environment(platform)) for platform in ('android', 'ios')]
        self.artifact.unlink()
        for platform, env in contexts:
            self.assertFalse(auth.signing_ready(self.path, platform, env))
        self.artifact.touch()
        for data in ('{', 'null', '[]', '{"local_auth":null}', '{"local_auth":{"mode":"unknown"}}'):
            self.path.write_text(data)
            for platform, env in contexts:
                self.assertFalse(auth.signing_ready(self.path, platform, env))


if __name__ == '__main__':
    unittest.main()
