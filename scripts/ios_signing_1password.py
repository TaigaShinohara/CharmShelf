#!/usr/bin/env python3
"""Project-local iOS signing entrypoint."""
import os
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
runner=Path(os.environ.get('CODEX_AUTH_HOME',Path.home()/'.local/share/codex-auth'))/'ios_signing.py'
if not runner.is_file():raise SystemExit('NOT_CONFIGURED: Install the shared iOS signing runner.')
os.execv(sys.executable,[sys.executable,str(runner),'--profile',str(ROOT/'auth/ios-signing.local.json'),*sys.argv[1:]])
