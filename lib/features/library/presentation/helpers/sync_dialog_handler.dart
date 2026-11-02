import 'package:flutter/material.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/features/library/domain/models/sync_progress.dart';
import 'package:private_shelf/features/library/presentation/widgets/sync_progress_dialog.dart';

/// 同期進捗ダイアログのライフサイクルと表示・非表示を管理するハンドラー
class SyncDialogHandler {
  bool _isSyncDialogVisible = false;
  bool _isSyncDialogOpening = false;
  Route<void>? _syncDialogRoute;

  /// 同期の状態変更をリスニングし、ダイアログを自動制御する
  void handleSyncProgressChange(
    BuildContext context,
    SyncProgress? previous,
    SyncProgress next,
    String modeLabel,
  ) {
    if (previous?.status != next.status) {
      AppLogger.d(
        LogTag.ui,
        '$modeLabel同期状態: ${previous?.status.name ?? 'none'} -> ${next.status.name}',
      );
    }
    if (isActiveSyncStatus(next.status)) {
      showSyncDialogIfNeeded(context);
    } else {
      hideSyncDialogIfNeeded();
    }
  }

  /// 現在進行中（Active）な同期ステータスか判定
  bool isActiveSyncStatus(SyncStatus status) {
    return status == SyncStatus.scanning || status == SyncStatus.processing;
  }

  /// 必要に応じて同期ダイアログを表示
  void showSyncDialogIfNeeded(BuildContext context) {
    if (_isSyncDialogVisible || _isSyncDialogOpening) return;
    _isSyncDialogOpening = true;
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const PopScope(canPop: false, child: SyncProgressDialog()),
    );
    _syncDialogRoute = route;
    Navigator.of(context).push(route).then((_) {
      _isSyncDialogVisible = false;
      _syncDialogRoute = null;
    });
    _isSyncDialogVisible = true;
    _isSyncDialogOpening = false;
  }

  /// 必要に応じて同期ダイアログを非表示
  void hideSyncDialogIfNeeded() {
    if (!_isSyncDialogVisible && _syncDialogRoute == null) return;
    removeSyncDialogRoute();
  }

  /// ダイアログのルートを手動削除
  void removeSyncDialogRoute() {
    final route = _syncDialogRoute;
    if (route != null) {
      if (route.isActive) {
        route.navigator?.removeRoute(route);
      }
      _syncDialogRoute = null;
    }
    _isSyncDialogVisible = false;
    _isSyncDialogOpening = false;
  }

  /// リソースの破棄処理（State.dispose時に呼出）
  void dispose() {
    removeSyncDialogRoute();
  }
}
