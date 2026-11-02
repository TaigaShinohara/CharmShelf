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
