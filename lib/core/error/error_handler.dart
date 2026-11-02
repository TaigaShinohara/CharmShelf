import 'package:flutter/foundation.dart';

import '../logger/app_logger.dart';
import '../logger/log_tag.dart';
import 'crash_report_service.dart';

/// アプリ全体のエラーハンドリングを管理するクラス
///
/// Flutter/Dartの各種エラーをキャッチし、ログ出力とクラッシュレポートの
/// 記録を行います。
class GlobalErrorHandler {
  GlobalErrorHandler._();

  /// クラッシュレポートを有効にするかどうか
  static bool _crashReportEnabled = true;

  /// エラーハンドリング中フラグ（無限ループ防止）
  static bool _isHandlingError = false;

  /// クラッシュレポートの有効/無効を設定
  static void setCrashReportEnabled(bool enabled) {
    _crashReportEnabled = enabled;
  }

  /// エラーハンドラーをインストール
  ///
  /// アプリ起動時に一度だけ呼び出してください。
  static void install() {
    // Flutter フレームワークのエラー
    FlutterError.onError = (details) {
      if (kDebugMode) FlutterError.presentError(details);
      _handleError(
        details.exception,
        details.stack,
        context: 'FlutterError.onError',
        errorSource: ErrorSource.flutter,
      );
    };

    // プラットフォーム（Dart VM）のエラー
    PlatformDispatcher.instance.onError = (error, stack) {
      _handleError(
        error,
        stack,
        context: 'PlatformDispatcher.onError',
        errorSource: ErrorSource.platform,
      );
      return true; // エラーを処理済みとしてマーク
    };
  }

  /// runZonedGuarded内で発生したエラーを処理
  static void handleZoneError(Object error, StackTrace stack) {
    _handleError(
      error,
      stack,
      context: 'runZonedGuarded',
      errorSource: ErrorSource.zone,
    );
  }

  /// 手動でエラーをログに記録
  static void log(Object error, StackTrace? stack, {String? context}) {
    _handleError(
      error,
      stack,
      context: context ?? 'Manual Error Log',
      errorSource: ErrorSource.manual,
    );
  }

  /// デバッグモード専用のエラーログ
  static void debugLog(Object error, StackTrace? stack, {String? context}) {
    if (!kDebugMode) return;

    AppLogger.d(LogTag.app, context ?? 'DebugError', error, stack);
  }

  /// エラーを内部処理
  static void _handleError(
    Object error,
    StackTrace? stack, {
    required String context,
    required ErrorSource errorSource,
  }) {
    if (_shouldIgnoreError(error)) {
      return;
    }

    // 再入防止: エラーハンドリング中に別のエラーが発生した場合
    if (_isHandlingError) {
      // エラーハンドリング中のエラーは標準出力のみ
      debugPrint('Error in error handler.'); // audit: allow
      return;
    }

    _isHandlingError = true;
    try {
      // ログに出力
      AppLogger.e(LogTag.app, context, error, stack);

      // クラッシュレポートを記録
      if (_crashReportEnabled) {
        _recordCrashReport(error, stack, context, errorSource);
      }
    } finally {
      _isHandlingError = false;
    }
  }

  static bool _shouldIgnoreError(Object error) {
    // String-based developer diagnostics must never evaluate arbitrary errors
    // in release mode. Non-Flutter exceptions need no message inspection.
    if (kReleaseMode || error is! FlutterError) return false;
    final message = error.toString();
    if (message.contains(
      "Looking up a deactivated widget's ancestor is unsafe",
    )) {
      return true;
    }
    return false;
  }

  /// クラッシュレポートを記録（非同期、ベストエフォート）
  static void _recordCrashReport(
    Object error,
    StackTrace? stack,
    String context,
    ErrorSource source,
  ) {
    // Fire-and-forget でクラッシュレポートを記録
    // エラー処理中に別のエラーが発生しても無視する
    Future(() async {
      try {
        await CrashReportService.instance.recordError(
          error,
          stack,
          context: context,
          additionalData: {'errorSource': source.name},
        );
      } catch (_) {
        // クラッシュレポートの記録に失敗しても無視
        // ここでエラーをログに出すと無限ループの可能性があるため
      }
    });
  }

  /// 未処理の非同期エラーを報告
  ///
  /// Future内で発生した未処理エラーをキャッチする場合に使用。
  /// 例: `Future.error(e).catchError(GlobalErrorHandler.reportAsyncError)`
  static void reportAsyncError(Object error, StackTrace stack) {
    _handleError(
      error,
      stack,
      context: 'Async Error',
      errorSource: ErrorSource.async,
    );
  }

  /// エラー境界用のハンドラー
  ///
  /// UIウィジェット内でのエラーをキャッチする場合に使用。
  static void reportWidgetError(
    Object error,
    StackTrace? stack, {
    String? widgetName,
  }) {
    _handleError(
      error,
      stack,
      context: widgetName != null
          ? 'Widget Error: $widgetName'
          : 'Widget Error',
      errorSource: ErrorSource.widget,
    );
  }
}

/// エラーの発生源
enum ErrorSource {
  /// Flutter フレームワーク（FlutterError.onError）
  flutter,

  /// プラットフォーム/Dart VM（PlatformDispatcher.onError）
  platform,

  /// Zoneエラー（runZonedGuarded）
  zone,

  /// 非同期エラー
  async,

  /// ウィジェットエラー
  widget,

  /// 手動記録
  manual,
}
