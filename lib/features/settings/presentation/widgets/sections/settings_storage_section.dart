import 'package:private_shelf/features/library/presentation/providers/reference_migration_provider.dart';
import 'package:private_shelf/features/library/presentation/screens/reference_migration_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/feedback/snackbar_service.dart';
import 'package:private_shelf/core/services/local_storage_manager.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/external_library_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/folder_sync_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/import_flow_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/sync_progress_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/trash_provider.dart';
import 'package:private_shelf/features/home/presentation/providers/favorite_collections_provider.dart';
import 'package:private_shelf/features/home/presentation/providers/recently_viewed_collections_provider.dart';
import 'package:private_shelf/features/security/presentation/utils/security_action_guard.dart';
import 'package:private_shelf/features/settings/presentation/widgets/storage_clear_progress_dialog.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/settings/settings_section.dart';
import 'package:private_shelf/shared/widgets/settings/settings_tile.dart';
import 'package:private_shelf/shared/widgets/dialogs/dialog_actions.dart';

class SettingsStorageSection extends ConsumerStatefulWidget {
  const SettingsStorageSection({
    super.key,
    required this.isSyncing,
    required this.onSync,
  });

  final bool isSyncing;
  final VoidCallback onSync;

  @override
  ConsumerState<SettingsStorageSection> createState() =>
      _SettingsStorageSectionState();
}

class _FeaturePoint extends StatelessWidget {
  const _FeaturePoint({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StorageClearOverviewDialog extends StatefulWidget {
  const _StorageClearOverviewDialog({
    required this.title,
    required this.filesPage,
    required this.databasePage,
    required this.cancelLabel,
    required this.nextLabel,
    required this.executeLabel,
  });

  final String title;
  final Widget filesPage;
  final Widget databasePage;
  final String cancelLabel;
  final String nextLabel;
  final String executeLabel;

  @override
  State<_StorageClearOverviewDialog> createState() =>
      _StorageClearOverviewDialogState();
}

class _StorageClearOverviewDialogState
    extends State<_StorageClearOverviewDialog> {
  late final PageController _pageController;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_page == 1) {
      Navigator.pop(context, true);
      return;
    }
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _back() => _pageController.previousPage(
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: PageView(
          controller: _pageController,
          onPageChanged: (page) => setState(() => _page = page),
          children: [widget.filesPage, widget.databasePage],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${_page + 1}/2',
                style: theme.textTheme.labelMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              DialogActionRow(
                leading: _page == 0
                    ? DialogCloseButton(
                        onPressed: () => Navigator.pop(context, false),
                        semanticLabel: widget.cancelLabel,
                      )
                    : TextButton(
                        onPressed: _back,
                        child: Text(l10n.commonBack),
                      ),
                trailing: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  ),
                  child: Text(
                    _page == 1 ? widget.executeLabel : widget.nextLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsStorageSectionState
    extends ConsumerState<SettingsStorageSection> {
  bool _isClearing = false;

  bool get _isStorageOperationBusy =>
      widget.isSyncing || _isImportFlowRunning || _isClearing;

  bool get _isImportFlowRunning {
    final status = ref.read(importFlowNotifierProvider).status;
    return status == ImportFlowStatus.scanning ||
        status == ImportFlowStatus.importing;
  }

  Future<void> _handleClearStorage() async {
    if (_isStorageOperationBusy) return;

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final snackBar = ref.read(snackBarServiceProvider);

    final authOk = await SecurityActionGuard.requireAuth(
      context,
      ref,
      title: l10n.settingsStorageClear,
    );
    if (!authOk || !mounted) return;

    // 1回目の確認ダイアログ（概要を2ページに分割）
    final firstConfirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _StorageClearOverviewDialog(
        title: l10n.settingsStorageClearDialogTitle1,
        cancelLabel: l10n.commonCancel,
        nextLabel: l10n.commonNext,
        executeLabel: l10n.settingsStorageClearExecute,
        filesPage: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.settingsStorageClearDialogIntro1),
              const SizedBox(height: 16),
              _FeaturePoint(
                icon: Icons.delete_forever_outlined,
                title: l10n.settingsStorageClearFeatureFilesTitle,
                description: l10n.settingsStorageClearFeatureFilesBody,
              ),
            ],
          ),
        ),
        databasePage: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FeaturePoint(
                icon: Icons.storage_outlined,
                title: l10n.settingsStorageClearFeatureDbTitle,
                description: l10n.settingsStorageClearFeatureDbBody,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.settingsStorageClearNoteWarning,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (firstConfirmed != true || !mounted) return;

    final finalConfirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.delete_forever, color: theme.colorScheme.error),
        title: Text(l10n.settingsStorageClearFinalTitle),
        content: Text(l10n.settingsStorageClearFinalMessage),
        actions: [
          DialogActionRow(
            leading: DialogCloseButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              semanticLabel: l10n.commonCancel,
            ),
            trailing: FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              child: Text(l10n.settingsStorageClearFinalExecute),
            ),
          ),
        ],
      ),
    );

