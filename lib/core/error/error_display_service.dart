import 'package:flutter/material.dart';
import 'package:private_shelf/shared/widgets/feedback/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/shared/widgets/dialogs/dialog_actions.dart';

import '../../gen_l10n/app_localizations.dart';
import '../feedback/snackbar_service.dart';
import '../logger/app_logger.dart';
import '../logger/log_tag.dart';
import 'app_error.dart';
import 'app_error_extension.dart';

/// エラー表示サービス
///
/// エラーの重大度に応じて適切なUIで表示します。
/// - critical: ダイアログ
/// - warning: SnackBar
/// - info: Toast（短時間のSnackBar）
class ErrorDisplayService {
  ErrorDisplayService._();

  /// エラーを重大度に応じて表示
  ///
  /// [context] BuildContext
  /// [error] 表示するエラー
  /// [ref] WidgetRef（SnackBarService使用時に必要）
  /// [onRetry] リトライボタンのコールバック
  static void show(
    BuildContext context,
    AppError error, {
    WidgetRef? ref,
    VoidCallback? onRetry,
  }) {
    switch (error.severity) {
      case ErrorSeverity.critical:
        _showDialog(context, error, onRetry: onRetry);
        break;
      case ErrorSeverity.warning:
        _showSnackBar(context, error, ref: ref, onRetry: onRetry);
        break;
      case ErrorSeverity.info:
        _showToast(context, error, ref: ref);
        break;
    }

    // ログに記録
    AppLogger.e(
      LogTag.app,
      'Error displayed: ${error.category.name}',
      error.originalError ?? error,
      error.stackTrace,
    );
  }

  /// ダイアログでエラーを表示（critical用）
  static void _showDialog(
    BuildContext context,
    AppError error, {
    VoidCallback? onRetry,
  }) {
    final l10n = AppLocalizations.of(context)!;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.commonErrorOccurred),
        content: Text(error.localizedMessage(l10n)),
        actions: [
          if (onRetry != null)
            DialogActionRow(
              leading: DialogCloseButton(
                onPressed: () => Navigator.of(context).pop(),
                semanticLabel: l10n.commonClose,
              ),
              trailing: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onRetry();
                },
                child: Text(l10n.commonRetry),
              ),
            )
          else
            DialogCloseButton(
              onPressed: () => Navigator.of(context).pop(),
              semanticLabel: l10n.commonClose,
            ),
        ],
      ),
    );
  }

  /// SnackBarでエラーを表示（warning用）
  static void _showSnackBar(
    BuildContext context,
    AppError error, {
    WidgetRef? ref,
    VoidCallback? onRetry,
  }) {
    final l10n = AppLocalizations.of(context)!;

    if (ref != null) {
      ref
          .read(snackBarServiceProvider)
          .error(
            context: context,
            message: error.localizedMessage(l10n),
            action: onRetry != null
                ? SnackBarAction(label: l10n.commonRetry, onPressed: onRetry)
                : null,
          );
    } else {
      // refがない場合は標準のSnackBarを使用
      AppSnackBarMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.localizedMessage(l10n)),
          action: onRetry != null
              ? SnackBarAction(label: l10n.commonRetry, onPressed: onRetry)
              : null,
        ),
      );
    }
  }

  /// Toastでエラーを表示（info用）
  static void _showToast(
    BuildContext context,
    AppError error, {
    WidgetRef? ref,
  }) {
    final l10n = AppLocalizations.of(context)!;

    if (ref != null) {
      ref
          .read(snackBarServiceProvider)
          .info(
            context: context,
            message: error.localizedMessage(l10n),
            duration: const Duration(seconds: 2),
          );
    } else {
      // refがない場合は標準のSnackBarを使用
      AppSnackBarMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.localizedMessage(l10n)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
