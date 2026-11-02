import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec=importlib.util.spec_from_file_location("flutter_local",Path(__file__).with_name("flutter_local.py"))
launcher=importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)

@unittest.skipUnless(os.name=="posix","The optional launcher targets macOS/Linux")
class LocalJdkSelectionTests(unittest.TestCase):
    def setUp(self):
        self.temporary=tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root=Path(self.temporary.name)

    def jdk(self,name,status):
        home=self.root/name
        binary=home/"bin/java";binary.parent.mkdir(parents=True)
        binary.write_text(f"#!/bin/sh\nexit {status}\n")
        binary.chmod(0o700)
        return str(home)

    def test_unusable_inherited_jdk_uses_working_system_jdk(self):
        inherited=self.jdk("stale-intel",126)
        working=self.jdk("working-arm",0)
        before=os.environ.get("JAVA_HOME")
        with patch.object(launcher,"system_java_home",return_value=working):
            self.assertEqual(launcher.select_java_home(None,inherited),str(Path(working).resolve()))
        self.assertEqual(os.environ.get("JAVA_HOME"),before)

    def test_explicit_unusable_jdk_does_not_silently_change_user_choice(self):
        with patch.object(launcher,"system_java_home") as discover:
            with self.assertRaises(SystemExit):launcher.select_java_home(self.jdk("explicit",126),None)
        discover.assert_not_called()

    def test_working_inherited_jdk_is_preserved(self):
        working=self.jdk("preferred",0)
        with patch.object(launcher,"system_java_home") as discover:
            self.assertEqual(launcher.select_java_home(None,working),str(Path(working).resolve()))
        discover.assert_not_called()

if __name__=="__main__":unittest.main()
