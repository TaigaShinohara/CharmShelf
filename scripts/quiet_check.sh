#!/bin/bash
# 非対話コマンドの全文ログを保存し、終了コードを保持して末尾だけを表示する。
set -uo pipefail

if [ "$#" -eq 0 ]; then
  printf '使い方: bash scripts/quiet_check.sh <コマンド> <引数...>\n' >&2
  exit 64
fi

umask 077
log_file=$(mktemp "${TMPDIR:-/tmp}/tagshelf-check.XXXXXX") || exit 1
result=0
"$@" >"$log_file" 2>&1 || result=$?

printf '終了コード: %s | 全文ログ: %s\n' "$result" "$log_file"
if [ "$result" -eq 0 ]; then
  tail -n 8 "$log_file"
else
  tail -n 80 "$log_file"
fi
exit "$result"
