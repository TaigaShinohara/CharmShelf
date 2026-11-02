#!/usr/bin/env python3
"""Prepare temporary GitHub Actions signing files; never print secret values."""
import base64
import os
from pathlib import Path
import re
import sys


def folder(environment):
    root = Path(environment['RUNNER_TEMP'])
    if not root.is_absolute() or not root.is_dir():
        raise ValueError('Invalid runner directory')
    return root / 'codex-android-signing'


def clean(environment):
    target = folder(environment)
    if target.is_symlink():
        raise ValueError('Unsafe signing directory')
    if not target.exists():
        return
    for name in ('key.properties', 'release.keystore'):
        (target / name).unlink(missing_ok=True)
    target.rmdir()


def prepare(environment):
    properties = base64.b64decode(environment['KEY_PROPERTIES_BASE64'], validate=True)
    keystore = base64.b64decode(environment['KEYSTORE_BASE64'], validate=True)
    if not keystore or b'\x00' in properties or len(re.findall(rb'(?m)^storeFile[ \t]*=.*$', properties)) != 1:
        raise ValueError('Invalid signing material')
    target = folder(environment)
    # Properties escaping handles Unicode and special characters in runner paths.
    location = str(target / 'release.keystore')
    def escape_character(character):
        if ord(character) > 126:
            units = character.encode('utf-16-be').hex()
            return ''.join('\\u' + units[i:i+4] for i in range(0, len(units), 4))
        return '\\' + character if character in '\\=:#! ' else character
    escaped = ''.join(escape_character(c) for c in location)
    properties = re.sub(rb'(?m)^storeFile[ \t]*=.*$', lambda _: b'storeFile=' + escaped.encode('ascii'), properties)
    gradle_options = environment.get('GRADLE_OPTS', '') + ' -Dorg.gradle.daemon=false -Dorg.gradle.configuration-cache=false'
    env_lines = 'CODEX_ANDROID_KEY_PROPERTIES=' + str(target / 'key.properties') + '\nGRADLE_OPTS=' + gradle_options + '\n'
    if any(c in str(target) + gradle_options for c in '\r\n'):
        raise ValueError('Invalid environment metadata')
    target.mkdir(mode=0o700)
    try:
        for name, content in (('key.properties', properties), ('release.keystore', keystore)):
            fd = os.open(target / name, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, 'wb') as stream:
                stream.write(content)
        with open(environment['GITHUB_ENV'], 'a') as stream:
            stream.write(env_lines)
    except Exception:
        clean(environment)
        raise


if __name__ == '__main__':
    try:
        if sys.argv[1:] == ['--clean']:
            clean(os.environ)
        elif not sys.argv[1:]:
            prepare(os.environ)
        else:
            raise ValueError('Invalid command')
    except Exception:
        raise SystemExit('ANDROID_SIGNING_SETUP_FAILED: Check required secrets and runner configuration.') from None
