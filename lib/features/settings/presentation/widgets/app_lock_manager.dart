import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_application/secure_application.dart';

import '../../../../core/logger/app_logger.dart';
import '../../../../core/logger/log_tag.dart';
import '../../domain/models/privacy_settings.dart';
import '../providers/privacy_settings_provider.dart';

class AppLockManager extends ConsumerStatefulWidget {
  const AppLockManager({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockManager> createState() => _AppLockManagerState();
}

class _AppLockManagerState extends ConsumerState<AppLockManager>
    with WidgetsBindingObserver {
  Stopwatch? _backgroundStopwatch;
  bool? _wasLockedBeforeBackground;
  bool _isResumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isResumed = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.inactive) {
      // 親プラグインはpausedで自動ロックするため、その前に認証状態を記録する。
      _wasLockedBeforeBackground ??=
          SecureApplicationProvider.of(context)?.value.locked ?? true;
    } else if (state == AppLifecycleState.paused) {
      _backgroundStopwatch = Stopwatch()..start();
    } else if (state == AppLifecycleState.resumed) {
      if (_backgroundStopwatch == null) {
        // 生体認証・システムダイアログだけのinactive往復はロックを変更しない。
        _wasLockedBeforeBackground = null;
      }
      // 即時チェックを行ってロック無効時等の1フレーム遅延を防ぐ
      if (mounted) _checkLock();

      // SecureApplicationの状態更新完了に合わせたバックアップチェック
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkLock();
      });
    }
  }

  void _checkLock() {
    if (!_isResumed) return;
    final secureController = SecureApplicationProvider.of(context);
    if (secureController == null) return;

    final settingsState = ref.read(privacySettingsNotifierProvider);
    final settings = settingsState.value;
    if (settings == null) {
      // 設定の読み込みに失敗した状態で保護済み画面を表示し続けない。
      if (settingsState.hasError) {
        secureController.lock();
        AppLogger.w(LogTag.auth, 'プライバシー設定を読み込めないため安全側でロック');
      }
      return;
    }

    if (!settings.isAppLockEnabled) {
      // アプリロックが無効ならば常にアンロック（ファイルピッカー等からの復帰含む）
      // unlock()でlocked状態を解除（open()はsecured状態の解除なので不適切）
      secureController.unlock();
      AppLogger.d(LogTag.ui, 'アプリロック無効: SecureApplicationを解除');
      return;
    }

    if (_backgroundStopwatch == null) {
      // 起動時またはバックグラウンド移動が記録されていない場合
      return;
    }

    _backgroundStopwatch!.stop();
    final elapsed = _backgroundStopwatch!.elapsed;
    final timeoutDuration = _getTimeoutDuration(settings.autoLockTimeout);

    if (_wasLockedBeforeBackground == false &&
        (settings.autoLockTimeout == AutoLockTimeout.never ||
            elapsed <= timeoutDuration)) {
      // タイムアウト以内ならアンロック
      // unlock()でlocked状態を解除（open()はsecured状態の解除なので不適切）
      secureController.unlock();
      AppLogger.d(LogTag.ui, 'タイムアウト以内: SecureApplicationを解除');
    } else {
      // SecureApplication の secured は画面保護設定であり、アプリロックとは
      // 独立している。画面保護が OFF でも明示的にロックする。
      secureController.lock();
      AppLogger.d(LogTag.ui, 'タイムアウト超過: SecureApplicationをロック');
    }

    // リセット
    _backgroundStopwatch = null;
    _wasLockedBeforeBackground = null;
  }

  Duration _getTimeoutDuration(AutoLockTimeout timeout) {
    switch (timeout) {
      case AutoLockTimeout.immediately:
        return Duration.zero;
      case AutoLockTimeout.oneMinute:
        return const Duration(minutes: 1);
      case AutoLockTimeout.fiveMinutes:
        return const Duration(minutes: 5);
      case AutoLockTimeout.tenMinutes:
        return const Duration(minutes: 10);
      case AutoLockTimeout.thirtyMinutes:
        return const Duration(minutes: 30);
      case AutoLockTimeout.never:
        return Duration.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 設定の変更を監視して、ロード完了時や設定変更時にチェックを実行
    ref.listen(privacySettingsNotifierProvider, (previous, next) {
      if (next is AsyncData) {
        _checkLock();
      }
    });

    return widget.child;
  }
}
