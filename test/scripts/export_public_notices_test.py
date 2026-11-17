"""iOS native license export must normalize line endings to match SwiftPM export."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

MODULE_PATH = Path(__file__).resolve().parents[2] / 'scripts/maintenance/export_public_notices.py'
SPEC = importlib.util.spec_from_file_location('export_public_notices', MODULE_PATH)
EXPORT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(EXPORT)


class ExportPublicNoticesTest(unittest.TestCase):
    def test_ios_entries_normalizes_crlf_license_text(self):
        with tempfile.TemporaryDirectory(prefix='charmshelf-public-notices-') as directory:
            root = Path(directory)
            plugin_dir = root / 'plugin_a'
            plugin_dir.mkdir()
            (plugin_dir / 'LICENSE').write_bytes(b'MIT License\r\n\r\nCopyright\r\n')
            (root / '.flutter-plugins-dependencies').write_text(
                json.dumps({'plugins': {'ios': [{'name': 'plugin_a', 'native_build': True}]}}),
                encoding='utf-8',
            )
            ios_output = root / 'ios_native_licenses.json'
            retained = [
                {'package': name, 'text': f'{name} text'}
                for name in sorted(EXPORT.SWIFT_EXTRA_NAMES)
            ]
            ios_output.write_text(json.dumps(retained), encoding='utf-8')

            with patch.object(EXPORT, 'ROOT', root), patch.object(EXPORT, 'IOS_OUTPUT', ios_output):
                entries = EXPORT.ios_entries({'plugin_a': plugin_dir})

            by_package = {entry['package']: entry['text'] for entry in entries}
            self.assertEqual(by_package['plugin_a'], 'MIT License\n\nCopyright\n')


if __name__ == '__main__':
    unittest.main()
