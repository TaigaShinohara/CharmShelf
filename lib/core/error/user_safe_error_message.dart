import 'package:private_shelf/gen_l10n/app_localizations.dart';

import 'app_error.dart';
import 'app_error_extension.dart';

/// 例外の技術情報をユーザーUIへ漏らさず、ローカライズ済み文言へ変換します。
///
/// 詳細な例外、パス、内部状態はログへ記録し、画面ではカテゴリに対応する
/// 回復可能な説明だけを表示します。未知の例外は安全な一般メッセージへ
/// フォールバックします。
String userSafeErrorMessage(Object? error, AppLocalizations l10n) {
  if (error is AppError) {
    return error.localizedMessage(l10n);
  }
  return l10n.errorUnknown;
}
