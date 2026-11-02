import 'dart:math';

import 'app_error.dart';

/// リトライポリシー
///
/// エラー発生時の再試行戦略を定義します。
class RetryPolicy {
  /// 最大試行回数
  final int maxAttempts;

  /// 初回の遅延時間
  final Duration initialDelay;

  /// 最大遅延時間
  final Duration maxDelay;

  /// バックオフ倍率（指数バックオフ用）
  final double backoffMultiplier;

  /// リトライ可否を判定するカスタムロジック
  final bool Function(AppError error)? shouldRetry;

  const RetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 10),
    this.backoffMultiplier = 2.0,
    this.shouldRetry,
  });

  /// ネットワークエラー用のプリセット
  static const RetryPolicy network = RetryPolicy(
    maxAttempts: 3,
    initialDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 10),
    backoffMultiplier: 2.0,
  );

  /// データベースエラー用のプリセット
  static const RetryPolicy database = RetryPolicy(
    maxAttempts: 2,
    initialDelay: Duration(milliseconds: 100),
    maxDelay: Duration(seconds: 1),
    backoffMultiplier: 2.0,
  );

  /// リトライなし
  static const RetryPolicy none = RetryPolicy(maxAttempts: 1);

  /// 指定された試行回数に対する遅延時間を計算（指数バックオフ）
  ///
  /// [attemptNumber] 試行回数（1から開始）
  Duration getDelay(int attemptNumber) {
    final delay = initialDelay * pow(backoffMultiplier, attemptNumber - 1);
    return delay > maxDelay ? maxDelay : delay;
  }

  /// エラーがリトライ可能かどうかを判定
  ///
  /// [error] 判定対象のエラー
  bool canRetry(AppError error) {
    if (shouldRetry != null) {
      return shouldRetry!(error);
    }

    // デフォルト: ネットワークエラーとデータベースエラーはリトライ可能
    return error.category == ErrorCategory.network ||
        error.category == ErrorCategory.database;
  }
}
