import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';

final clipboardServiceProvider = Provider<ClipboardService>((ref) {
  return ClipboardService(ref);
});

/// クリップボード操作を一元管理するサービスクラス
class ClipboardService {
  final Ref _ref;

  const ClipboardService(this._ref);

  /// テキストをクリップボードにコピーし、触覚フィードバックを発火する
  Future<Result<void, AppError>> copyText(
    String text, {
    bool triggerHaptics = true,
  }) async {
    try {
      if (text.isEmpty) {
        return Result.failure(
          AppError.validation(
            'コピー対象の文字列が空です。',
            context: 'ClipboardService.copyText',
          ),
        );
      }

      await Clipboard.setData(ClipboardData(text: text));

      if (triggerHaptics) {
        await _ref.read(feedbackServiceProvider).lightImpact();
      }

      AppLogger.d(LogTag.ui, 'クリップボードにテキストをコピーしました: length=${text.length}');
      return Result.success(null);
    } catch (e, st) {
      AppLogger.e(LogTag.ui, 'クリップボードへのコピーに失敗しました', e, st);
      return Result.failure(
        AppError.system(
          'クリップボードへのコピーに失敗しました: $e',
          original: e,
          stackTrace: st,
          context: 'ClipboardService.copyText',
        ),
      );
    }
  }

  /// クリップボードから現在のテキストを取得する
  Future<Result<String?, AppError>> getText() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return Result.success(data?.text);
    } catch (e, st) {
      AppLogger.e(LogTag.ui, 'クリップボードからのテキスト取得に失敗しました', e, st);
      return Result.failure(
        AppError.system(
          'クリップボードの読み込みに失敗しました: $e',
          original: e,
          stackTrace: st,
          context: 'ClipboardService.getText',
        ),
      );
    }
  }
}
