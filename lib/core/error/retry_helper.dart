import '../logger/app_logger.dart';
import '../logger/log_tag.dart';
import 'app_error.dart';
import 'result.dart';
import 'retry_policy.dart';

/// Result型を返す操作をリトライポリシーに従って実行する
///
/// [operation] 実行する操作
/// [policy] リトライポリシー（デフォルトは3回まで）
/// [context] エラー発生時に追加するコンテキスト情報
///
/// 使用例:
/// ```dart
/// final result = await withRetry(
///   () => repository.getData(),
///   policy: RetryPolicy.network,
///   context: 'GetDataUseCase.execute',
/// );
/// ```
Future<Result<T, AppError>> withRetry<T>(
  Future<Result<T, AppError>> Function() operation, {
  RetryPolicy policy = const RetryPolicy(),
  String? context,
}) async {
  var attempt = 0;

  while (attempt < policy.maxAttempts) {
    attempt++;

    // 2回目以降は遅延を入れる
    if (attempt > 1) {
      final delay = policy.getDelay(attempt - 1);
      AppLogger.d(
        LogTag.app,
        'Retry attempt $attempt/${policy.maxAttempts} after ${delay.inMilliseconds}ms',
      );
      await Future.delayed(delay);
    }

    // 操作を実行
    final result = await operation();

    // 成功した場合は即座に返す
    if (result.isSuccess) {
      if (attempt > 1) {
        AppLogger.i(LogTag.app, 'Operation succeeded after $attempt attempts');
      }
      return result;
    }

    final error = result.errorOrNull!;

    // リトライ不可能なエラーまたは最終試行の場合
    if (!policy.canRetry(error) || attempt >= policy.maxAttempts) {
      if (!policy.canRetry(error)) {
        AppLogger.d(
          LogTag.app,
          'Error is not retryable: ${error.category.name}',
        );
      } else {
        AppLogger.w(
          LogTag.app,
          'Operation failed after $attempt attempts',
          error,
        );
      }

      // コンテキストを追加して返す
      if (context != null) {
        return Result.failure(error.withContext(context));
      }
      return result;
    }

    // リトライ可能なエラーの場合はログを出力して次の試行へ
    AppLogger.d(
      LogTag.app,
      'Retryable error occurred (attempt $attempt/${policy.maxAttempts}): ${error.message}',
    );
  }

  // 到達しないはずだが、型安全性のため
  return Result.failure(
    AppError.unknown(
      'Retry logic error',
      severity: ErrorSeverity.critical,
      context: context,
    ),
  );
}
