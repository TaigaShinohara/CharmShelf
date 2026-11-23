"""Unconfigured public export paths must stop before credential or build access."""
import os
from pathlib import Path
import plistlib
import runpy
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import check_distribution_config as config

ROOT = Path(__file__).resolve().parents[1]


class DistributionBoundaryTests(unittest.TestCase):
    def test_local_export_options_check_the_exact_installed_distribution_identity(self):
        certificate = 'A' * 40
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            options = root / 'Local Export Options.plist'
            options.write_bytes(plistlib.dumps({
                'method': 'app-store-connect',
                'destination': 'export',
                'signingStyle': 'manual',
                'teamID': 'TESTTEAM01',
                'signingCertificate': certificate,
                'provisioningProfiles': {'org.charmshelf.opensource': 'CharmShelf Distribution'},
            }))
            with patch.object(config.subprocess, 'run') as security:
                config.require_distribution_config('ios', root, ios_export_options=options)
                security.assert_not_called()
                security.return_value.stdout = (
                    f'  1) {certificate} "Apple Distribution: Test Team (TESTTEAM01)"\n'
                )
                config.require_distribution_config(
                    'ios', root, ios_export_options=options, check_installed_signing=True,
                )
                security.assert_called_once_with(
                    ['security', 'find-identity', '-v', '-p', 'codesigning'],
                    check=True, capture_output=True, text=True, timeout=20,
                )
                security.return_value.stdout = (
                    f'  1) {certificate} "Apple Development: Test Team (TESTTEAM01)"\n'
                    f'  2) {"B" * 40} "Apple Distribution: Test Team (TESTTEAM01)"\n'
                )
                with self.assertRaisesRegex(SystemExit, 'IOS_DISTRIBUTION_IDENTITY_UNAVAILABLE'):
                    config.require_distribution_config(
                        'ios', root, ios_export_options=options, check_installed_signing=True,
                    )

    def test_placeholder_ios_launcher_does_not_resolve_credentials(self):
        entry = ROOT / 'scripts/fastlane_ios_1password.py'
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'scripts').mkdir()
            (root / 'scripts/ios_export_options.plist').write_bytes(
                plistlib.dumps({'teamID': 'YOUR_APPLE_TEAM_ID'})
            )
            with patch.object(config, 'ROOT', root), patch.object(sys, 'argv', [str(entry), 'beta']), patch('project_auth.ensure') as api, patch('project_auth.ensure_signing') as signing, patch('subprocess.call') as invoke:
                with self.assertRaisesRegex(SystemExit, 'DISTRIBUTION_NOT_CONFIGURED'):
                    runpy.run_path(str(entry), run_name='__main__')
                api.assert_not_called()
                signing.assert_not_called()
                invoke.assert_not_called()

    @unittest.skipUnless(shutil.which('zsh'), 'zsh is only required for optional local release helpers')
    def test_placeholder_ios_export_stops_before_signing_or_flutter(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / 'scripts'
            scripts.mkdir()
            tools = root / 'tools'
            tools.mkdir()
            (tools / 'python3').symlink_to(sys.executable)
            for name in ('build_ios_release_candidate.zsh', 'check_distribution_config.py'):
                shutil.copyfile(ROOT / 'scripts' / name, scripts / name)
            (scripts / 'ios_export_options.plist').write_bytes(
                plistlib.dumps({'teamID': 'YOUR_APPLE_TEAM_ID'})
            )
            result = subprocess.run(
                [shutil.which('zsh'), str(scripts / 'build_ios_release_candidate.zsh'), '1.0.0', '1', '--export'],
                env={'PATH': str(tools) + os.pathsep + '/usr/bin:/bin', 'PYTHONDONTWRITEBYTECODE': '1'},
                text=True, capture_output=True,
            )
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertIn('DISTRIBUTION_NOT_CONFIGURED', result.stderr)
            self.assertNotIn('No such file', result.stderr)


if __name__ == '__main__':
    unittest.main()
