import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../shared/widgets/feedback/app_snackbar.dart';
import 'snackbar_config.dart';
import 'snackbar_providers.dart';

part 'snackbar_service.g.dart';

/// SnackBar表示を一元管理するサービス
///
/// 使用例:
/// ```dart
/// ref.read(snackBarServiceProvider).show(
///   context: context,
///   message: '保存しました',
///   type: SnackBarType.success,
/// );
/// ```
class SnackBarService {
  SnackBarService(this._ref);

  final Ref _ref;
  GlobalKey<ScaffoldMessengerState>? _messengerKey;

  /// ScaffoldMessengerKeyを設定（アプリ初期化時に呼び出す）
  void setMessengerKey(GlobalKey<ScaffoldMessengerState> key) {
    _messengerKey = key;
  }

  /// 現在の設定を取得
  SnackBarConfig get _config => _ref.read(snackBarConfigNotifierProvider);

  /// SnackBarを表示
  ///
  /// [context] BuildContext（Overlayアクセス用、上部表示時に必要）
  /// [message] 表示するメッセージ
  /// [type] SnackBarのタイプ（success, error, warning, info, default）
  /// [action] アクションボタン
  /// [duration] 表示時間（省略時は設定値を使用）
  void show({
    BuildContext? context,
    required String message,
    SnackBarType type = SnackBarType.defaultType,
    SnackBarAction? action,
    Duration? duration,
  }) {
    final config = duration != null
        ? _config.copyWith(duration: duration)
        : _config;

    if (config.position == SnackBarPosition.top && context != null) {
      // 上部表示の場合はOverlayを使用
      TopSnackBarOverlay.show(
        context: context,
        message: message,
        config: config,
        type: type,
        action: action,
      );
    } else {
      // 下部表示の場合は標準SnackBar
      _showBottomSnackBar(
        context: context,
        message: message,
        config: config,
        type: type,
        action: action,
      );
    }
  }

  /// 下部にSnackBarを表示
  void _showBottomSnackBar({
    BuildContext? context,
    required String message,
    required SnackBarConfig config,
    required SnackBarType type,
    SnackBarAction? action,
  }) {
    final snackBar = AppSnackBar.create(
      message: message,
      config: config,
      type: type,
      action: action,
    );

    // GlobalKeyがあればそれを使用、なければcontextから取得
    if (context != null) {
      final messenger = AppSnackBarMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(snackBar);
      return;
    }

    if (appSnackBarOverlayKey.currentState != null) {
      AppSnackBarMessenger.showGlobal(snackBar);
      return;
    }

    final messenger = _messengerKey?.currentState;
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(snackBar);
  }

  /// 成功メッセージを表示
  void success({
    BuildContext? context,
    required String message,
    SnackBarAction? action,
    Duration? duration,
  }) {
    show(
      context: context,
      message: message,
      type: SnackBarType.success,
      action: action,
      duration: duration,
    );
  }

  /// エラーメッセージを表示
  void error({
    BuildContext? context,
    required String message,
    SnackBarAction? action,
    Duration? duration,
  }) {
    show(
      context: context,
      message: message,
      type: SnackBarType.error,
      action: action,
      duration: duration,
    );
  }

  /// 警告メッセージを表示
  void warning({
    BuildContext? context,
    required String message,
    SnackBarAction? action,
    Duration? duration,
  }) {
    show(
      context: context,
      message: message,
      type: SnackBarType.warning,
      action: action,
      duration: duration,
    );
  }

  /// 情報メッセージを表示
  void info({
    BuildContext? context,
    required String message,
    SnackBarAction? action,
    Duration? duration,
  }) {
    show(
      context: context,
      message: message,
      type: SnackBarType.info,
      action: action,
      duration: duration,
    );
  }

  /// 現在のSnackBarを非表示
  void hide({BuildContext? context}) {
    // 上部表示のOverlayを非表示
    TopSnackBarOverlay.hide();

    // 下部表示のSnackBarを非表示
    if (context != null) {
      AppSnackBarMessenger.maybeOf(context)?.hideCurrentSnackBar();
    } else if (appSnackBarOverlayKey.currentState != null) {
      AppSnackBarMessenger.hideGlobal();
    } else {
      _messengerKey?.currentState?.hideCurrentSnackBar();
    }
  }

  /// 全てのSnackBarを非表示
  void hideAll({BuildContext? context}) {
    TopSnackBarOverlay.hide();
    if (context != null) {
      AppSnackBarMessenger.maybeOf(context)?.clearSnackBars();
    } else if (appSnackBarOverlayKey.currentState != null) {
      AppSnackBarMessenger.clearGlobal();
    } else {
      _messengerKey?.currentState?.clearSnackBars();
    }
  }
}

@Riverpod(keepAlive: true)
SnackBarService snackBarService(Ref ref) {
  return SnackBarService(ref);
}
