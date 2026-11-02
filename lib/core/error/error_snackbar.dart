import 'package:flutter/material.dart';
import 'package:private_shelf/shared/widgets/feedback/app_snackbar.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_error_extension.dart';
import '../../shared/widgets/widgets.dart';

import '../feedback/snackbar_config.dart';
import '../feedback/snackbar_service.dart';
import '../theme/app_colors.dart';
import 'app_error.dart';

/// エラー表示用SnackBar
///
/// [AppError]の重要度に応じたSnackBarを表示します。
/// SnackBarServiceを使用してカスタマイズされたスタイルで表示します。
class ErrorSnackBar {
  /// WidgetRefを使用してSnackBarを表示
  static void show(BuildContext context, AppError error, {WidgetRef? ref}) {
    final type = switch (error.severity) {
      ErrorSeverity.critical => SnackBarType.error,
      ErrorSeverity.warning => SnackBarType.warning,
      ErrorSeverity.info => SnackBarType.info,
    };

    if (ref != null) {
      final l10n = AppLocalizations.of(context)!;
      ref
          .read(snackBarServiceProvider)
          .show(
            context: context,
            message: error.localizedMessage(l10n),
            type: type,
          );
    } else {
      // フォールバック: 従来の方法
      _showLegacy(context, error);
    }
  }

  /// 従来の方法でSnackBarを表示（WidgetRefがない場合のフォールバック）
  static void _showLegacy(BuildContext context, AppError error) {
    final color = switch (error.severity) {
      ErrorSeverity.critical => AppColors.error,
      ErrorSeverity.warning => AppColors.warning,
      ErrorSeverity.info => AppColors.info,
    };

    final l10n = AppLocalizations.of(context)!;
    AppSnackBarMessenger.of(context).showSnackBar(
      SnackBar(
        content: AppText(error.localizedMessage(l10n)),
        backgroundColor: color,
      ),
    );
  }
}
