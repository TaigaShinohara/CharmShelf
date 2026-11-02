"""Exercise the real shell/helper boundary with synthetic files and tool stubs."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
import project_auth

ROOT = Path(__file__).resolve().parents[1]


class SigningEntrypointTests(unittest.TestCase):
    def run_entry(self, kind):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            scripts = folder / 'scripts'
            (scripts / 'maintenance').mkdir(parents=True)
            (folder / 'auth').mkdir()
            (folder / 'android').mkdir()
            fingerprint = 'YOUR_UPLOAD_CERTIFICATE_SHA256' if kind == 'unconfigured' else ':'.join(['AB'] * 32)
            (folder / 'android/upload_certificate.sha256').write_text(fingerprint)
            for name in ('build_signed_android_release.zsh', 'project_auth.py', 'check_distribution_config.py', 'maintenance/check_flutter_version.sh'):
                shutil.copyfile(ROOT / 'scripts' / name, scripts / name)
            (scripts / 'maintenance/check_private_content.py').write_text('print("PRIVACY_CHECK_STUB")\n')
            (folder / 'pubspec.yaml').write_text('environment:\n  flutter: 3.47.5\n')
            (folder / 'pubspec.lock').write_text('# synthetic\n')
            profile = folder / 'auth/android-signing.local.json'
            data = {'service': 'fixture', 'environment': 'development', 'local_auth': {'mode': 'desktop', 'account': 'account-a'}, 'secret_references': {'KEYSTORE_BASE64': 'op://fixture/item/field'}}
            profile.write_text(json.dumps(data))
            flutter = folder / 'flutter'
            flutter.write_text('#!/bin/sh\nif [ "$1" = "--version" ]; then printf \'{"frameworkVersion":"3.47.5"}\\n\'; else echo BUILD_STUB_REACHED; exit 91; fi\n')
            flutter.chmod(0o700)
            python = folder / 'python3'
            python.write_text('#!' + sys.executable + '\nimport json,os,sys\n'
                              'if sys.argv[1:2] == ["scripts/android_signing_1password.py"]:\n'
                              ' print("SIGNING_DISPATCH="+json.dumps(sys.argv[1:]));sys.exit(7)\n'
                              'os.execv(sys.executable,[sys.executable,*sys.argv[1:]])\n')
            python.chmod(0o700)
            env = {'PATH': str(folder) + ':/usr/bin:/bin', 'HOME': str(folder), 'FLUTTER_BIN': str(flutter), 'PYTHONDONTWRITEBYTECODE': '1'}
            material = folder / 'key.properties'
            material.touch()
            if kind != 'absent':
                env['CODEX_ANDROID_KEY_PROPERTIES'] = str(material)
            if kind in ('matching', 'other-account', 'other-project'):
                env['CODEX_ANDROID_SIGNING_V2_ID'] = project_auth.signing_identity(profile, 'android', env)
            if kind == 'other-account':
                data['local_auth']['account'] = 'account-b'
                profile.write_text(json.dumps(data))
            if kind == 'other-project':
                other = folder / 'other-project.json'
                other.write_text(profile.read_text())
                env['CODEX_ANDROID_SIGNING_V2_ID'] = project_auth.signing_identity(other, 'android', env)
            if kind == 'missing':
                material.unlink()
            return subprocess.run(['/bin/zsh', str(scripts / 'build_signed_android_release.zsh'), '--build-name=1.2.3'], env=env, text=True, capture_output=True)

    def test_absent_missing_or_foreign_signing_reenters_before_build(self):
        for kind in ('absent', 'missing', 'unmarked', 'other-account', 'other-project'):
            with self.subTest(kind=kind):
                result = self.run_entry(kind)
                self.assertEqual(result.returncode, 7, result.stderr)
                self.assertNotIn('BUILD_STUB_REACHED', result.stdout)
                line = next(x for x in result.stdout.splitlines() if x.startswith('SIGNING_DISPATCH='))
                args = json.loads(line.partition('=')[2])
                self.assertEqual(args[:5], ['scripts/android_signing_1password.py', '--context-version', '2', '--', '/bin/zsh'])
                self.assertEqual(args[-1], '--build-name=1.2.3')

    def test_unconfigured_distribution_stops_before_auth_or_build(self):
        result = self.run_entry('unconfigured')
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn('DISTRIBUTION_NOT_CONFIGURED', result.stderr)
        self.assertNotIn('BUILD_STUB_REACHED', result.stdout)
        self.assertNotIn('SIGNING_DISPATCH=', result.stdout)

    def test_matching_signing_reaches_only_the_fake_build(self):
        result = self.run_entry('matching')
        self.assertEqual(result.returncode, 91, result.stderr)
        self.assertIn('BUILD_STUB_REACHED', result.stdout)
        self.assertNotIn('SIGNING_DISPATCH=', result.stdout)


if __name__ == '__main__':
    unittest.main()
