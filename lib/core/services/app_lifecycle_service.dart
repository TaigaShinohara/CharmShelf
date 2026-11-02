import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../logger/app_logger.dart';
import '../logger/log_tag.dart';

/// アプリのライフサイクル状態
enum AppLifecycleStatus {
  /// フォアグラウンド（アクティブ）
  foreground,

  /// 非アクティブ（電話着信、マルチタスク切り替え中など）
  inactive,

  /// バックグラウンド
  background,

  /// 終了処理中（Androidのみ）
  detached,
}

/// アプリライフサイクルを管理するNotifier
///
/// `WidgetsBindingObserver` を使ってライフサイクル変化を検知し、
/// Riverpod の状態として提供します。
class AppLifecycleNotifier extends StateNotifier<AppLifecycleStatus>
    with WidgetsBindingObserver {
  AppLifecycleNotifier() : super(AppLifecycleStatus.foreground) {
    WidgetsBinding.instance.addObserver(this);
    AppLogger.d(LogTag.lifecycle, 'AppLifecycleNotifier initialized');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final newStatus = _mapState(state);
    if (newStatus != this.state) {
      AppLogger.i(LogTag.lifecycle, 'App lifecycle changed: ${newStatus.name}');
      this.state = newStatus;
    }
  }

  AppLifecycleStatus _mapState(AppLifecycleState state) {
    return switch (state) {
      AppLifecycleState.resumed => AppLifecycleStatus.foreground,
      AppLifecycleState.inactive => AppLifecycleStatus.inactive,
      AppLifecycleState.paused => AppLifecycleStatus.background,
      AppLifecycleState.detached => AppLifecycleStatus.detached,
      AppLifecycleState.hidden => AppLifecycleStatus.background,
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppLogger.d(LogTag.lifecycle, 'AppLifecycleNotifier disposed');
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// アプリライフサイクル状態のProvider
///
/// 使い方:
/// ```dart
/// final status = ref.watch(appLifecycleProvider);
/// if (status == AppLifecycleStatus.foreground) {
///   // フォアグラウンド復帰時の処理
/// }
/// ```
final appLifecycleProvider =
    StateNotifierProvider<AppLifecycleNotifier, AppLifecycleStatus>((ref) {
      return AppLifecycleNotifier();
    });

/// フォアグラウンドかどうかを簡易的に取得するProvider
final isAppForegroundProvider = Provider<bool>((ref) {
  final status = ref.watch(appLifecycleProvider);
  return status == AppLifecycleStatus.foreground;
});

/// バックグラウンドかどうかを簡易的に取得するProvider
final isAppBackgroundProvider = Provider<bool>((ref) {
  final status = ref.watch(appLifecycleProvider);
  return status == AppLifecycleStatus.background;
});
