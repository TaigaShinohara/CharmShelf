import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logger/app_logger.dart';
import '../logger/log_tag.dart';

/// 接続状態
enum ConnectionStatus {
  /// オンライン（Wi-Fi、モバイル、イーサネット等）
  online,

  /// オフライン
  offline,
}

/// 接続状態を監視するサービス
class ConnectivityService {
  bool _started = false;

  final Connectivity _connectivity = Connectivity();
  final _controller = StreamController<ConnectionStatus>.broadcast();

  Stream<ConnectionStatus> get statusStream => _controller.stream;
  ConnectionStatus _currentStatus = ConnectionStatus.offline;
  ConnectionStatus get currentStatus => _currentStatus;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// 監視を開始（必要になるまで遅延させる）
  ///
  /// Dart は single-threaded なので、同期コード内で複数回呼ばれることはない。
  /// `_started` フラグのみで十分にガードできる。
  void start() {
    if (_started) return;
    _started = true;
    _init();
  }

  void _init() {
    // Bug 1 fix: 初期状態取得時のエラーハンドリングを追加
    _connectivity.checkConnectivity().then(
      _handleConnectivityChange,
      onError: (Object error, StackTrace stack) {
        AppLogger.e(LogTag.connectivity, '接続状態の初回取得に失敗', error, stack);
        // エラー時は offline を維持（安全側に倒す）
      },
    );

    // 変化を監視
    _subscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChange,
      onError: (Object error, StackTrace stack) {
        AppLogger.e(LogTag.connectivity, '接続監視ストリームでエラー発生', error, stack);
      },
    );
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final newStatus = _toConnectionStatus(results);
    if (newStatus != _currentStatus) {
      _currentStatus = newStatus;
      _controller.add(newStatus);
      AppLogger.i(
        LogTag.connectivity,
        '接続状態が変化: ${newStatus == ConnectionStatus.online ? 'オンライン' : 'オフライン'}',
      );
    }
  }

  ConnectionStatus _toConnectionStatus(List<ConnectivityResult> results) {
    // 接続なし、または none のみの場合はオフライン
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return ConnectionStatus.offline;
    }
    return ConnectionStatus.online;
  }

  /// 現在の接続状態を確認
  Future<ConnectionStatus> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _handleConnectivityChange(results);
    return _currentStatus;
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// ConnectivityService のシングルトンProvider
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

/// 接続状態のStreamProvider
///
/// 使い方:
/// ```dart
/// final status = ref.watch(connectivityStatusProvider);
/// status.when(
///   data: (s) => s == ConnectionStatus.online ? ... : ...,
///   loading: () => ...,
///   error: (e, st) => ...,
/// );
/// ```
final connectivityStatusProvider = StreamProvider<ConnectionStatus>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  service.start();
  // 初期値を先に流してからストリームに接続
  return Stream.value(
    service.currentStatus,
  ).asyncExpand((_) => service.statusStream);
});

/// 同期的に接続状態を取得するProvider（初期値はoffline）
final isOnlineProvider = Provider<bool>((ref) {
  final asyncStatus = ref.watch(connectivityStatusProvider);
  return asyncStatus.value == ConnectionStatus.online;
});
