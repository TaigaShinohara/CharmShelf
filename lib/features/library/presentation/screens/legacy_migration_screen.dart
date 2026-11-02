import 'dart:async';
import 'package:private_shelf/core/services/storage_operation_gate.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import '../providers/external_library_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_storage/shared_storage.dart' as saf;

import 'package:private_shelf/features/library/data/services/legacy_migration_service.dart';
import 'package:private_shelf/features/library/presentation/providers/legacy_migration_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

class LegacyMigrationScreen extends ConsumerStatefulWidget {
  const LegacyMigrationScreen({
    super.key,
    required this.onCompleted,
    this.onDeferred,
    this.fromSettings = false,
  });
  final FutureOr<void> Function() onCompleted;
  final FutureOr<void> Function()? onDeferred;
  final bool fromSettings;
  @override
  ConsumerState<LegacyMigrationScreen> createState() =>
      _LegacyMigrationScreenState();
}

class _LegacyMigrationScreenState extends ConsumerState<LegacyMigrationScreen> {
  LegacyMigrationRecord? _record;
  bool _busy = true;
  bool _running = false;
  bool _confirming = false;
  bool _failed = false;
  bool _recordUnreadable = true;
  bool _operationBusy = false;
  LegacyIssue? _issue;
  LegacyPhase? _progressPhase;
  int _done = 0;
  int _total = 0;
  @override
  void initState() {
    super.initState();
    _run(() async {
      final service = await ref.read(legacyMigrationServiceProvider.future);
      _record = await service.load();
      _recordUnreadable = false;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_running) return;
    _running = true;
    if (mounted) {
      setState(() {
        _busy = true;
        _failed = false;
        _progressPhase = null;
        _total = 0;
        _issue = null;
        _operationBusy = false;
      });
    }
    try {
      await action();
    } catch (error, stack) {
      AppLogger.e(LogTag.storage, '旧データ処理が完了しませんでした', error, stack);
      _failed = true;
      _operationBusy = error is StorageOperationBusy;
      _issue = error is LegacyMigrationException ? error.issue : null;
      // The persisted phase, not the failed screen action, determines resume.
      try {
        _record = await (await ref.read(
          legacyMigrationServiceProvider.future,
        )).load();
        _recordUnreadable = false;
      } catch (_) {
        _recordUnreadable = true;
      }
    } finally {
      _running = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _inspect() => _run(() async {
    final uri = await saf.openDocumentTree(
      initialUri: Uri.parse(
        'content://com.android.externalstorage.documents/tree/primary%3ADocuments',
      ),
    );
    if (uri == null) return;
    final service = await ref.read(legacyMigrationServiceProvider.future);
    if (_record?.requiresRecovery == true) {
      await service.reconnect(uri);
    } else {
      _record = await service.inspect(uri);
    }
    _recordUnreadable = false;
    ref.invalidate(legacyMigrationRecordProvider);
  });

  Future<void> _execute(bool restore) => _run(() async {
    final service = await ref.read(legacyMigrationServiceProvider.future);
    service.onProgress = (phase, completed, total) {
      if (mounted) {
        setState(() {
          _progressPhase = phase;
          _done = completed;
          _total = total;
        });
      }
    };
    try {
      _record = await service.execute(restore: restore);
      ref.invalidate(legacyMigrationRecordProvider);
    } finally {
      service.onProgress = null;
    }
  });

  Future<void> _finish() => _run(() async {
    final service = await ref.read(legacyMigrationServiceProvider.future);
    await service.finishCleanup();
    ref.invalidate(legacyMigrationRecordProvider);
    await widget.onCompleted();
  });

  Future<void> _defer() => _run(() async {
    final service = await ref.read(legacyMigrationServiceProvider.future);
    final record = await service.load();
    if (record?.requiresRecovery == true) {
      throw StateError('Resume before leaving');
    }
    await widget.onDeferred?.call();
  });

  Future<void> _confirmDiscard() async {
    if (_confirming || _running) return;
    _confirming = true;
    try {
      final l10n = AppLocalizations.of(context)!;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.legacyDiscardTitle),
          scrollable: true,
          content: Text(l10n.legacyDiscardWarning),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.legacyDiscardConfirm),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) await _execute(false);
    } finally {
      _confirming = false;
    }
  }

