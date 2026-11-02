import 'package:flutter/material.dart';
import 'package:private_shelf/shared/icons/library_action_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:private_shelf/core/error/user_safe_error_message.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/core/feedback/snackbar_service.dart';
import 'package:private_shelf/core/theme/app_tokens.dart';
import 'package:private_shelf/features/library/domain/models/restorable_data_summary.dart';
import 'package:private_shelf/features/library/domain/models/sync_progress.dart';
import 'package:private_shelf/features/library/presentation/providers/data_restore_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

/// 端末内のデータを自動復元し、その結果をユーザーに報告してアプリを開始させる画面。
class DataRestoreScreen extends ConsumerStatefulWidget {
  const DataRestoreScreen({
    super.key,
    required this.summary,
    required this.onRestoreCompleted,
    required this.onSkipped,
    this.autoStartRestore = true,
  });

  final RestorableDataSummary summary;
  final VoidCallback onRestoreCompleted;
  final VoidCallback onSkipped;
  final bool autoStartRestore;

  @override
  ConsumerState<DataRestoreScreen> createState() => _DataRestoreScreenState();
}

class _DataRestoreScreenState extends ConsumerState<DataRestoreScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.autoStartRestore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerAutoRestore();
      });
    }
  }

  void _triggerAutoRestore() {
    final status = ref.read(dataRestoreNotifierProvider).status;
    if (status == DataRestoreStatus.readyToRestore ||
        status == DataRestoreStatus.idle) {
      ref.read(dataRestoreNotifierProvider.notifier).executeRestore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final restoreState = ref.watch(dataRestoreNotifierProvider);
    final isRestoring = restoreState.status == DataRestoreStatus.restoring;
    final isSuccess = restoreState.status == DataRestoreStatus.success;
    final isPermissionRequired =
        restoreState.status == DataRestoreStatus.permissionRequired;
    final isError =
        restoreState.status == DataRestoreStatus.error || isPermissionRequired;
    final reportedSummary = restoreState.summary.hasAnyItems
        ? restoreState.summary
        : widget.summary;

    ref.listen(dataRestoreNotifierProvider, (previous, next) {
      if (next.status == DataRestoreStatus.success &&
          previous?.status != DataRestoreStatus.success) {
        ref
            .read(snackBarServiceProvider)
            .success(context: context, message: l10n.dataRestoreSuccess);
      } else if (next.status == DataRestoreStatus.error && next.error != null) {
        ref
            .read(snackBarServiceProvider)
            .error(
              context: context,
              message: userSafeErrorMessage(next.error, l10n),
            );
      }
    });

    final title = isPermissionRequired
        ? l10n.dataRestorePermissionTitle
        : isSuccess
        ? l10n.dataRestoreCompletedTitle
        : (isRestoring ? l10n.dataRestoreInProgress : l10n.dataRestoreTitle);

    final description = isPermissionRequired
        ? l10n.dataRestorePermissionDescription
        : isSuccess
        ? l10n.dataRestoreCompletedDescription
        : l10n.dataRestoreDescription;

    final heroIcon = isSuccess
        ? Icons.check_circle_outline_rounded
        : (isRestoring
              ? Icons.sync_rounded
              : Icons.settings_backup_restore_rounded);

    return PopScope(
      canPop: !isRestoring,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ヒーローアイコン
                    Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.colorScheme.primaryContainer,
                              theme.colorScheme.secondaryContainer.withValues(
                                alpha: 0.7,
                              ),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            heroIcon,
                            size: 44,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // タイトル & 説明
                    Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // 検出データサマリーカード
                    if (!isPermissionRequired) ...[
                      _DataSummaryCard(summary: reportedSummary),
                      const SizedBox(height: 20),
                    ],

                    if (isPermissionRequired)
                      FilledButton.icon(
                        onPressed: () => ref
                            .read(dataRestoreNotifierProvider.notifier)
                            .executeRestore(),
                        icon: const Icon(Icons.folder_open),
                        label: Text(l10n.dataRestoreSelectFolder),
                      ),

                    // インラインエラーバナー
                    if (isError && restoreState.error != null) ...[
                      _ErrorBanner(
                        errorMessage: userSafeErrorMessage(
                          restoreState.error,
                          l10n,
                        ),
                        onRetry: () async {
                          await ref.read(feedbackServiceProvider).lightImpact();
                          await ref
                              .read(dataRestoreNotifierProvider.notifier)
                              .executeRestore();
                        },
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 復元処理中の進捗表示
                    if (isRestoring) ...[
                      _RestoringProgressIndicator(
                        syncProgress: restoreState.syncProgress,
                      ),
                      const SizedBox(height: 24),
                    ],

                    // アクションボタン
                    if (!isError)
                      FilledButton.icon(
                        onPressed: isRestoring
                            ? null
                            : () async {
                                await ref
                                    .read(feedbackServiceProvider)
                                    .lightImpact();
                                widget.onRestoreCompleted();
                              },
                        icon: isRestoring
                            ? const SizedBox(
                                width: AppIconSize.sm,
                                height: AppIconSize.sm,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.arrow_forward_rounded,
                                size: AppIconSize.sm,
                              ),
                        label: Text(
                          isRestoring
                              ? l10n.dataRestoreInProgress
                              : l10n.dataRestoreActionStart,
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else ...[
                      // エラー発生時のフォールバック導線
                      TextButton(
                        onPressed: widget.onSkipped,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          l10n.dataRestoreActionContinue,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DataSummaryCard extends StatelessWidget {
  const _DataSummaryCard({required this.summary});

  final RestorableDataSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd().add_Hm();

    final statItems = [
      _StatItemData(
        icon: const Icon(Icons.perm_media_outlined),
        count: summary.mediaItemCount,
        label: l10n.dataRestoreStatMedia,
        semanticsLabel: l10n.dataRestoreMediaCount(summary.mediaItemCount),
      ),
      _StatItemData(
        icon: const CharmIcon(),
        count: summary.tagCount,
        label: l10n.dataRestoreStatTags,
        semanticsLabel: l10n.dataRestoreTagCount(summary.tagCount),
      ),
      _StatItemData(
        icon: const CatalogizeIcon(),
        count: summary.collectionCount,
        label: l10n.dataRestoreStatCollections,
        semanticsLabel: l10n.dataRestoreCollectionCount(
          summary.collectionCount,
        ),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 安定した3カラム統計タイル
          Row(
            children: [
              for (int i = 0; i < statItems.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _StatTile(data: statItems[i])),
              ],
            ],
          ),
          // 最終保存日時
          if (summary.lastExportedAt != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.35,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      l10n.dataRestoreLastExport(
                        dateFormat.format(summary.lastExportedAt!.toLocal()),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatItemData {
  const _StatItemData({
    required this.icon,
    required this.count,
    required this.label,
    required this.semanticsLabel,
  });

  final Widget icon;
  final int count;
  final String label;
  final String semanticsLabel;
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.data});

  final _StatItemData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isZero = data.count == 0;

    final iconColor = isZero
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
        : theme.colorScheme.primary;
    final countColor = isZero
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
        : theme.colorScheme.onSurface;
    final labelColor = theme.colorScheme.onSurfaceVariant.withValues(
      alpha: isZero ? 0.6 : 0.9,
    );

    return Semantics(
      container: true,
      label: data.semanticsLabel,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.45,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme(
              data: IconThemeData(size: 22, color: iconColor),
              child: data.icon,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${data.count}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: countColor,
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                data.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.errorMessage, required this.onRetry});

  final String errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 20,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  errorMessage,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(l10n.commonRetry),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(
                  color: theme.colorScheme.error.withValues(alpha: 0.6),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: const Size(0, 32),
                textStyle: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestoringProgressIndicator extends StatelessWidget {
  const _RestoringProgressIndicator({required this.syncProgress});

  final SyncProgress syncProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final progressValue = syncProgress.totalItems > 0
        ? (syncProgress.processedItems / syncProgress.totalItems).clamp(
            0.0,
            1.0,
          )
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: progressValue,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.dataRestoreInProgress,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (syncProgress.totalItems > 0)
                Text(
                  '${syncProgress.processedItems} / ${syncProgress.totalItems}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
