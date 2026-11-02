import 'package:flutter/material.dart';
import 'package:private_shelf/shared/widgets/feedback/app_snackbar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../feedback/feedback_providers.dart';
import '../feedback/haptics_service.dart';
import '../feedback/snackbar_service.dart';
import '../logger/app_logger.dart';
import '../logger/log_tag.dart';
import '../theme/app_colors.dart';

/// クリップボード操作のユーティリティ
class ClipboardUtils {
  ClipboardUtils._();

  /// テキストをクリップボードにコピー
  ///
  /// コピーに成功したら `true`、失敗したら `false` を返します。
  static Future<bool> copyText(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      AppLogger.d(LogTag.app, 'Text copied to clipboard');
      return true;
    } catch (e, st) {
      AppLogger.e(LogTag.app, 'Failed to copy text to clipboard', e, st);
      return false;
    }
  }

  /// テキストをコピーし、フィードバック（SnackBar + ハプティクス）を表示
  ///
  /// [context] SnackBar表示に必要なBuildContext
  /// [text] コピーするテキスト
  /// [message] SnackBarに表示するメッセージ（デフォルト: 'コピーしました'）
  /// [enableHaptics] ハプティクスを有効にするか（デフォルト: true）
  /// [ref] WidgetRef（SnackBarServiceを使用する場合）
  static Future<void> copyWithFeedback(
    BuildContext context,
    String text, {
    String message = 'コピーしました',
    bool enableHaptics = true,
    WidgetRef? ref,
  }) async {
    final success = await copyText(text);

    if (!context.mounted) return;

    if (success) {
      // ハプティクスフィードバック
      if (enableHaptics) {
        if (ref != null) {
          await ref.read(feedbackServiceProvider).success();
        } else {
          await HapticsService.success();
        }
      }

      if (!context.mounted) return;

      // SnackBar表示
      if (ref != null) {
        ref
            .read(snackBarServiceProvider)
            .success(context: context, message: message);
      } else {
        AppSnackBarMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // エラー時
      if (enableHaptics) {
        if (ref != null) {
          await ref.read(feedbackServiceProvider).error();
        } else {
          await HapticsService.error();
        }
      }

      if (!context.mounted) return;

      if (ref != null) {
        ref
            .read(snackBarServiceProvider)
            .error(context: context, message: 'コピーに失敗しました');
      } else {
        AppSnackBarMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('コピーに失敗しました'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// クリップボードからテキストを取得
  ///
  /// テキストがない場合は `null` を返します。
  static Future<String?> getText() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text;
    } catch (e, st) {
      AppLogger.e(LogTag.app, 'Failed to get text from clipboard', e, st);
      return null;
    }
  }

  /// クリップボードにテキストがあるかチェック
  static Future<bool> hasText() async {
    final text = await getText();
    return text != null && text.isNotEmpty;
  }
}
