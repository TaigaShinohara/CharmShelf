import 'package:connectivity_plus/connectivity_plus.dart';

import '../logger/app_logger.dart';
import '../logger/log_tag.dart';
import 'app_error.dart';
import 'result.dart';

/// ネットワーク接続状態をチェックするユーティリティ
class ConnectivityChecker {
  ConnectivityChecker._();

  /// ネットワーク接続状態を確認
  ///
  /// 戻り値: `Result<bool, AppError>`
  /// - `true`: オンライン（接続あり）
  /// - `false`: オフライン（接続なし）
  static Future<Result<bool, AppError>> checkConnectivity() async {
    try {
      final connectivity = Connectivity();
      final results = await connectivity.checkConnectivity();

      // 接続なし、または none のみの場合はオフライン
      final isConnected =
          results.isNotEmpty &&
          !results.every((r) => r == ConnectivityResult.none);

      return Result.success(isConnected);
    } catch (e, st) {
      AppLogger.e(LogTag.connectivity, 'Connectivity check failed', e, st);
      return Result.failure(
        AppError.network(
          'Failed to check connectivity',
          severity: ErrorSeverity.warning,
          original: e,
          stackTrace: st,
          context: 'ConnectivityChecker.checkConnectivity',
        ),
      );
    }
  }

  /// オフライン時のエラーを生成
  ///
  /// ネットワーク操作を行う前にオフラインであることが分かっている場合に使用
  static AppError offlineError() {
    return AppError.network(
      'No internet connection',
      severity: ErrorSeverity.warning,
      context: 'Offline',
    );
  }
}
