#!/usr/bin/env python3
"""Run a synthetic preferences QA APK on an explicitly dedicated emulator.

No build, boot, data clear, uninstall, or physical-device operation is performed.
The APK must target integration_test/android_dependency_preferences_smoke_test.dart
and define TAGSHELF_DEPENDENCY_QA_SOURCE_HASH to the supplied hex64 value. Build
with tagshelfPerformanceQa=true and a fresh numbered tagshelfQaInstance, using
debug signing only. A Release/R8 APK exercises the JNI consumer keep rules too.
"""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--serial', required=True)
    parser.add_argument('--avd-name', required=True)
    parser.add_argument('--apk', required=True, type=Path)
    parser.add_argument('--package', required=True)
    parser.add_argument('--source-hash', required=True)
    parser.add_argument('--adb', default=shutil.which('adb'))
    parser.add_argument('--apkanalyzer', default=shutil.which('apkanalyzer'))
    parser.add_argument('--timeout', type=int, default=120)
    args = parser.parse_args()
    if not re.fullmatch(r'emulator-[0-9]+', args.serial):
        parser.error('An explicit emulator serial is required')
    if not re.fullmatch(r'tagshelf_dependency_qa_[A-Za-z0-9_]+', args.avd_name):
        parser.error('AVD name must start with tagshelf_dependency_qa_')
    if not re.fullmatch(
        r'com\.tsmusic\.privateshelf\.opensource\.performanceqa[0-9]{1,8}', args.package
    ):
        parser.error('A numbered TagShelf performance QA package is required')
    if not re.fullmatch(r'[a-fA-F0-9]{64}', args.source_hash):
        parser.error('source-hash must contain 64 hexadecimal characters')
    if not args.adb:
        parser.error('adb is unavailable')
    if not args.apkanalyzer:
        sdk = os.environ.get('ANDROID_SDK_ROOT') or os.environ.get('ANDROID_HOME')
        if sdk:
            candidate = Path(sdk) / 'cmdline-tools/latest/bin/apkanalyzer'
            if candidate.is_file():
                args.apkanalyzer = str(candidate)
    if not args.apkanalyzer:
        parser.error('Pass the Android SDK apkanalyzer path explicitly')
    if not args.apk.is_file():
        parser.error('APK does not exist')
    if args.timeout < 1 or args.timeout > 600:
        parser.error('timeout must be between 1 and 600 seconds')

    def command(*parts: str, timeout: int = 30) -> str:
        return subprocess.check_output(
            parts, text=True, stderr=subprocess.STDOUT, timeout=timeout
        ).strip()

    def adb(*parts: str, timeout: int = 30) -> str:
        return command(args.adb, '-s', args.serial, *parts, timeout=timeout)

    # Check every target identifier before the first installation or app launch.
    if adb('shell', 'getprop', 'ro.kernel.qemu') != '1':
        raise RuntimeError('Target is not an Android emulator')
    if adb('shell', 'getprop', 'ro.hardware') not in ('ranchu', 'goldfish'):
        raise RuntimeError('Unexpected emulator hardware')
    avd_lines = adb('emu', 'avd', 'name').splitlines()
    if not avd_lines or avd_lines[0] != args.avd_name:
        raise RuntimeError('AVD identity does not match the dedicated target')
    if adb('shell', 'getprop', 'sys.boot_completed') != '1':
        raise RuntimeError('Dedicated emulator has not finished booting')
    apk_package = command(
        args.apkanalyzer, 'manifest', 'application-id', str(args.apk.resolve())
    )
    if apk_package != args.package:
        raise RuntimeError('APK application ID does not match the QA package')
    existing = adb('shell', 'pm', 'list', 'packages', '--user', '0', args.package)
    if existing:
        raise RuntimeError('QA package already exists; use a fresh numbered ID')

    adb('install', '-t', str(args.apk.resolve()), timeout=120)
    activity = 'com.tsmusic.privateshelf.MainActivity'
    stages = ('seed-legacy', 'read-write', 'verify-restart')
    seen_pids: set[int] = set()
    marker = 'TAGSHELF_DEPENDENCY_QA_RESULT '
    for stage in stages:
        # Retain every QA artifact; only stop this explicitly verified package.
        adb('shell', 'am', 'force-stop', args.package)
        adb('shell', 'am', 'start', '-W', '-n', f'{args.package}/{activity}')
        app_pid = adb('shell', 'pidof', '-s', args.package)
        if not app_pid.isdecimal() or int(app_pid) in seen_pids:
            raise RuntimeError('QA app did not start a distinct Android process')
        deadline = time.monotonic() + args.timeout
        matched = None
        while time.monotonic() < deadline:
            logs = adb(
                'logcat', '-d', '-v', 'brief', f'--pid={app_pid}', '-s', 'flutter'
            )
            for line in logs.splitlines():
                if marker not in line:
                    continue
                try:
                    result = json.loads(line.split(marker, 1)[1])
                except json.JSONDecodeError:
                    continue
                if (
                    result.get('schema') == 1
                    and result.get('sourceHash') == args.source_hash
                    and result.get('packageName') == args.package
                    and result.get('pid') == int(app_pid)
                ):
                    matched = result
            if matched is not None:
                break
            time.sleep(1)
        if matched is None:
            raise RuntimeError(f'No QA result before timeout for {stage}')
        if matched.get('stage') != stage or matched.get('allTestsPassed') is not True:
            raise RuntimeError(f'QA stage failed: {json.dumps(matched)}')
        seen_pids.add(matched['pid'])
        print(json.dumps(matched), flush=True)
    if len(seen_pids) != 3:
        raise RuntimeError('Expected three distinct Android processes')
    print('PASS: legacy-format read, JNI writes, reload, and cold restart retained')


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, subprocess.SubprocessError) as error:
        print(f'FAIL: {error}', file=sys.stderr)
        sys.exit(1)
