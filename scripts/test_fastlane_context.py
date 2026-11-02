"""Actual launcher reentry with synthetic profiles and no credential/tool access."""
import copy
import json
import os
from pathlib import Path
import runpy
import sys
import tempfile
import unittest
from unittest.mock import patch
import project_auth as auth

ROOT = Path(__file__).resolve().parents[1]


class FastlaneContextTests(unittest.TestCase):
    def test_launchers_reject_foreign_signing_before_api_and_fastlane(self):
        template = (ROOT / 'scripts/fastlane_1password.py').is_file()
        for platform in ('android', 'ios'):
            for kind in ('matching', 'unmarked', 'other-account', 'other-project'):
                with self.subTest(platform=platform, kind=kind), tempfile.TemporaryDirectory() as folder:
                    temporary = Path(folder)
                    material = temporary / 'signing-material'
                    material.touch()
                    (temporary / (platform + '_signing.py')).touch()
                    profile = {'service': 'fixture', 'environment': 'development', 'local_auth': {'mode': 'desktop', 'account': 'account-a'}, 'secret_references': {'API_KEY': 'op://fixture/item/field'}}
                    signing_path = ROOT / 'auth' / (platform + '-signing.local.json')
                    prefix = 'template-' if template else 'tagshelf-'
                    api_path = ROOT / 'auth' / (prefix + ('app-store' if platform == 'ios' else 'google-play') + '.local.json')
                    env = {'CODEX_AUTH_HOME': folder, 'API_KEY': 'synthetic', auth.PROFILE_MARKER: auth.profile_identity(profile, api_path)}
                    env.update({name: 'fixture-metadata' for name in auth.SIGNING_FIELDS[platform]})
                    env[auth.SIGNING_FIELDS[platform][0]] = str(material)
                    foreign = copy.deepcopy(profile)
                    if kind == 'other-account':
                        foreign['local_auth']['account'] = 'account-b'
                    path = temporary / 'other-project.json' if kind == 'other-project' else signing_path
                    with patch.object(Path, 'read_text', return_value=json.dumps(foreign)):
                        env['CODEX_' + platform.upper() + '_SIGNING_V2_ID'] = auth.signing_identity(path, platform, env)
                    if kind == 'unmarked':
                        env.pop('CODEX_' + platform.upper() + '_SIGNING_V2_ID')
                    entry = ROOT / 'scripts' / ('fastlane_1password.py' if template else 'fastlane_' + platform + '_1password.py')
                    args = [str(entry), *(['--', platform] if template else []), 'fixture']
                    # Profile reads return fixtures; no local reference file is read.
                    with patch.dict(os.environ, env, clear=True), patch.object(Path, 'read_text', return_value=json.dumps(profile)), patch.object(sys, 'argv', args), patch('subprocess.call', return_value=7) as call:
                        with self.assertRaises(SystemExit) as stop:
                            runpy.run_path(str(entry), run_name='__main__')
                        self.assertEqual(stop.exception.code, 7)
                        call.assert_called_once()
                        command = call.call_args.args[0]
                        if kind == 'matching':
                            self.assertEqual(command, ['bundle', 'exec', 'fastlane', platform, 'fixture'])
                        else:
                            self.assertEqual(command[1], str(temporary / (platform + '_signing.py')))
                            self.assertIn(str(signing_path), command)
                            self.assertIn('--context-version', command)


if __name__ == '__main__':
    unittest.main()
