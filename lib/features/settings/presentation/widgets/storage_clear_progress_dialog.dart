import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logger/app_logger.dart';
import '../../../../core/logger/log_tag.dart';
import '../../../../gen_l10n/app_localizations.dart';
import '../../data/services/storage_clear_service.dart';

/// ストレージ消去ダイアログの結果
enum StorageClearDialogResult {
  /// 中断された
  cancelled,

  /// 正常に消去完了した
  success,

  /// 消去に失敗した
  failed,
}

/// ストレージ消去のカウントダウンおよび実行中プログレスを表示するダイアログ
class StorageClearProgressDialog extends ConsumerStatefulWidget {
  const StorageClearProgressDialog({super.key});

  /// ダイアログを表示するヘルパーメソッド
  static Future<StorageClearDialogResult?> show(BuildContext context) {
    return showDialog<StorageClearDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const StorageClearProgressDialog(),
    );
  }

  @override
  ConsumerState<StorageClearProgressDialog> createState() =>
      _StorageClearProgressDialogState();
}

enum _ProgressPhase { countdown, clearing, retryRequired }

class _StorageClearProgressDialogState
    extends ConsumerState<StorageClearProgressDialog> {
  static const int _initialCountdownSeconds = 5;

  _ProgressPhase _phase = _ProgressPhase.countdown;
  int _remainingSeconds = _initialCountdownSeconds;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds <= 1) {
        timer.cancel();
        _startClearing();
      } else {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  Future<void> _startClearing() async {
    if (!mounted) return;

    setState(() {
      _phase = _ProgressPhase.clearing;
    });

    try {
      final clearService = await ref.read(storageClearServiceProvider.future);
      final result = await clearService.clearStorage();

      if (!mounted) return;

      if (result.isSuccess) {
        Navigator.pop(context, StorageClearDialogResult.success);
      } else {
        await _handleFailure(clearService);
      }
    } catch (e, st) {
      AppLogger.e(LogTag.storage, 'ストレージ消去ダイアログ内での実行エラー', e, st);
      if (!mounted) return;
      Navigator.pop(context, StorageClearDialogResult.failed);
    }
  }

  Future<void> _retryPendingClear() async {
    if (!mounted) return;
    setState(() => _phase = _ProgressPhase.clearing);
    try {
      final clearService = await ref.read(storageClearServiceProvider.future);
      final result = await clearService.recoverPendingClear();
      if (!mounted) return;
      if (result.isSuccess) {
        Navigator.pop(context, StorageClearDialogResult.success);
      } else {
        await _handleFailure(clearService);
      }
    } catch (e, st) {
      AppLogger.e(LogTag.storage, 'ストレージ消去の再試行に失敗しました', e, st);
      if (mounted) setState(() => _phase = _ProgressPhase.retryRequired);
    }
  }

  Future<void> _handleFailure(StorageClearService clearService) async {
    var pending = true;
    try {
      pending = await clearService.hasPendingClear();
    } catch (e, st) {
      AppLogger.e(LogTag.storage, 'ストレージ消去の保留状態を確認できませんでした', e, st);
    }
    if (!mounted) return;
    if (pending) {
      setState(() => _phase = _ProgressPhase.retryRequired);
    } else {
      Navigator.pop(context, StorageClearDialogResult.failed);
    }
  }

  void _handleCancel() {
    if (_phase == _ProgressPhase.countdown) {
      _countdownTimer?.cancel();
      Navigator.pop(context, StorageClearDialogResult.cancelled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _phase == _ProgressPhase.countdown) {
          _handleCancel();
        }
      },
      child: AlertDialog(
        title: Row(
          children: [
            Icon(switch (_phase) {
              _ProgressPhase.countdown => Icons.timer_outlined,
              _ProgressPhase.clearing => Icons.delete_forever_outlined,
              _ProgressPhase.retryRequired => Icons.error_outline,
            }, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _phase == _ProgressPhase.countdown
                    ? l10n.settingsStorageClearCountdownTitle
                    : _phase == _ProgressPhase.clearing
                    ? l10n.settingsStorageClearDeletingTitle
                    : l10n.settingsStorageClearFailed,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_phase == _ProgressPhase.countdown) ...[
              const SizedBox(height: 8),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      value: _remainingSeconds / _initialCountdownSeconds,
                      strokeWidth: 6,
                      color: theme.colorScheme.error,
                      backgroundColor: theme.colorScheme.errorContainer,
                    ),
                  ),
                  Text(
                    '$_remainingSeconds',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.settingsStorageClearCountdownSeconds(_remainingSeconds),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.settingsStorageClearCountdownMessage,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ] else if (_phase == _ProgressPhase.clearing) ...[
              const SizedBox(height: 16),
              CircularProgressIndicator(color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(
                l10n.settingsStorageClearDeletingMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                l10n.settingsStorageClearRetryMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
        actions: _phase == _ProgressPhase.countdown
            ? [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _handleCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(
                      l10n.settingsStorageClearCancelNow,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ]
            : _phase == _ProgressPhase.retryRequired
            ? [
                FilledButton.icon(
                  onPressed: _retryPendingClear,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.commonRetry),
                ),
              ]
            : const [],
      ),
    );
  }
}
