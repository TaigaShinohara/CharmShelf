import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'log_level.dart';
import 'log_tag.dart';

/// アプリケーション全体で使用するロガー
///
/// レベル別の色付き出力（IDE対応）、タグによる分類、エラー/スタックトレースの
/// 自動フォーマットをサポートします。
///
/// 使用例:
/// ```dart
/// AppLogger.i(LogTag.auth, 'ユーザー認証成功');
/// AppLogger.e(LogTag.db, 'データベースエラー', error, stackTrace);
/// ```
class AppLogger {
  AppLogger._();

  /// 最小ログレベル（これ未満のログは出力されない）
  static LogLevel _minLevel = kDebugMode ? LogLevel.info : LogLevel.error;

  /// 最小ログレベルを設定
  static void setMinLevel(LogLevel level) {
    _minLevel = level;
  }

  /// 現在の最小ログレベルを取得
  static LogLevel get minLevel => _minLevel;

  /// VERBOSEレベルのログを出力
  static void v(
    LogTag tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    _log(LogLevel.verbose, tag, message, error, stack);
  }

  /// DEBUGレベルのログを出力
  static void d(
    LogTag tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    _log(LogLevel.debug, tag, message, error, stack);
  }

  /// INFOレベルのログを出力
  static void i(
    LogTag tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    _log(LogLevel.info, tag, message, error, stack);
  }

  /// WARNINGレベルのログを出力
  static void w(
    LogTag tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    _log(LogLevel.warning, tag, message, error, stack);
  }

  /// ERRORレベルのログを出力
  static void e(
    LogTag tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    _log(LogLevel.error, tag, message, error, stack);
  }

  /// ログを出力（内部メソッド）
  static void _log(
    LogLevel level,
    LogTag tag,
    String message,
    Object? error,
    StackTrace? stack,
  ) {
    // 最小レベル未満のログはスキップ
    if (level.priority < _minLevel.priority) return;

    // タイムスタンプ（時:分:秒.ミリ秒）
    final now = DateTime.now();
    final timestamp =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${now.millisecond.toString().padLeft(3, '0')}';

    // ログメッセージを構築
    final safeMessage = kReleaseMode ? 'Operation failed' : message;
    final safeError = kReleaseMode ? null : error;
    final safeStack = kReleaseMode ? null : stack;
    final logMessage =
        '[$timestamp] ${level.icon} ${level.name.toUpperCase().padRight(7)} '
        '[${tag.name.toUpperCase().padRight(10)}] $safeMessage';

    // コンソールに出力（debugPrint）
    debugPrint(logMessage);

    // エラー情報を出力
    if (safeError != null) {
      debugPrint('    └─ Error: $safeError');
    }

    // スタックトレースを出力
    if (safeStack != null) {
      _printStackTrace(safeStack);
    }

    // dart:developerのlogも呼び出し（IDE対応）
    developer.log(
      safeMessage,
      name: tag.name.toUpperCase(),
      level: level.developerLevel,
      error: safeError,
      stackTrace: safeStack,
    );
  }

  /// スタックトレースを出力
  static void _printStackTrace(StackTrace stack) {
    final lines = stack.toString().split('\n');
    const maxLines = 10;

    debugPrint('    ┌─ StackTrace:');
    for (var i = 0; i < lines.length && i < maxLines; i++) {
      final line = lines[i].trim();
      if (line.isNotEmpty) {
        debugPrint('    │ $line');
      }
    }
    if (lines.length > maxLines) {
      debugPrint('    │ ... and ${lines.length - maxLines} more lines');
    }
    debugPrint('    └─');
  }

  /// 区切り線を出力（デバッグ用）
  static void separator([String? label]) {
    if (_minLevel.priority > LogLevel.debug.priority) return;

    String output;
    if (label != null) {
      final paddedLabel = ' $label ';
      final leftPad = (60 - paddedLabel.length) ~/ 2;
      final rightPad = 60 - paddedLabel.length - leftPad;
      output = '─' * leftPad + paddedLabel + '─' * rightPad;
    } else {
      output = '─' * 60;
    }

    debugPrint(output);
  }

  /// JSONオブジェクトを整形して出力
  static void json(LogTag tag, String label, Map<String, dynamic> data) {
    if (_minLevel.priority > LogLevel.debug.priority) return;

    d(tag, '$label:');
    for (final entry in data.entries) {
      debugPrint('    ${entry.key}: ${entry.value}');
    }
  }

  /// パフォーマンス計測用のタイマーを開始
  static Stopwatch startTimer(LogTag tag, String operation) {
    v(tag, '⏱️ Started: $operation');
    return Stopwatch()..start();
  }

  /// パフォーマンス計測結果を出力
  static void endTimer(LogTag tag, String operation, Stopwatch stopwatch) {
    stopwatch.stop();
    final elapsed = stopwatch.elapsedMilliseconds;
    final message = '⏱️ Completed: $operation (${elapsed}ms)';

    if (elapsed > 1000) {
      w(tag, message);
    } else if (elapsed > 100) {
      i(tag, message);
    } else {
      v(tag, message);
    }
  }
}
