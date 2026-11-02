import 'package:flutter/material.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

import 'confirm_dialog.dart';

/// 未保存データの確認ダイアログを表示します。
///
/// 「変更を破棄しますか？」というメッセージで、
/// ユーザーに未保存データの破棄を確認します。
///
/// 戻り値:
/// - `true`: 破棄してよい
/// - `false`: 破棄しない（キャンセル）
Future<bool> showUnsavedDataDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;

  return showConfirmDialog(
    context,
    title: l10n.unsavedDataDialogTitle,
    message: l10n.unsavedDataDialogMessage,
    confirmLabel: l10n.unsavedDataDialogDiscard,
    cancelLabel: l10n.commonCancel,
    isDestructive: true,
  );
}
