import 'package:flutter/material.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/features/library/domain/models/sync_progress.dart';
import 'package:private_shelf/features/library/presentation/providers/sync_progress_provider.dart';
import 'package:private_shelf/shared/widgets/dialogs/dialog_actions.dart';

class SyncProgressDialog extends ConsumerWidget {
  const SyncProgressDialog({super.key});

  Future<void> _handleCancel(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.importCancelConfirmTitle),
        content: Text(l10n.importCancelConfirmMessage),
        actions: [
          DialogActionRow(
            leading: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.importCancelContinueAction),
            ),
            trailing: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.importCancelConfirmAction),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      ref.read(syncProgressNotifierProvider.notifier).cancel();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(syncProgressNotifierProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      actionsAlignment: MainAxisAlignment.spaceBetween,
      title: Text(
        progress.status == SyncStatus.error
            ? l10n.commonErrorOccurred
            : (progress.status == SyncStatus.cancelling
                  ? l10n.commonCancelling
                  : l10n.commonProcessing),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (progress.status == SyncStatus.scanning)
            Text(l10n.syncStatusScanning)
          else if (progress.status == SyncStatus.processing)
            Text(
              l10n.syncStatusProcessing(
                progress.processedItems,
                progress.totalItems,
              ),
            )
          else if (progress.status == SyncStatus.cancelling)
            Text(l10n.importRollingBack)
          else if (progress.status == SyncStatus.error)
            Text(
              l10n.errorFile,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          const SizedBox(height: 16),
          if (progress.status != SyncStatus.error)
            LinearProgressIndicator(
              value: progress.status == SyncStatus.processing
                  ? progress.progress
                  : null,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          if (progress.currentFileName != null &&
              progress.status != SyncStatus.error &&
              progress.status != SyncStatus.cancelling) ...[
            const SizedBox(height: 12),
            Text(
              progress.currentFileName!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (progress.status == SyncStatus.scanning ||
              progress.status == SyncStatus.processing) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.importDoNotCloseWarning,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (progress.status == SyncStatus.error)
          DialogCloseButton(
            onPressed: () => Navigator.of(context).pop(),
            semanticLabel: l10n.commonClose,
          )
        else if (progress.status == SyncStatus.scanning ||
            progress.status == SyncStatus.processing ||
            progress.status == SyncStatus.cancelling)
          DialogCloseButton(
            onPressed: progress.status == SyncStatus.cancelling
                ? null
                : () => _handleCancel(context, ref),
            semanticLabel: progress.status == SyncStatus.cancelling
                ? l10n.commonCancelling
                : l10n.commonCancel,
          ),
      ],
    );
  }
}
