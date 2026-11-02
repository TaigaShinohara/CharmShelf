import base64
import os
from pathlib import Path
import stat
import tempfile
import unittest
import prepare_android_signing as signing


class SigningFilesTests(unittest.TestCase):
    def environment(self, folder):
        return {'RUNNER_TEMP':folder,'GITHUB_ENV':str(Path(folder)/'job.env'),
                'KEY_PROPERTIES_BASE64':base64.b64encode(b'storeFile=old\nstorePassword=dummy-secret\nkeyAlias=test\nkeyPassword=dummy-key\n').decode(),
                'KEYSTORE_BASE64':base64.b64encode(b'dummy-keystore').decode()}
    def test_private_files_and_only_metadata_exported_then_cleanup(self):
        with tempfile.TemporaryDirectory() as root:
            env=self.environment(root);signing.prepare(env);folder=signing.folder(env)
            self.assertEqual(stat.S_IMODE(folder.stat().st_mode),0o700)
            for p in folder.iterdir():self.assertEqual(stat.S_IMODE(p.stat().st_mode),0o600)
            properties=(folder/'key.properties').read_text()
            self.assertIn(str(folder/'release.keystore'),properties)
            exported=Path(env['GITHUB_ENV']).read_text()
            self.assertNotIn('dummy-',exported)
            self.assertIn('configuration-cache=false',exported)
            signing.clean(env);self.assertFalse(folder.exists())
    def test_invalid_material_creates_no_directory(self):
        with tempfile.TemporaryDirectory() as root:
            env=self.environment(root);env['KEYSTORE_BASE64']='invalid!'
            with self.assertRaises(ValueError):signing.prepare(env)
            self.assertFalse(signing.folder(env).exists())
    def test_environment_write_failure_cleans_files(self):
        with tempfile.TemporaryDirectory() as root:
            env=self.environment(root);env['GITHUB_ENV']=root
            with self.assertRaises(OSError):signing.prepare(env)
            self.assertFalse(signing.folder(env).exists())
    def test_preexisting_directory_is_not_overwritten_or_removed(self):
        with tempfile.TemporaryDirectory() as root:
            env=self.environment(root);folder=signing.folder(env);folder.mkdir();marker=folder/'keep';marker.write_text('existing')
            with self.assertRaises(FileExistsError):signing.prepare(env)
            self.assertEqual(marker.read_text(),'existing')
    def test_cleanup_does_not_follow_directory_symlink(self):
        with tempfile.TemporaryDirectory() as root,tempfile.TemporaryDirectory() as other:
            env=self.environment(root);Path(other,'key.properties').write_text('existing')
            signing.folder(env).symlink_to(other)
            with self.assertRaises(ValueError):signing.clean(env)
            self.assertTrue(Path(other,'key.properties').exists())


if __name__=='__main__':unittest.main()
