#!/usr/bin/env python3
"""Run the shared 1Password signing helper with this project's local profile."""
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    profile = ROOT / 'auth/android-signing.local.json'
    runner = Path(os.environ.get('CODEX_AUTH_HOME', Path.home() / '.local/share/codex-auth')) / 'android_signing.py'
    if not profile.is_file() or not runner.is_file():
        raise SystemExit('NOT_CONFIGURED: Follow auth/README.md to configure 1Password signing.')
    return subprocess.call([sys.executable, str(runner), '--profile', str(profile), *sys.argv[1:]], cwd=ROOT)


if __name__ == '__main__':
    raise SystemExit(main())
