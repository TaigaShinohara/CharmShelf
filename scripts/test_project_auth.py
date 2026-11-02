#!/usr/bin/env python3
import json,os,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
import project_auth

class ProjectAuthTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
  self.root=Path(self.tmp.name);self.profile=self.root/'service.json'
  self.profile.write_text(json.dumps({'local_auth':{'mode':'desktop','account':'fixture-account'},'secret_references':{'API_KEY':'op://vault/item/field'}}))
  (self.root/'run.py').write_text('# stub')
 def test_existing_injected_credential_avoids_login(self):
  marker=project_auth.profile_identity(json.loads(self.profile.read_text()), self.profile)
  with patch.dict(os.environ,{'API_KEY':'dummy','CODEX_AUTH_PROFILE_V2_ID':marker},clear=True),patch('project_auth.subprocess.call') as launch:
   project_auth.ensure(self.profile,['app']);launch.assert_not_called()
 def test_inherited_credential_without_profile_marker_is_replaced(self):
  with patch.dict(os.environ,{'API_KEY':'stale-dummy','CODEX_AUTH_HOME':str(self.root)},clear=True),patch('project_auth.subprocess.call',return_value=0) as launch:
   with self.assertRaises(SystemExit):project_auth.ensure(self.profile,['app'])
   launch.assert_called_once()
 def test_foreign_profile_marker_is_not_trusted(self):
  with patch.dict(os.environ,{'API_KEY':'dummy','CODEX_AUTH_PROFILE_V2_ID':'other-profile','CODEX_AUTH_HOME':str(self.root)},clear=True),patch('project_auth.subprocess.call',return_value=0) as launch:
   with self.assertRaises(SystemExit):project_auth.ensure(self.profile,['app'])
   launch.assert_called_once()
 def test_explicit_cloud_context_uses_network_secret_placeholder(self):
  profile=json.loads(self.profile.read_text());profile['cloud']={'context':'codex-cloud:test'};self.profile.write_text(json.dumps(profile))
  with patch.dict(os.environ,{'API_KEY':'network-secret-placeholder','CODEX_AUTH_CONTEXT':'codex-cloud:test'},clear=True),patch('project_auth.subprocess.call') as launch:
   project_auth.ensure(self.profile,['app']);launch.assert_not_called()
 def test_missing_cloud_secret_does_not_try_mac_keychain(self):
  profile=json.loads(self.profile.read_text());profile['cloud']={'context':'codex-cloud:test'};self.profile.write_text(json.dumps(profile))
  with patch.dict(os.environ,{'CODEX_AUTH_CONTEXT':'codex-cloud:test'},clear=True),patch('project_auth.subprocess.call') as launch:
   with self.assertRaisesRegex(SystemExit,'Network secrets'):project_auth.ensure(self.profile,['app'])
   launch.assert_not_called()
 def test_reference_is_resolved_before_application(self):
  with patch.dict(os.environ,{'API_KEY':'op://vault/item/field','CODEX_AUTH_HOME':str(self.root)},clear=True),patch('project_auth.subprocess.call',return_value=7) as launch:
   with self.assertRaises(SystemExit) as stop:project_auth.ensure(self.profile,['app','argument'])
   self.assertEqual(stop.exception.code,7)
   self.assertEqual(launch.call_args.args[0][-3:],['--','app','argument'])
 def test_missing_profile_does_not_launch(self):
  with patch('project_auth.subprocess.call') as launch:
   with self.assertRaises(SystemExit):project_auth.ensure(self.root/'missing',['app'])
   launch.assert_not_called()
 def test_empty_profile_fails_closed(self):
  self.profile.write_text('{"secret_references": {}}')
  with self.assertRaises(SystemExit):project_auth.ensure(self.profile,['app'])
 def test_missing_runner_fails_closed(self):
  with patch.dict(os.environ,{'CODEX_AUTH_HOME':str(self.root/'missing')},clear=True):
   with self.assertRaises(SystemExit):project_auth.ensure(self.profile,['app'])

if __name__=='__main__':unittest.main()
