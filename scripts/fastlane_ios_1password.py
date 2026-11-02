#!/usr/bin/env python3
"""Prepare signing first, then resolve API credentials for Fastlane."""
import sys,subprocess
from pathlib import Path
from project_auth import ensure, ensure_signing
from check_distribution_config import require_distribution_config
ROOT=Path(__file__).resolve().parents[1]
if len(sys.argv)<2:raise SystemExit('Usage: LANE [OPTIONS]')
if sys.argv[1] in ('beta', 'release'):require_distribution_config('ios')
ensure_signing(ROOT/'auth/ios-signing.local.json','ios',[sys.executable,*sys.argv])
# API resolution is last: profile isolation removes inherited API credentials.
ensure(ROOT/'auth/tagshelf-app-store.local.json',[sys.executable,*sys.argv])
raise SystemExit(subprocess.call(['bundle','exec','fastlane','ios',*sys.argv[1:]],cwd=ROOT))
