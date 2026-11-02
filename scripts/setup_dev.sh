#!/usr/bin/env bash
# Prepare a clean checkout without any maintainer credentials or signing keys.
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/maintenance/check_flutter_version.sh
flutter pub get --enforce-lockfile
python3 scripts/maintenance/prepare_host_isar.py
dart run scripts/check_l10n_consistency.dart
dart run scripts/merge_l10n.dart
flutter gen-l10n
dart run scripts/update_config.dart
dart run build_runner build
printf 'Development checkout ready. Run flutter analyze and flutter test --exclude-tags golden.\n'
