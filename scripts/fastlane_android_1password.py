#!/usr/bin/env python3
"""Prepare signing first, then resolve API credentials for Fastlane."""
import os,sys,subprocess
from pathlib import Path
from project_auth import ensure, ensure_signing
from google_play_publication import require_publication_ready
ROOT=Path(__file__).resolve().parents[1]
if len(sys.argv)<2:raise SystemExit('Usage: LANE [OPTIONS] or --check-auth')
common=Path(os.environ.get('CODEX_AUTH_HOME',Path.home()/'.local/share/codex-auth'))
if sys.argv[1:]==['--check-auth']:
    ensure(ROOT/'auth/tagshelf-google-play.local.json',[sys.executable,*sys.argv])
    checker=common/'google_play_check.py'
    if not checker.is_file():raise SystemExit('NOT_CONFIGURED: Install shared Google Play checker.')
    raise SystemExit(subprocess.call([sys.executable,str(checker)]))
require_publication_ready(sys.argv[1])
ensure_signing(ROOT/'auth/android-signing.local.json','android',[sys.executable,*sys.argv])
# API resolution is last: profile isolation removes inherited API credentials.
ensure(ROOT/'auth/tagshelf-google-play.local.json',[sys.executable,*sys.argv])
raise SystemExit(subprocess.call(['bundle','exec','fastlane','android',*sys.argv[1:]],cwd=ROOT))
