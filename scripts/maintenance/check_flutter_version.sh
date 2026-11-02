#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
expected_version="$(
  awk '
    /^environment:/ { in_environment = 1; next }
    in_environment && /^[^[:space:]]/ { exit }
    in_environment && $1 == "flutter:" { print $2; exit }
  ' "$repo_root/pubspec.yaml"
)"
flutter_bin="${FLUTTER_BIN:-$(command -v flutter || true)}"

if [[ -z "$expected_version" ]]; then
  echo 'pubspec.yamlのenvironment.flutterがありません。' >&2
  exit 1
fi
if [[ -z "$flutter_bin" || ! -x "$flutter_bin" ]]; then
  echo 'Flutter SDKが見つかりません。' >&2
  exit 1
fi

actual_version="$("$flutter_bin" --version --machine | python3 -c 'import json,sys; print(json.load(sys.stdin)["frameworkVersion"])')"
if [[ "$actual_version" != "$expected_version" ]]; then
  echo "Flutter SDK不一致: expected=$expected_version actual=$actual_version" >&2
  exit 1
fi

echo "Flutter SDK一致: $actual_version"
