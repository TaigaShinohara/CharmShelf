"""SDK license fallback must not hide missing third-party notices."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

MODULE_PATH = Path(__file__).resolve().parents[2] / 'scripts/maintenance/export_ios_licenses.py'
SPEC = importlib.util.spec_from_file_location('export_ios_licenses', MODULE_PATH)
EXPORT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(EXPORT)


class SdkLicenseTest(unittest.TestCase):
    def test_sdk_test_plugin_inherits_license_but_foreign_package_does_not(self):
        with tempfile.TemporaryDirectory(prefix='tagshelf-license-test-') as directory:
            root = Path(directory)
            flutter = root / 'packages/flutter'
            plugin = root / 'packages/integration_test'
            flutter.mkdir(parents=True)
            plugin.mkdir()
            (root / 'LICENSE').write_text('SDK license fixture')
            (root / '.flutter-plugins-dependencies').write_text(json.dumps({
                'plugins': {'ios': [{'name': 'integration_test', 'native_build': True,
                                     'dev_dependency': True}]}}))
            roots = {'flutter': flutter, 'integration_test': plugin}
            with patch.object(EXPORT, 'ROOT', root), \
                    patch.object(EXPORT, 'package_roots', return_value=roots), \
                    patch.object(EXPORT, 'LOCAL_SWIFT_PACKAGES', {}), \
                    patch.object(EXPORT, 'REMOTE_SWIFT_PACKAGES', {}):
                self.assertEqual(EXPORT.create_entries(root), [
                    {'package': 'integration_test', 'text': 'SDK license fixture'}])
                roots['integration_test'] = root / 'foreign/integration_test'
                with self.assertRaises(FileNotFoundError):
                    EXPORT.create_entries(root)
                roots.pop('integration_test')
                with self.assertRaises(ValueError):
                    EXPORT.create_entries(root)


if __name__ == '__main__':
    unittest.main()