  Future<void> _resolveReferences() async {
    final registrationSubscription = ref.listenManual(
      externalFolderListProvider,
      (_, _) {},
    );
    try {
      final l10n = AppLocalizations.of(context)!;
      final folders = await ref.read(legacyLinkedCollectionsProvider.future);
      final items = await ref.read(legacyLinkedItemsProvider.future);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.legacyUnlinkTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.legacyUnlinkBody),
                for (final folder in folders)
                  Text(folder.alias ?? folder.title),
                for (final item in items)
                  Text(p.basename(Uri.decodeComponent(item.path))),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.commonCancel),
            ),
            if (folders.isNotEmpty || items.isNotEmpty)
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.legacyUnlinkConfirm),
              ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await StorageOperationGate.maintenance(() async {
        for (final folder in folders) {
          await ref
              .read(externalFolderListProvider.notifier)
              .removeFolder(folder);
        }
        if (items.isNotEmpty) {
          final repository = await ref.read(mediaRepositoryProvider.future);
          // Database references only. Never call a use case that deletes source files.
          final result = await repository.deleteGraph(
            items.map((item) => item.id).toList(),
            [],
          );
          if (result.isFailure) throw result.errorOrNull!;
        }
        ref.invalidate(legacyLinkedCollectionsProvider);
        ref.invalidate(legacyLinkedItemsProvider);
        // Removing a reference may release the Documents grant. Reselect it.
      });
    } finally {
      registrationSubscription.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final record = _record;
    final complete = record?.phase == LegacyPhase.complete;
    final choice = record?.phase == LegacyPhase.choice;
    final canLeave =
        !_busy && !_recordUnreadable && !(record?.requiresRecovery ?? false);
    final completionTitle = switch (record?.completedOutcome) {
      LegacyOutcome.notFound => l10n.legacyNotFoundTitle,
      LegacyOutcome.restored => l10n.legacyRestoredTitle,
      LegacyOutcome.deleted => l10n.legacyDeletedTitle,
      null => l10n.legacyCompletedTitle,
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && canLeave && widget.onDeferred != null) {
          unawaited(_defer());
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      complete ? Icons.check_circle_outline : Icons.restore,
                      size: 48,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      complete
                          ? completionTitle
                          : choice
                          ? l10n.legacyFoundTitle
                          : record?.requiresRecovery == true
                          ? l10n.legacyRecoveryTitle
                          : l10n.legacyTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (!choice) ...[
                      const SizedBox(height: 16),
                      Text(
                        complete
                            ? (record?.completedOutcome ==
                                      LegacyOutcome.notFound
                                  ? l10n.legacyNotFoundBody
                                  : l10n.legacyCompletedBody)
                            : record == null
                            ? l10n.legacySelectBody
                            : l10n.legacyResumeBody,
                      ),
                    ],
                    if (record != null && !complete) ...[
                      const SizedBox(height: 12),
                      Text(
                        l10n.legacyInventory(
                          record.fileCount,
                          (record.bytes / (1024 * 1024)).toStringAsFixed(1),
                        ),
                      ),
                      const Text('Documents/CharmShelf'),
                    ],
                    if (_failed) ...[
                      const SizedBox(height: 16),
                      Text(
                        _operationBusy
                            ? l10n.legacyOperationBusy
                            : _recordUnreadable
                            ? l10n.legacyRecordFailure
                            : switch (_issue) {
                                LegacyIssue.wrongFolder =>
                                  l10n.legacyWrongFolder,
                                LegacyIssue.unknownFiles =>
                                  l10n.legacyUnknownFiles,
                                LegacyIssue.sourceChanged =>
                                  l10n.legacySourceChanged,
                                LegacyIssue.unsupportedFiles =>
                                  l10n.legacyUnsupportedFiles,
                                LegacyIssue.invalidMetadata =>
                                  l10n.legacyInvalidMetadata,
                                LegacyIssue.linkedFolder =>
                                  l10n.legacyLinkedFolder,
                                null => l10n.legacyFailure,
                              },
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    if (_issue == LegacyIssue.linkedFolder && !_busy)
                      OutlinedButton(
                        onPressed: () => _run(_resolveReferences),
                        child: Text(l10n.legacyUnlinkTitle),
                      ),
                    const SizedBox(height: 24),
                    if (_busy) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(switch (_progressPhase) {
                        LegacyPhase.restoring => l10n.legacyCopying,
                        LegacyPhase.importing => l10n.legacyVerifying,
                        LegacyPhase.deleting => l10n.legacyDeleting,
                        _ => l10n.legacyWorking,
                      }),
                      if (_total > 0) Text('$_done / $_total'),
                    ] else if (complete) ...[
                      FilledButton(
                        onPressed: _finish,
                        child: Text(
                          widget.fromSettings
                              ? l10n.legacyBackToSettings
                              : l10n.legacyContinue,
                        ),
                      ),
                      TextButton(
                        onPressed: _inspect,
                        child: Text(l10n.legacyInspectAgain),
                      ),
                    ] else if (_recordUnreadable) ...[
                      FilledButton(
                        onPressed: () => _run(() async {
                          _record = await (await ref.read(
                            legacyMigrationServiceProvider.future,
                          )).load();
                          _recordUnreadable = false;
                        }),
                        child: Text(l10n.commonRetry),
                      ),
                    ] else if (record == null) ...[
                      _ChoiceCard(
                        icon: Icons.folder_open,
                        title: l10n.legacyFolderTitle,
                        description: l10n.legacyFolderBody,
                        action: FilledButton(
                          onPressed: _inspect,
                          child: Text(l10n.legacySelectDocuments),
                        ),
                      ),
                    ] else if (choice) ...[
                      _ChoiceCard(
                        icon: Icons.restore,
                        title: l10n.legacyRestore,
                        description: l10n.legacyChoiceBody,
                        recommendation: l10n.legacyRecommended,
                        action: FilledButton(
                          onPressed: () => _execute(true),
                          child: Text(l10n.legacyRestore),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(l10n.legacyRestoreCleanup),
                      const SizedBox(height: 16),
                      if (widget.onDeferred != null)
                        TextButton(
                          onPressed: canLeave ? _defer : null,
                          child: Text(l10n.legacyDecideLater),
                        ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _confirmDiscard,
                        icon: const Icon(Icons.delete_outline),
                        label: Text(l10n.legacyDecline),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.legacyDiscardHint,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      TextButton(
                        onPressed: _inspect,
                        child: Text(l10n.legacyInspectAgain),
                      ),
                    ] else ...[
                      FilledButton(
                        onPressed: () => _execute(
                          record.restored ||
                              record.phase == LegacyPhase.restoring ||
                              record.phase == LegacyPhase.importing,
                        ),
                        child: Text(l10n.commonRetry),
                      ),
                      TextButton(
                        onPressed: _inspect,
                        child: Text(l10n.legacyReconnect),
                      ),
                    ],
                    if (record == null &&
                        canLeave &&
                        widget.onDeferred != null) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _defer,
                        child: Text(l10n.legacyLater),
                      ),
                      Text(l10n.legacyLaterHint, textAlign: TextAlign.center),
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

/// Wrapping headings keep both the action and recommendation readable at large text sizes.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.action,
    this.recommendation,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget action;
  final String? recommendation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: recommendation != null
            ? colors.primaryContainer
            : colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: recommendation != null
              ? colors.primary
              : colors.outlineVariant,
        ),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          color: recommendation != null
              ? colors.onPrimaryContainer
              : colors.onSurface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(icon, color: colors.primary),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: recommendation != null
                        ? colors.onPrimaryContainer
                        : colors.onSurface,
                  ),
                ),
                if (recommendation != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      recommendation!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(description),
            const SizedBox(height: 16),
            action,
          ],
        ),
      ),
    );
  }
}