    if (finalConfirmed != true || !mounted || _isStorageOperationBusy) return;

    setState(() => _isClearing = true);

    try {
      final result = await StorageClearProgressDialog.show(context);
      if (!mounted) return;

      if (result == StorageClearDialogResult.success) {
        _refreshAfterStorageReset();
        snackBar.success(
          context: context,
          message: l10n.settingsStorageClearSuccess,
        );
      } else if (result == StorageClearDialogResult.cancelled) {
        snackBar.info(
          context: context,
          message: l10n.settingsStorageClearCancelled,
        );
      } else if (result == StorageClearDialogResult.failed) {
        snackBar.error(
          context: context,
          message: l10n.settingsStorageClearFailed,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClearing = false);
      }
    }
  }

  void _refreshAfterStorageReset() {
    ref.read(importFlowNotifierProvider.notifier).reset();
    ref.read(syncProgressNotifierProvider.notifier).reset();
    ref.invalidate(folderSyncNotifierProvider);
    ref.invalidate(mediaRepositoryProvider);
    ref.invalidate(libraryViewModelProvider);
    ref.invalidate(externalFolderListProvider);
    ref.invalidate(externalRootItemsProvider);
    ref.invalidate(trashedMediaRootsProvider);
    ref.invalidate(tagListViewModelProvider);
    ref.invalidate(favoriteCollectionsProvider);
    ref.invalidate(recentlyViewedCollectionsProvider);
  }

  Future<void> _showStoragePathDialog(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) async {
    final showsTechnicalPath = theme.platform != TargetPlatform.iOS;
    final path = showsTechnicalPath
        ? (await ref
                  .read(localStorageManagerProvider)
                  .getPrivateRootDirectory())
              .path
        : null;

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        actionsAlignment: MainAxisAlignment.spaceBetween,
        title: Text(l10n.settingsStoragePath),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              theme.platform == TargetPlatform.iOS
                  ? l10n.settingsStoragePathDialogMessageIos
                  : l10n.settingsStoragePathDialogMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (path != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                child: SelectableText(
                  path,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (path == null)
            DialogCloseButton(
              onPressed: () => Navigator.pop(dialogContext),
              semanticLabel: l10n.commonClose,
            )
          else
            DialogActionRow(
              leading: DialogCloseButton(
                onPressed: () => Navigator.pop(dialogContext),
                semanticLabel: l10n.commonClose,
              ),
              trailing: FilledButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: Text(l10n.settingsStoragePathCopy),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: path));
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  if (!context.mounted) return;
                  ref
                      .read(snackBarServiceProvider)
                      .success(
                        context: context,
                        message: l10n.settingsStoragePathCopied,
                      );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showStorageInfoDialog({
    required String title,
    required String message,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        actionsAlignment: MainAxisAlignment.spaceBetween,
        title: Text(title),
        content: Text(message),
        actions: [
          DialogCloseButton(
            onPressed: () => Navigator.pop(dialogContext),
            semanticLabel: l10n.commonClose,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    ref.watch(importFlowNotifierProvider.select((state) => state.status));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(
          title: l10n.settingsStorageSection,
          icon: Icons.folder_outlined,
          children: [
            if (ref
                        .watch(referenceMigrationNeedsAttentionProvider)
                        .value ==
                    true ||
                ref.watch(referenceMigrationNeedsAttentionProvider).hasError)
              SettingsTile(
                icon: Icons.file_download_outlined,
                title: l10n.referenceMigrationTitle,
                subtitle: l10n.referenceMigrationDescription,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ReferenceMigrationScreen(),
                  ),
                ),
              ),
            SettingsTile(
              icon: Icons.folder_outlined,
              title: l10n.settingsStoragePath,
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => _showStoragePathDialog(context, l10n, theme),
            ),
            SettingsTile(
              icon: widget.isSyncing ? Icons.sync : Icons.sync_outlined,
              title: l10n.settingsStorageSync,
              subtitle: l10n.settingsStorageSyncSubtitle,
              trailing: widget.isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton.filledTonal(
                      key: const ValueKey('storage-optimize-button'),
                      tooltip: l10n.settingsStorageSync,
                      icon: const Icon(Icons.auto_fix_high_rounded),
                      onPressed: widget.onSync,
                    ),
              onInfoTap: () => _showStorageInfoDialog(
                title: l10n.settingsStorageSync,
                message: l10n.settingsStorageSyncInfoMessage,
              ),
            ),
            SettingsTile(
              icon: Icons.delete_forever_outlined,
              iconColor: theme.colorScheme.error,
              iconBackgroundColor: theme.colorScheme.errorContainer.withValues(
                alpha: 0.5,
              ),
              title: l10n.settingsStorageClear,
              trailing: _isClearing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right, size: 18),
              onTap: _isStorageOperationBusy ? null : _handleClearStorage,
            ),
          ],
        ),
      ],
    );
  }
}
