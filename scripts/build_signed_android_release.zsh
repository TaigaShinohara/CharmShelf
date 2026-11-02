#!/bin/zsh
set -euo pipefail

tagshelf_script_dir="${0:A:h}"
tagshelf_project_root="${tagshelf_script_dir:h}"
tagshelf_flutter_bin="${FLUTTER_BIN:-${commands[flutter]:-}}"

cd "${tagshelf_project_root}"
python3 scripts/check_distribution_config.py android
FLUTTER_BIN="${tagshelf_flutter_bin}" bash scripts/maintenance/check_flutter_version.sh

# Re-enter under the project-specific 1Password profile. The shared runner
# removes temporary signing files after this process and its checks finish.
if ! python3 scripts/project_auth.py --check-signing auth/android-signing.local.json android; then
  exec python3 scripts/android_signing_1password.py --context-version 2 -- /bin/zsh "$0" "$@"
fi

python3 scripts/maintenance/check_private_content.py --sources-only

# Flutter 3.47 filters dev-only Android plugins in the release-mode tooling
# preparation, which --no-pub skips. After tests/pub get, an old registrant can
# otherwise reference IntegrationTestPlugin absent from release dependencies.
tagshelf_build_arguments=()
for tagshelf_argument in "$@"; do
  if [[ "${tagshelf_argument}" == --no-pub ]]; then
    print 'Release用プラグイン登録を再生成するため、--no-pubは使用しません。'
  else
    tagshelf_build_arguments+=("${tagshelf_argument}")
  fi
done
tagshelf_lock_hash_before="$(shasum -a 256 pubspec.lock | awk '{print $1}')"
"${tagshelf_flutter_bin}" build appbundle --release --dart-define=ENV=production "${tagshelf_build_arguments[@]}"
tagshelf_lock_hash_after="$(shasum -a 256 pubspec.lock | awk '{print $1}')"
if [[ "${tagshelf_lock_hash_before}" != "${tagshelf_lock_hash_after}" ]]; then
  print -u2 '依存lockが変化しました。このAABをリリース候補として使用しないでください。'
  exit 1
fi

tagshelf_aab_path="build/app/outputs/bundle/release/app-release.aab"
tagshelf_expected_fingerprint_path="android/upload_certificate.sha256"
if ! tagshelf_jarsigner_output="$(jarsigner -verify "${tagshelf_aab_path}" 2>&1)"; then
  print -u2 -- "${tagshelf_jarsigner_output}"
  exit 1
fi

tagshelf_certificate="$(
  keytool \
    -J-Duser.language=en \
    -J-Duser.country=US \
    -printcert \
    -jarfile "${tagshelf_aab_path}"
)"
tagshelf_actual_fingerprints=(
  "${(@f)$(
    print -r -- "${tagshelf_certificate}" |
      awk -F'SHA256: ' '/SHA256:/{print toupper($2)}' |
      sed 's/[[:space:]]//g' |
      sort -u
  )}"
)

if (( ${#tagshelf_actual_fingerprints[@]} != 1 )); then
  print -u2 'Release bundle must have exactly one signing certificate'
  exit 1
fi
if [[ "${tagshelf_certificate}" == *'Android Debug'* ]]; then
  print -u2 'Android Debug certificate must never sign a release bundle'
  exit 1
fi

tagshelf_expected_fingerprint="$(tr -d '[:space:]' < "${tagshelf_expected_fingerprint_path}")"
if [[ "${tagshelf_actual_fingerprints[1]}" != "${tagshelf_expected_fingerprint}" ]]; then
  print -u2 'Release bundle was signed by an unexpected certificate'
  exit 1
fi

print "Release bundle signature verified: ${tagshelf_actual_fingerprints[1]}"
python3 scripts/maintenance/check_android_bundle.py "${tagshelf_aab_path}"
python3 scripts/maintenance/check_private_content.py --archive "${tagshelf_aab_path}"
