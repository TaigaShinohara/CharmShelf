import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'app_error.dart';

/// AppErrorのローカライズ拡張
extension AppErrorLocalization on AppError {
  /// エラーメッセージをローカライズして取得
  ///
  /// 技術的な詳細メッセージではなく、ユーザーフレンドリーなメッセージを返します。
  /// [l10n] AppLocalizationsのインスタンス
  String localizedMessage(AppLocalizations l10n) {
    return switch (category) {
      ErrorCategory.network => l10n.errorNetwork,
      ErrorCategory.database => l10n.errorDatabase,
      ErrorCategory.auth => l10n.errorAuth,
      ErrorCategory.validation => l10n.errorValidation,
      ErrorCategory.file => l10n.errorFile,
      ErrorCategory.permission => l10n.errorPermission,
      ErrorCategory.system => l10n.errorSystem,
      ErrorCategory.ui => l10n.errorUi,
      ErrorCategory.unknown => l10n.errorUnknown,
    };
  }
}
