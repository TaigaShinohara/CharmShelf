"""Publication-boundary regressions; no real credentials, builds or uploads."""
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys
import unittest
from unittest.mock import patch

import google_play_publication as policy

ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = (ROOT / "scripts/fastlane_1password.py").is_file()
RUBY = os.environ.get("RUBY_BIN") or ("/usr/bin/ruby" if Path("/usr/bin/ruby").is_file() else shutil.which("ruby"))



class PublicationBoundaryTests(unittest.TestCase):
    def test_launcher_blocks_all_upload_lanes_before_authentication(self):
        path = ROOT / "scripts" / ("fastlane_1password.py" if TEMPLATE else "fastlane_android_1password.py")
        for lane in sorted(policy.PUBLISH_LANES):
            for prepared in (False, True):
                env = {"CI": "true", "CODEX_AUTH_PROFILE": "template-google-play"}
                if prepared:
                    env["CODEX_ANDROID_KEY_PROPERTIES"] = "/fixture/already-prepared"
                args = [str(path), *(["--", "android"] if TEMPLATE else []), lane]
                with self.subTest(lane=lane, prepared=prepared), patch.dict(os.environ, env, clear=True), patch.object(sys, "argv", args), patch("project_auth.ensure") as ensure, patch("subprocess.call") as launch, patch.object(Path, "read_text", side_effect=AssertionError("must not read a profile")):
                    with self.assertRaisesRegex(SystemExit, "GOOGLE_PLAY_PUBLICATION_BLOCKED"):
                        runpy.run_path(str(path), run_name="__main__")
                    ensure.assert_not_called()
                    launch.assert_not_called()

    def test_read_only_checker_still_reaches_only_the_checker(self):
        path = ROOT / "scripts" / ("google_play_1password.py" if TEMPLATE else "fastlane_android_1password.py")
        args = [str(path), *([] if TEMPLATE else ["--check-auth"])]
        with patch.dict(os.environ, {}, clear=True), patch.object(sys, "argv", args), patch.object(Path, "is_file", return_value=True), patch("project_auth.ensure") as ensure, patch("subprocess.call", return_value=0) as launch:
            with self.assertRaises(SystemExit) as caught:
                runpy.run_path(str(path), run_name="__main__")
            self.assertEqual(caught.exception.code, 0)
            ensure.assert_called_once()
            launch.assert_called_once()
            self.assertTrue(launch.call_args.args[0][-1].endswith("google_play_check.py"))

    def test_firebase_is_not_enabled_or_blocked_by_play_policy(self):
        result = subprocess.run([sys.executable, str(ROOT / "scripts/google_play_publication.py"), "firebase"], capture_output=True)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, b"")
        self.assertEqual(result.stderr, b"")

    def test_unknown_workflow_lane_is_rejected(self):
        result = subprocess.run([sys.executable, str(ROOT / "scripts/google_play_publication.py"), "unexpected"], capture_output=True)
        self.assertEqual(result.returncode, 2)

    @unittest.skipUnless(RUBY, "Ruby is only required for optional Fastlane lane checks")
    def test_direct_fastlane_lanes_stop_before_build_and_credentials(self):
        # Load only the lane DSL. All real Fastlane actions are forbidden; the
        # only permitted child process is the credential-free policy check.
        harness = r'''
require "open3"
class PublicationStopped < StandardError; end
module UI
  def self.user_error!(message); raise "Unexpected action: #{message}"; end
end
$lanes = {}; $before = {}; $platform = nil
def default_platform(*); end
def desc(*); end
def platform(name)
  previous = $platform; $platform = name; yield; $platform = previous
end
def lane(name, &block); $lanes[[$platform, name]] = block; end
def before_all(&block); $before[$platform] = block; end
def sh(*args)
  expected = ["python3", File.expand_path("scripts/google_play_publication.py", ARGV[2]), ARGV[1]]
  raise "Unexpected external command" unless args == expected
  out, err, status = Open3.capture3(*args)
  raise "Publication policy unexpectedly allowed upload" if status.success?
  raise PublicationStopped, err
end
load ARGV[0]
begin
  selected = ARGV[1].to_sym
  $before[:android]&.call(selected)
  $lanes.fetch([:android, selected]).call
  raise "Upload lane unexpectedly completed"
rescue PublicationStopped => error
  raise unless error.message.include?("GOOGLE_PLAY_PUBLICATION_BLOCKED")
  puts "BLOCKED_BEFORE_BUILD"
end
'''
        fastfile = ROOT / ("android/fastlane/Fastfile" if TEMPLATE else "fastlane/Fastfile")
        for lane in sorted(policy.PUBLISH_LANES):
            with self.subTest(lane=lane):
                result = subprocess.run([RUBY, "-e", harness, str(fastfile), lane, str(ROOT)],
                                        env={"PATH": os.environ["PATH"], "CI": "true"},
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), "BLOCKED_BEFORE_BUILD")


if __name__ == "__main__":
    unittest.main()
