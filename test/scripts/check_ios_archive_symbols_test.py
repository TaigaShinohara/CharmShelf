"""Reject the UUID-matching empty dSYM produced by objective_c 9.3.0."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[2] / 'scripts/maintenance/check_ios_archive.py'
spec = importlib.util.spec_from_file_location('archive_check', SOURCE)
archive_check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(archive_check)


class ObjectiveCSymbolsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.archive = Path(self.temp.name)
        self.app = self.archive / 'Products/Applications/Runner.app'
        self.binary = self.app / 'Frameworks/objective_c.framework/objective_c'
        self.binary.parent.mkdir(parents=True)
        self.binary.touch()
        for name in ('Runner.app.dSYM', 'App.framework.dSYM', 'objective_c.framework.dSYM'):
            (self.archive / 'dSYMs' / name).mkdir(parents=True)

    def run_check(self, debug_info):
        def run(command, **kwargs):
            output = 'UUID: 12345678-1234-1234-1234-123456789ABC (arm64) binary'
            if '--debug-info' in command:
                output = debug_info
            return subprocess.CompletedProcess(command, 0, stdout=output, stderr='')
        with patch.object(archive_check.subprocess, 'run', side_effect=run):
            archive_check.check_debug_symbols(self.archive, self.app)

    def test_rejects_matching_uuid_without_compile_units(self):
        with self.assertRaisesRegex(ValueError, 'デバッグ情報がありません'):
            self.run_check('file format Mach-O arm64\n.debug_info contents:\n')

    def test_accepts_actual_compile_unit(self):
        self.run_check('0x0000000b: DW_TAG_compile_unit')

    def test_rejects_missing_objective_c_dsym(self):
        (self.archive / 'dSYMs/objective_c.framework.dSYM').rmdir()
        with self.assertRaisesRegex(ValueError, 'dSYMがありません'):
            self.run_check('DW_TAG_compile_unit')


if __name__ == '__main__':
    unittest.main()
