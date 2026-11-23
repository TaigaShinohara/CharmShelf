#!/bin/zsh
# ローカルでアーカイブとApp Store署名IPAを作る。アップロード・実機上書きは行わない。
set -euo pipefail
umask 077
zmodload zsh/datetime

if (( $# < 2 )); then
  print -u2 'Usage: zsh scripts/build_ios_release_candidate.zsh <version> <build-number> [--export [--export-options <plist>] [--installed-signing]] [--no-pub]'
  print -u2 '提出用の番号はApp Store Connectの既存ビルドと照合してください。'
  exit 2
fi

release_name="$1"
release_number="$2"
shift 2
export_ipa=0
installed_signing=0
options_file=""
pub_args=()
while (( $# )); do
  case "$1" in
    --export) export_ipa=1 ;;
    --export-options)
      if (( $# < 2 )) || [[ -z "$2" || "$2" == --* ]]; then
        print -u2 '--export-optionsにはローカルのplistを指定してください。'
        exit 2
      fi
      options_file="${2:A}"
      shift
      ;;
    --installed-signing) installed_signing=1 ;;
    --no-pub) pub_args=(--no-pub) ;;
    *) print -u2 "不明なオプション: $1"; exit 2 ;;
  esac
  shift
done
if (( export_ipa == 0 )) && { [[ -n "$options_file" ]] || (( installed_signing == 1 )); }; then
  print -u2 '署名オプションには--exportが必要です。'
  exit 2
fi
# 比較計測時だけNOにする。グローバル設定・Pods生成物は変更しない。
compile_cache="${IOS_COMPILATION_CACHE:-YES}"
if [[ "$compile_cache" != YES && "$compile_cache" != NO ]]; then
  print -u2 'IOS_COMPILATION_CACHEはYESまたはNOを指定してください。'
  exit 2
fi
if [[ ! "$release_name" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || \
   [[ ! "$release_number" =~ '^[1-9][0-9]*$' ]]; then
  print -u2 'Version must be x.y.z; build number must be a positive integer.'
  exit 2
fi

script_path="${0:A}"
repo_root="${script_path:h:h}"
cd "$repo_root"
export_options="${options_file:-$repo_root/scripts/ios_export_options.plist}"
if (( export_ipa == 1 )); then
  signing_check=(ios --ios-export-options "$export_options")
  if (( installed_signing == 1 )); then
    signing_check+=(--check-installed-signing)
  fi
  python3 scripts/check_distribution_config.py "${signing_check[@]}"
fi
if (( export_ipa == 1 && installed_signing == 0 )) && [[ -z "${CODEX_IOS_KEYCHAIN_PATH:-}" ]]; then
  exec python3 scripts/ios_signing_1password.py -- zsh "$script_path" "$release_name" "$release_number" \
    --export --export-options "$export_options" "${pub_args[@]}"
fi
flutter_bin="${FLUTTER_BIN:-${commands[flutter]:-}}"
FLUTTER_BIN="$flutter_bin" bash scripts/maintenance/check_flutter_version.sh
python3 scripts/maintenance/check_private_content.py --sources-only
derived_data_dir="$repo_root/build/ios-release-derived-data"
sdk_version="$(xcrun --sdk iphoneos --show-sdk-version)"
if (( ${sdk_version%%.*} < 26 )); then
  print -u2 'App Store提出にはiOS SDK 26以降が必要です。'
  exit 1
fi

candidate_dir="$repo_root/build/ios-release-candidates/${release_name}-${release_number}-$(date +%Y%m%d-%H%M%S)"
mkdir -p "${candidate_dir:h}"
mkdir "$candidate_dir"
print "ローカル候補の保存先: $candidate_dir"
git rev-parse HEAD > "$candidate_dir/source-commit.txt"
git status --short --untracked-files=all > "$candidate_dir/source-status.txt"
"$flutter_bin" --version > "$candidate_dir/flutter-version.txt"
xcodebuild -version > "$candidate_dir/xcode-version.txt"
print 'phase\tseconds\texit_code' > "$candidate_dir/timing.tsv"
print "COMPILATION_CACHE_ENABLE_CACHING=$compile_cache" > "$candidate_dir/build-options.txt"

# 失敗時も所要時間・終了コードと全文ログを保持する。
timed_step() {
  local phase="$1"
  shift
  local started="$EPOCHREALTIME"
  local result=0
  "$@" > "$candidate_dir/$phase.log" 2>&1 || result=$?
  printf '%s\t%.3f\t%d\n' "$phase" "$(( EPOCHREALTIME - started ))" "$result" \
    >> "$candidate_dir/timing.tsv"
  if (( result != 0 )); then
    print -u2 "工程失敗: $phase (終了コード $result)。ログ: $candidate_dir/$phase.log"
  fi
  return "$result"
}

# 過去のbuild/ios/archive/Runner.xcarchiveは上書きしない。
# `--config-only` では App.framework が既存キャッシュにだけ残っている場合があり、
# クリーンな状態の archive が Flutter アプリ本体を見つけられない。提出候補は
# 事前生成物に依存させず、未署名の Release 本体まで必ず作成してから archive する。
timed_step flutter-build "$flutter_bin" build ios --release --no-codesign "${pub_args[@]}" \
  --dart-define=ENV=production \
  --build-name="$release_name" --build-number="$release_number"
timed_step archive xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "$candidate_dir/Runner.xcarchive" \
  -derivedDataPath "$derived_data_dir" \
  -resultBundlePath "$candidate_dir/archive.xcresult" \
  -jobs 2 -showBuildTimingSummary \
  "COMPILATION_CACHE_ENABLE_CACHING=$compile_cache" \
  COMPILATION_CACHE_ENABLE_DIAGNOSTIC_REMARKS=YES \
  "PERFORMANCE_MEASUREMENT_FILE=$candidate_dir/flutter-performance.json" \
  archive CODE_SIGNING_ALLOWED=NO

# Apple TN3181 requires empty accessed-API arrays to be omitted. Export signs the
# normalized app. Embedded code and nonempty declarations are left for their SDK owners.
timed_step privacy-manifests python3 scripts/maintenance/normalize_ios_privacy_manifests.py \
  "$candidate_dir/Runner.xcarchive"

resolved="$repo_root/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
python3 scripts/maintenance/check_ios_swift_packages.py --resolved "$resolved"
python3 scripts/maintenance/export_ios_licenses.py --check \
  --source-packages "$derived_data_dir/SourcePackages/checkouts"

# Xcode 26.6の自動dSYM生成にはCASの参照先が渡らない。
# 保持されたデバッグマップから再生成し、SDKモジュール情報の欠落を防ぐ。
dsym_check_args=()
if [[ "$compile_cache" == YES ]]; then
  timed_step dsym xcrun dsymutil \
    -cas "$derived_data_dir/CompilationCache.noindex/builtin" \
    --verify --num-threads 2 \
    "$candidate_dir/Runner.xcarchive/Products/Applications/Runner.app/Runner" \
    -o "$candidate_dir/Runner.xcarchive/dSYMs/Runner.app.dSYM"
  dsym_check_args=(--dsym-log "$candidate_dir/dsym.log")
fi

python3 - "$candidate_dir/Runner.xcarchive/Products/Applications/Runner.app/Info.plist" \
  "$release_name" "$release_number" <<'PY'
import plistlib
import sys
from pathlib import Path
info = plistlib.loads(Path(sys.argv[1]).read_bytes())
if (info.get('CFBundleShortVersionString'), info.get('CFBundleVersion')) != tuple(sys.argv[2:]):
    raise SystemExit('成果物のバージョン・ビルド番号が要求と一致しません。')
PY

python3 scripts/maintenance/check_ios_archive.py "$candidate_dir/Runner.xcarchive" "${dsym_check_args[@]}" \
  > "$candidate_dir/archive-check.txt"
cat "$candidate_dir/archive-check.txt"
python3 scripts/maintenance/check_private_content.py \
  --archive "$candidate_dir/Runner.xcarchive/Products/Applications/Runner.app"
cat "$candidate_dir/timing.tsv"
if (( export_ipa == 0 )); then
  print '未署名アーカイブ完成。IPA書き出しは署名資産の整合確認後に--exportを指定してください。'
  exit 0
fi

# 既存の配布証明書・プロファイルのみを使う。自動発行やアップロードは許可しない。
if ! timed_step export xcodebuild -exportArchive -archivePath "$candidate_dir/Runner.xcarchive" \
  -exportOptionsPlist "$export_options" \
  -exportPath "$candidate_dir/export"; then
  print -u2 "IPA書き出しに失敗しました。アーカイブは保持済みです: $candidate_dir"
  print -u2 "署名資産の整合とexport.logを確認してください。"
  exit 1
fi

ipa_files=("$candidate_dir"/export/*.ipa(N))
if (( ${#ipa_files} != 1 )); then
  print -u2 'Expected exactly one exported IPA.'
  exit 1
fi
unzip -tq "$ipa_files[1]"
python3 scripts/maintenance/check_private_content.py --archive "$ipa_files[1]"
python3 scripts/maintenance/check_ios_ipa.py "$ipa_files[1]" \
  --archive "$candidate_dir/Runner.xcarchive" \
  --export-options "$export_options" \
  --report "$candidate_dir/ipa-verification.json"
shasum -a 256 "$ipa_files[1]" > "$candidate_dir/ipa.sha256"
cat "$candidate_dir/timing.tsv"
print "ローカルIPA完成（未アップロード）: $ipa_files[1]"
print '署名内容・輸出コンプライアンス・実機QA・ストアのビルド番号を確認してから提出してください。'
