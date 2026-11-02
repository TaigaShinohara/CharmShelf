import '../../domain/models/import_preview_source.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/core/error/user_safe_error_message.dart';
import 'package:private_shelf/core/providers/tab_navigation_provider.dart';
import 'package:private_shelf/core/services/app_lifecycle_service.dart';
import 'package:private_shelf/core/theme/app_theme.dart';
import 'package:private_shelf/core/utils/file_size_utils.dart';
import 'package:private_shelf/features/library/domain/models/file_tree.dart';
import 'package:private_shelf/features/library/domain/models/media_format_utils.dart';
import 'package:private_shelf/features/library/domain/models/import_execution_report.dart';
import 'package:private_shelf/features/library/domain/models/import_catalog_mode.dart';
import 'package:private_shelf/features/library/domain/models/sync_progress.dart';
import 'package:private_shelf/features/library/presentation/providers/file_tree_thumbnail_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/import_flow_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/sync_progress_provider.dart';
import 'package:private_shelf/features/library/presentation/screens/media_viewer_screen.dart';
import 'package:private_shelf/features/library/presentation/screens/import_results_screen.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/sheets/app_bottom_sheet.dart';
import 'package:private_shelf/shared/widgets/widgets.dart';

enum _ImportMediaTypeFilter { all, images, videos, audio, docs }

String _localizedImportFailureReason(AppLocalizations l10n, String reason) {
  return switch (reason) {
    ImportFailureReasonCode.cancelled => l10n.importFailureCancelled,
    ImportFailureReasonCode.noSpace => l10n.importFailureNoSpace,
    ImportFailureReasonCode.permission => l10n.importFailurePermission,
    ImportFailureReasonCode.duplicate => l10n.importFailureDuplicate,
    ImportFailureReasonCode.unsupported => l10n.importFailureUnsupported,
    ImportFailureReasonCode.corrupt => l10n.importFailureCorrupt,
    ImportFailureReasonCode.invalid => l10n.importFailureInvalid,
    ImportFailureReasonCode.file => l10n.importFailureFile,
    ImportFailureReasonCode.database => l10n.importFailureDatabase,
    ImportFailureReasonCode.network => l10n.importFailureNetwork,
    ImportFailureReasonCode.authentication => l10n.importFailureAuthentication,
    ImportFailureReasonCode.system => l10n.importFailureSystem,
    ImportFailureReasonCode.ui => l10n.importFailureUi,
    ImportFailureReasonCode.temporaryCopy => l10n.importFailureTemporaryCopy,
    ImportFailureReasonCode.processing => l10n.importFailureProcessing,
    _ => reason,
  };
}

class ImportSelectionScreen extends ConsumerStatefulWidget {
  const ImportSelectionScreen({super.key});

  @override
  ConsumerState<ImportSelectionScreen> createState() =>
      _ImportSelectionScreenState();
}

class _ImportSelectionScreenState extends ConsumerState<ImportSelectionScreen> {
  static const _longRunningWarningDelay = Duration(seconds: 2);

  bool _showAdvancedSettings = false;
  bool _showGrouping = false;
  bool _openingResult = false;
  bool _openingSingleFile = false;
  bool _singleFileAutoOpenAttempted = false;
  bool _showLongRunningWarning = false;
  _ImportMediaTypeFilter _activeFilter = _ImportMediaTypeFilter.all;
  Timer? _longRunningWarningTimer;
  ImportFlowStatus? _observedImportStatus;

  @override
  void initState() {
    super.initState();
    ref.listenManual<ImportFlowState>(importFlowNotifierProvider, (_, next) {
      _updateLongRunningWarning(next.status);
      _scheduleSingleFileOpen(next);
    }, fireImmediately: true);
    Future.microtask(() {
      ref.read(importFlowNotifierProvider.notifier).restoreDraftSession();
    });
  }

  @override
  void dispose() {
    _longRunningWarningTimer?.cancel();
    super.dispose();
  }

  void _updateLongRunningWarning(ImportFlowStatus status) {
    if (_observedImportStatus == status) return;
    _observedImportStatus = status;
    _longRunningWarningTimer?.cancel();
    _longRunningWarningTimer = null;
    _showLongRunningWarning = false;

    if (status != ImportFlowStatus.importing) return;
    _longRunningWarningTimer = Timer(_longRunningWarningDelay, () {
      if (!mounted ||
          ref.read(importFlowNotifierProvider).status !=
              ImportFlowStatus.importing) {
        return;
      }
      setState(() => _showLongRunningWarning = true);
    });
  }

  bool _isBusyStatus(ImportFlowStatus status) {
    return status == ImportFlowStatus.scanning ||
        status == ImportFlowStatus.importing;
  }

  void _scheduleSingleFileOpen(ImportFlowState state) {
    final report = state.importReport;
    if (_singleFileAutoOpenAttempted ||
        state.status != ImportFlowStatus.completed ||
        report == null ||
        report.committedFiles.length != 1 ||
        report.failedItems != 0 ||
        report.failedEntries.isNotEmpty ||
        report.pendingSourcePaths.isNotEmpty ||
        report.isCancelled ||
        report.isRolledBack ||
        report.retryBlocked ||
        _deriveSkippedItems(report) != 0 ||
        report.destinations.any((item) => item.isFolder && item.isCatalog)) {
      return;
    }
    _singleFileAutoOpenAttempted = true;
    _openingSingleFile = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // A normal import is pushed above the library. Keep a recoverable results
      // screen if a caller presents it without an underlying destination.
      if (!Navigator.of(context).canPop()) {
        setState(() => _openingSingleFile = false);
        return;
      }
      await openImportedFile(
        context,
        ref,
        report.committedFiles.single,
        onReadyToOpen: () {
          ref.read(currentTabIndexProvider.notifier).goToLibrary();
          _closeScreen();
        },
      );
      // Resolution/presentation failures leave the report and open action
      // available. A successful handoff has already removed this screen.
      if (mounted) setState(() => _openingSingleFile = false);
    });
  }

  int _countSelectedItems(FileTreeNode node) {
    if (!node.includeInImport) return 0;
    var count = node.includeInImport ? 1 : 0;
    for (final child in node.children) {
      count += _countSelectedItems(child);
    }
    return count;
  }

  int _countSelectedFiles(FileTreeNode node) {
    if (!node.includeInImport) return 0;
    var count = node.includeInImport && !node.isDirectory ? 1 : 0;
    for (final child in node.children) {
      count += _countSelectedFiles(child);
    }
    return count;
  }

  int _countCatalogableFiles(FileTreeNode node) {
    if (!node.includeInImport) return 0;
    var count = node.includeInImport && !node.isDirectory && node.isMedia
        ? 1
        : 0;
    for (final child in node.children) {
      count += _countCatalogableFiles(child);
    }
    return count;
  }

  int _estimateSelectedBytes(FileTreeNode node) {
    if (!node.includeInImport) return 0;
    var total = !node.isDirectory ? (node.size ?? 0) : 0;
    for (final child in node.children) {
      total += _estimateSelectedBytes(child);
    }
    return total;
  }

  int _deriveSkippedItems(ImportExecutionReport report) {
    final skipped =
        report.totalItems - report.processedItems - report.failedItems;
    return skipped < 0 ? 0 : skipped;
  }

  String _formatBytes(int bytes) {
    return FileSizeUtils.formatBytes(bytes);
  }

  void _cancelImport() {
    ref.read(syncProgressNotifierProvider.notifier).cancel();
  }

  Future<void> _handleCancelImport() async {
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

    if (confirmed == true && mounted) {
      _cancelImport();
    }
  }

  void _closeScreen() {
    ref.read(importFlowNotifierProvider.notifier).reset();
    Navigator.of(context).pop();
  }

  void _returnToLibrary() {
    ref.read(currentTabIndexProvider.notifier).goToLibrary();
    _closeScreen();
  }

  void _retryFailedItems() {
    ref.read(importFlowNotifierProvider.notifier).retryFailedItems();
  }

  Widget _buildScanningState(BuildContext context, String message) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
              child: Column(
                children: [
                  const SizedBox.square(
                    dimension: 36,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBusyState({
    required BuildContext context,
    required ImportFlowStatus status,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final syncProgress = ref.watch(syncProgressNotifierProvider);
    final isCancelling = syncProgress.status == SyncStatus.cancelling;
    final isImporting = status == ImportFlowStatus.importing && !isCancelling;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isImporting) ...[
                Icon(
                  isCancelling ? Icons.cancel_outlined : icon,
                  size: 56,
                  color: isCancelling
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
              ],
              if (isImporting) ...[
                LinearProgressIndicator(
                  value: syncProgress.progress > 0
                      ? syncProgress.progress
                      : null,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 12),
                if (syncProgress.totalItems > 0)
                  Text(
                    '${syncProgress.processedItems} / ${syncProgress.totalItems}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ] else ...[
                const CircularProgressIndicator(),
              ],
              const SizedBox(height: 16),
              Text(
                isCancelling ? l10n.importRollingBack : title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!isCancelling && !isImporting) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (!isCancelling &&
                  status == ImportFlowStatus.importing &&
                  _showLongRunningWarning) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l10n.importDoNotCloseWarning,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _matchesFilter(FileTreeNode node, _ImportMediaTypeFilter filter) {
    if (filter == _ImportMediaTypeFilter.all) return true;
    if (node.isDirectory) {
      return _hasMatchingDescendant(node, filter);
    }
    final ext = p.extension(node.name).toLowerCase();
    final mime = node.mimeType?.toLowerCase() ?? '';
    switch (filter) {
      case _ImportMediaTypeFilter.images:
        return const {
              '.jpg',
              '.jpeg',
              '.png',
              '.webp',
              '.gif',
              '.heic',
              '.bmp',
              '.heif',
            }.contains(ext) ||
            mime.startsWith('image/');
      case _ImportMediaTypeFilter.videos:
        return const {
              '.mp4',
              '.mov',
              '.mkv',
              '.avi',
              '.webm',
              '.flv',
              '.wmv',
              '.m4v',
            }.contains(ext) ||
            mime.startsWith('video/');
      case _ImportMediaTypeFilter.audio:
        return const {
              '.mp3',
              '.m4a',
              '.wav',
              '.flac',
              '.aac',
              '.ogg',
              '.opus',
              '.wma',
            }.contains(ext) ||
            mime.startsWith('audio/');
      case _ImportMediaTypeFilter.docs:
        return const {
              '.pdf',
              '.epub',
              '.txt',
              '.doc',
              '.docx',
              '.cbz',
              '.cbr',
            }.contains(ext) ||
            mime.startsWith('text/') ||
            mime == 'application/pdf';
      case _ImportMediaTypeFilter.all:
        return true;
    }
  }

  bool _hasMatchingDescendant(
    FileTreeNode node,
    _ImportMediaTypeFilter filter,
  ) {
    for (final child in node.children) {
      if (!child.isDirectory && _matchesFilter(child, filter)) {
        return true;
      }
      if (child.isDirectory && _hasMatchingDescendant(child, filter)) {
        return true;
      }
    }
    return false;
  }

  List<FileTreeNode> _collectSelectedLeafFiles(FileTreeNode node) {
    if (!node.includeInImport) return const [];
    final list = <FileTreeNode>[];
    if (!node.isDirectory) {
      if (node.includeInImport) list.add(node);
    } else {
      for (final child in node.children) {
        list.addAll(_collectSelectedLeafFiles(child));
      }
    }
    return list;
  }

  Widget _buildSelectionSummary(
    BuildContext context,
    FileTreeNode rootNode, {
    VoidCallback? onTap,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isVirtualRoot = rootNode.uri.scheme == 'private-shelf';
    final selectedFiles = _countSelectedFiles(rootNode);
    final selectedItems = isVirtualRoot
        ? selectedFiles
        : (_countSelectedItems(rootNode) - 1).clamp(0, 1 << 31);
    final estimatedBytes = _estimateSelectedBytes(rootNode);

    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              l10n.importSelectionEstimateTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (onTap != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.importAdvancedSettings,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!isVirtualRoot)
              _buildStatChip(
                context,
                Icons.list_alt_outlined,
                l10n.importSelectionEstimateItems(selectedItems),
              ),
            _buildStatChip(
              context,
              Icons.insert_drive_file_outlined,
              l10n.importSelectionEstimateFiles(selectedFiles),
            ),
            if (_collectSelectedLeafFiles(
              rootNode,
            ).every((file) => file.size != null && file.size! >= 0))
              _buildStatChip(
                context,
                Icons.storage_outlined,
                l10n.importSelectionEstimateSize(_formatBytes(estimatedBytes)),
              ),
          ],
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? Padding(padding: const EdgeInsets.all(16), child: summary)
            : InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(child: summary),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildResultSummaryCard(
    BuildContext context,
    ImportExecutionReport report,
  ) {
    // Unknown rollback state is not equivalent to zero saved files.
    if (report.retryBlocked) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final skippedItems = _deriveSkippedItems(report);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.importSummaryAdded(report.processedItems)),
            Text(l10n.importSummarySkipped(skippedItems)),
            Text(l10n.importSummaryFailed(report.failedItems)),
            if (report.isCancelled) ...[
              const SizedBox(height: 4),
              Text(
                l10n.importSummaryCancelled,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openAdvancedSettings() {
    setState(() {
      _showAdvancedSettings = true;
    });
  }

  void _closeAdvancedSettings() {
    setState(() {
      _showAdvancedSettings = false;
    });
  }

  Widget _buildSimpleConfirmationView(
    BuildContext context,
    FileTreeNode rootNode,
    AppLocalizations l10n,
    bool showLifecycleWarning,
    AppLifecycleStatus lifecycleStatus,
  ) {
    final theme = Theme.of(context);
    final isVirtualRoot = rootNode.uri.scheme == 'private-shelf';
    final isFolderImport = rootNode.isDirectory && !isVirtualRoot;
    final leafFiles = _collectSelectedLeafFiles(rootNode);
    final isSingleFile = !isFolderImport && leafFiles.length == 1;
    final hasKnownSize =
        leafFiles.isNotEmpty &&
        leafFiles.every((file) => file.size != null && file.size! >= 0);

    final String confirmMessage;
    final String? targetDisplayName;

    if (!isFolderImport) {
      if (leafFiles.length == 1) {
        final singleFile = leafFiles.first;
        targetDisplayName = singleFile.name;
        confirmMessage = l10n.importSimpleConfirmFileMessage;
      } else {
        targetDisplayName = null;
        confirmMessage = l10n.importSimpleConfirmFilesMessage;
      }
    } else {
      targetDisplayName = rootNode.name;
      confirmMessage = l10n.importSimpleConfirmFolderMessage;
    }

    final confirmationDetails = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          confirmMessage,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (targetDisplayName != null) ...[
          const SizedBox(height: 4),
          SelectableText(
            targetDisplayName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
        if (isSingleFile && hasKnownSize) ...[
          const SizedBox(height: 8),
          Text(_formatBytes(leafFiles.single.size!)),
        ],
      ],
    );

    return Column(
      children: [
        if (showLifecycleWarning)
          _buildLifecycleWarning(context, lifecycleStatus),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      margin: EdgeInsets.zero,
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (isFolderImport)
                              confirmationDetails
                            else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSimplePreviewHeader(
                                    context,
                                    rootNode,
                                    leafFiles,
                                    isFolderImport,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(child: confirmationDetails),
                                ],
                              ),
                            if (!isSingleFile) ...[
                              const SizedBox(height: 20),
                              Divider(
                                height: 1,
                                color: theme.colorScheme.outlineVariant,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Icon(
                                    Icons.insert_drive_file_outlined,
                                    size: 20,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      l10n.importSelectionEstimateFiles(
                                        _countSelectedFiles(rootNode),
                                      ),
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (!isSingleFile && hasKnownSize) ...[
                              const SizedBox(height: 8),
                              Text(
                                l10n.importSelectionEstimateSize(
                                  _formatBytes(
                                    _estimateSelectedBytes(rootNode),
                                  ),
                                ),
                              ),
                            ],
                            if (leafFiles.any((file) => file.size == null)) ...[
                              const SizedBox(height: 8),
                              Text(l10n.importSizeUnknown),
                            ],
                            if (leafFiles.length > 1) ...[
                              const SizedBox(height: 20),
                              _buildFilePreviewStrip(context, leafFiles),
                            ],
                            if (isFolderImport) ...[
                              const SizedBox(height: 16),
                              Text(
                                ref
                                            .watch(importFlowNotifierProvider)
                                            .catalogMode ==
                                        ImportCatalogMode.folder
                                    ? l10n.importGroupingFolder
                                    : l10n.importGroupingFiles,
                              ),
                              if (ref
                                      .watch(importFlowNotifierProvider)
                                      .importReport
                                      ?.hasCommittedFiles !=
                                  true)
                                TextButton.icon(
                                  onPressed: () => setState(
                                    () => _showGrouping = !_showGrouping,
                                  ),
                                  icon: Icon(
                                    _showGrouping
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                  ),
                                  label: Text(l10n.importGroupingChange),
                                ),
                              if (_showGrouping &&
                                  ref
                                          .watch(importFlowNotifierProvider)
                                          .importReport
                                          ?.hasCommittedFiles !=
                                      true)
                                _buildCatalogModeSelector(context, rootNode),
                            ],
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _openAdvancedSettings,
                                iconAlignment: IconAlignment.end,
                                icon: const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 20,
                                ),
                                label: Text(l10n.importAdvancedSettings),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AppFormattedText(
                              l10n.libraryImportStorageSafeBanner,
                              wrapWords: false,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCatalogModeSelector(
    BuildContext context,
    FileTreeNode rootNode,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final flow = ref.watch(importFlowNotifierProvider);
    final fileCount = _countSelectedFiles(rootNode);
    final catalogableFileCount = _countCatalogableFiles(rootNode);
    final mode = flow.catalogMode;

    void select(ImportCatalogMode next) {
      if (next != mode) {
        ref.read(importFlowNotifierProvider.notifier).setCatalogMode(next);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.importCatalogModeTitle,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(14),
          ),
          child: RadioGroup<ImportCatalogMode>(
            groupValue: mode,
            onChanged: (value) {
              if (value != null) select(value);
            },
            child: Column(
              children: [
                RadioListTile<ImportCatalogMode>(
                  value: ImportCatalogMode.folder,
                  title: Text(l10n.importGroupingFolder),
                  subtitle: Text(
                    '${l10n.importCatalogModeFolderDescription}\n${l10n.importCatalogModeFolderSummary(fileCount)}',
                  ),
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                const Divider(height: 1),
                RadioListTile<ImportCatalogMode>(
                  value: ImportCatalogMode.file,
                  title: Text(l10n.importGroupingFiles),
                  subtitle: Text(
                    '${l10n.importCatalogModeFileDescription}\n${l10n.importCatalogModeFileSummary(catalogableFileCount)}',
                  ),
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ],
            ),
          ),
        ),
        if (mode == ImportCatalogMode.file) ...[
          const SizedBox(height: 6),
          Text(
            l10n.importCatalogModeFileWarning,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSimplePreviewHeader(
    BuildContext context,
    FileTreeNode rootNode,
    List<FileTreeNode> leafFiles,
    bool isFolderImport,
  ) {
    final theme = Theme.of(context);

    if (!isFolderImport && leafFiles.length == 1) {
      final singleNode = leafFiles.first;
      final l10n = AppLocalizations.of(context)!;
      void openPreview() => _openMediaViewer(context, singleNode);

      return Semantics(
        key: ValueKey('import-preview-${singleNode.relativePath}'),
        container: true,
        button: true,
        label: singleNode.name,
        hint: l10n.importPreviewTooltip,
        onTap: openPreview,
        excludeSemantics: true,
        child: Tooltip(
          message: l10n.importPreviewTooltip,
          child: GestureDetector(
            excludeFromSemantics: true,
            onTap: openPreview,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _FileThumbnailImage(
                    node: singleNode,
                    size: 72,
                    fallbackIconSize: 32,
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.scrim.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.zoom_in,
                      size: 12,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final mainIcon = isFolderImport
        ? const CatalogizeIcon.outlined()
        : const Icon(Icons.file_copy_rounded);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: IconTheme.merge(
        data: IconThemeData(size: 36, color: theme.colorScheme.primary),
        child: mainIcon,
      ),
    );
  }

  Widget _buildFilePreviewStrip(
    BuildContext context,
    List<FileTreeNode> leafFiles,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final node in leafFiles.take(5))
          _buildSelectedFileRow(context, node),
        if (leafFiles.length > 5)
          TextButton.icon(
            key: const ValueKey('import-review-all-files'),
            onPressed: () => showAppBottomSheet<void>(
              context,
              title: l10n.importSelectionEstimateTitle,
              showCloseButton: true,
              useSingleChildScrollView: false,
              builder: (context, controller) => ListView.builder(
                key: const ValueKey('import-selected-files-list'),
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: leafFiles.length,
                itemBuilder: (context, index) =>
                    _buildSelectedFileRow(context, leafFiles[index]),
              ),
            ),
            icon: const Icon(Icons.list_alt),
            label: Text(l10n.importReviewAllFiles),
          ),
      ],
    );
  }

  Widget _buildSelectedFileRow(BuildContext context, FileTreeNode node) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final type = MediaFormatUtils.isAudio(node.name, mimeType: node.mimeType)
        ? l10n.importFilterAudio
        : MediaFormatUtils.isVideo(node.name, mimeType: node.mimeType)
        ? l10n.importFilterVideos
        : MediaFormatUtils.isImage(node.name, mimeType: node.mimeType)
        ? l10n.importFilterImages
        : MediaFormatUtils.isDocument(node.name, mimeType: node.mimeType) ||
              MediaFormatUtils.isText(node.name, mimeType: node.mimeType)
        ? l10n.importFilterDocs
        : l10n.libraryDisplayTypeFile;
    final size = node.size != null && node.size! >= 0
        ? _formatBytes(node.size!)
        : l10n.importSizeUnknown;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            key: ValueKey('import-preview-${node.relativePath}'),
            container: true,
            button: true,
            label: node.name,
            hint: l10n.importPreviewTooltip,
            onTap: () => _openMediaViewer(context, node),
            excludeSemantics: true,
            child: Tooltip(
              message: l10n.importPreviewTooltip,
              child: InkWell(
                excludeFromSemantics: true,
                onTap: () => _openMediaViewer(context, node),
                borderRadius: BorderRadius.circular(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox.square(
                    dimension: 48,
                    child: _FileThumbnailImage(
                      node: node,
                      size: 48,
                      fallbackIconSize: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(node.name, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  '$type · $size',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openMediaViewer(BuildContext context, FileTreeNode node) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaViewerScreen.preview(
          source: ImportPreviewSource(
            uri: node.uri,
            name: _resolvePreviewOriginalPath(node),
            size: node.size,
            mimeType: node.mimeType,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(importFlowNotifierProvider);
    final lifecycleStatus = ref.watch(appLifecycleProvider);
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(importFlowNotifierProvider.notifier);

    final (
      String appBarTitle,
      Widget? leading,
      bool automaticallyImplyLeading,
    ) = switch (state.status) {
      ImportFlowStatus.confirming =>
        _showAdvancedSettings
            ? (
                l10n.importScanResult,
                BackButton(onPressed: _closeAdvancedSettings),
                false,
              )
            : (l10n.importSimpleConfirmTitle, null, true),
      ImportFlowStatus.importing => (l10n.importImporting, null, false),
      ImportFlowStatus.completed => (l10n.importCompleted, null, false),
      ImportFlowStatus.error => (l10n.commonErrorOccurred, null, false),
      ImportFlowStatus.scanning ||
      ImportFlowStatus.idle => (l10n.importScanning, null, true),
    };

    final canPop = switch (state.status) {
      ImportFlowStatus.confirming => !_showAdvancedSettings,
      ImportFlowStatus.importing => false,
      ImportFlowStatus.completed => false,
      ImportFlowStatus.error => false,
      ImportFlowStatus.scanning => false,
      ImportFlowStatus.idle => true,
    };

    final syncProgress = ref.watch(syncProgressNotifierProvider);
    final isCancelling = syncProgress.status == SyncStatus.cancelling;

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          if (state.status == ImportFlowStatus.confirming) {
            unawaited(notifier.reset());
          }
          return;
        }
        if (_showAdvancedSettings &&
            state.status == ImportFlowStatus.confirming) {
          _closeAdvancedSettings();
        } else if (state.status == ImportFlowStatus.completed ||
            state.status == ImportFlowStatus.error) {
          _closeScreen();
        }
      },
      child: Scaffold(
        appBar: PremiumAppBar(
          titleText: appBarTitle,
          leading: leading,
          automaticallyImplyLeading: automaticallyImplyLeading,
        ),
        body: _buildBody(context, state, l10n, lifecycleStatus),
        bottomNavigationBar:
            state.status == ImportFlowStatus.confirming ||
                _isBusyStatus(state.status)
            ? SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: state.status == ImportFlowStatus.confirming
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!state.hasImportSelection) ...[
                              Text(
                                l10n.importNoNodesSelected,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            FilledButton.icon(
                              onPressed: state.hasImportSelection
                                  ? notifier.executeImport
                                  : null,
                              icon: const Icon(Icons.playlist_add),
                              label: Text(
                                _showAdvancedSettings
                                    ? l10n.importStart
                                    : l10n.importSimpleConfirmAction,
                              ),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(double.infinity, 56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ],
                        )
                      : OutlinedButton.icon(
                          onPressed: isCancelling ? null : _handleCancelImport,
                          icon: const Icon(Icons.cancel_outlined),
                          label: Text(
                            isCancelling
                                ? l10n.commonCancelling
                                : l10n.commonCancel,
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ImportFlowState state,
    AppLocalizations l10n,
    AppLifecycleStatus lifecycleStatus,
  ) {
    switch (state.status) {
      case ImportFlowStatus.scanning:
        return _buildScanningState(
          context,
          _busySubtitle(
            context: context,
            status: ImportFlowStatus.scanning,
            lifecycleStatus: lifecycleStatus,
          ),
        );
      case ImportFlowStatus.importing:
        return _buildBusyState(
          context: context,
          status: ImportFlowStatus.importing,
          icon: Icons.sync,
          title: l10n.importImporting,
          subtitle: _busySubtitle(
            context: context,
            status: ImportFlowStatus.importing,
            lifecycleStatus: lifecycleStatus,
          ),
        );
      case ImportFlowStatus.confirming:
        if (state.rootNode == null) return const SizedBox.shrink();
        if (state.rootNode!.children.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 48,
                  color: Theme.of(context).appColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(l10n.importNoMediaFound),
              ],
            ),
          );
        }
        final showLifecycleWarning = _shouldShowLifecycleWarning(
          lifecycleStatus: lifecycleStatus,
          importStatus: state.status,
        );

        if (!_showAdvancedSettings) {
          return _buildSimpleConfirmationView(
            context,
            state.rootNode!,
            l10n,
            showLifecycleWarning,
            lifecycleStatus,
          );
        }

        return Column(
          children: [
            if (showLifecycleWarning)
              _buildLifecycleWarning(context, lifecycleStatus),
            Expanded(
              child: ListView(
                children: [
                  _buildGuidanceCard(context, l10n),
                  _buildSelectionSummary(context, state.rootNode!),
                  _buildQuickActionBar(context, ref, l10n),
                  _buildFilterChips(context, l10n),
                  const Divider(height: 1),
                  ..._buildTreeNodes(
                    context,
                    ref,
                    state.rootNode!,
                    0,
                    l10n,
                    isEnabled: true,
                  ),
                ],
              ),
            ),
          ],
        );
      case ImportFlowStatus.completed:
        if (_openingSingleFile) {
          return const Center(child: CircularProgressIndicator());
        }
        final report = state.importReport;
        final hasPartialFailure = report?.hasPartialFailure ?? false;
        final isIncomplete =
            hasPartialFailure || (report?.isCancelled ?? false);
        final failureEntries = report?.failedEntries ?? const [];
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color:
                              (isIncomplete
                                      ? Theme.of(context).appColors.warning
                                      : Theme.of(context).appColors.success)
                                  .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isIncomplete
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_rounded,
                          size: 72,
                          color: isIncomplete
                              ? Theme.of(context).appColors.warning
                              : Theme.of(context).appColors.success,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (report != null) ...[
                    const SizedBox(height: 16),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 15 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: _buildResultSummaryCard(context, report),
                    ),
                    if (failureEntries.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.importFailedItemsTitle,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              for (final entry in failureEntries)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    '${entry.displayName.isNotEmpty ? entry.displayName : entry.path} - ${_localizedImportFailureReason(l10n, entry.reason)}',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                  if (report != null) ..._resultActions(report),
                  OutlinedButton(
                    onPressed: _returnToLibrary,
                    child: Text(l10n.importReturnToLibrary),
                  ),
                ],
              ),
            ),
          ),
        );
      case ImportFlowStatus.error:
        final report = state.importReport;
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    userSafeErrorMessage(state.error, l10n),
                    textAlign: TextAlign.center,
                  ),
                  if (report != null) ...[
                    const SizedBox(height: 16),
                    _buildResultSummaryCard(context, report),
                    if (report.failedEntries.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.importFailedItemsTitle,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              for (final entry in report.failedEntries)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    '${entry.displayName.isNotEmpty ? entry.displayName : entry.path} - ${_localizedImportFailureReason(l10n, entry.reason)}',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                  if (report != null) ..._resultActions(report),
                  OutlinedButton(
                    onPressed: _returnToLibrary,
                    child: Text(l10n.importReturnToLibrary),
                  ),
                ],
              ),
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  List<Widget> _resultActions(ImportExecutionReport report) {
    final l10n = AppLocalizations.of(context)!;
    final files = report.committedFiles;
    final canRetry =
        !report.retryBlocked &&
        report.sessionId != null &&
        report.pendingSourcePaths.isNotEmpty;
    final catalogs = report.destinations
        .where(
          (item) => item.sourcePath.isEmpty && item.isFolder && item.isCatalog,
        )
        .toList(growable: false);
    final catalog =
        catalogs.length == 1 &&
            files.every((file) => p.isWithin(catalogs.single.path, file.path))
        ? catalogs.single
        : null;
    return [
      if (files.isNotEmpty || catalog != null) ...[
        FilledButton.icon(
          onPressed: _openingResult
              ? null
              : () async {
                  setState(() => _openingResult = true);
                  if (catalog != null) {
                    await openImportedCatalog(
                      context,
                      ref,
                      catalog,
                      onEmpty: _closeScreen,
                    );
                  } else if (files.length == 1) {
                    await openImportedFile(context, ref, files.single);
                  } else {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => ImportResultsScreen(
                          items: List.unmodifiable(files),
                        ),
                      ),
                    );
                  }
                  if (mounted) {
                    setState(() => _openingResult = false);
                  }
                },
          icon: const Icon(Icons.open_in_new),
          label: Text(
            catalog != null
                ? l10n.importOpenCatalog
                : files.length == 1
                ? l10n.importOpenFile
                : l10n.importOpenResults,
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (canRetry) ...[
        OutlinedButton.icon(
          onPressed: _retryFailedItems,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.importPendingRetry),
        ),
        const SizedBox(height: 12),
      ],
      if (report.retryBlocked ||
          (report.sessionId == null && report.hasPartialFailure)) ...[
        Text(l10n.importRetryUnavailable),
        const SizedBox(height: 12),
      ],
    ];
  }

  Widget _buildQuickActionBar(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final notifier = ref.read(importFlowNotifierProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // 全選択 / 全解除
          TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            onPressed: () => notifier.setAllImportSelection(true),
            icon: const Icon(Icons.check_box_outlined, size: 16),
            label: Text(
              l10n.importSelectAll,
              style: theme.textTheme.labelSmall,
            ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            onPressed: () => notifier.setAllImportSelection(false),
            icon: const Icon(Icons.check_box_outline_blank, size: 16),
            label: Text(
              l10n.importDeselectAll,
              style: theme.textTheme.labelSmall,
            ),
          ),
          // 全展開 / 全折りたたみ
          IconButton(
            tooltip: l10n.importExpandAll,
            icon: const Icon(Icons.unfold_more, size: 18),
            onPressed: () => notifier.setAllExpanded(true),
          ),
          IconButton(
            tooltip: l10n.importCollapseAll,
            icon: const Icon(Icons.unfold_less, size: 18),
            onPressed: () => notifier.setAllExpanded(false),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final filters = [
      (_ImportMediaTypeFilter.all, l10n.importFilterAll, Icons.apps),
      (
        _ImportMediaTypeFilter.images,
        l10n.importFilterImages,
        Icons.image_rounded,
      ),
      (
        _ImportMediaTypeFilter.videos,
        l10n.importFilterVideos,
        Icons.movie_rounded,
      ),
      (
        _ImportMediaTypeFilter.audio,
        l10n.importFilterAudio,
        Icons.audiotrack_rounded,
      ),
      (
        _ImportMediaTypeFilter.docs,
        l10n.importFilterDocs,
        Icons.description_rounded,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: filters.map((item) {
          final filter = item.$1;
          final label = item.$2;
          final icon = item.$3;
          final isSelected = _activeFilter == filter;

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ConstrainedBox(
              key: ValueKey('import-filter-${filter.name}'),
              constraints: const BoxConstraints(minHeight: 48),
              child: ChoiceChip(
                avatar: Icon(
                  icon,
                  size: 14,
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
                label: Text(label),
                labelStyle: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _activeFilter = filter;
                    });
                  }
                },
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _shouldShowLifecycleWarning({
    required AppLifecycleStatus lifecycleStatus,
    required ImportFlowStatus importStatus,
  }) {
    return (importStatus == ImportFlowStatus.confirming ||
            importStatus == ImportFlowStatus.scanning ||
            importStatus == ImportFlowStatus.importing) &&
        lifecycleStatus != AppLifecycleStatus.foreground;
  }

  String _busySubtitle({
    required BuildContext context,
    required ImportFlowStatus status,
    required AppLifecycleStatus lifecycleStatus,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final base = switch (status) {
      ImportFlowStatus.scanning => l10n.importBusyScanningSubtitle,
      ImportFlowStatus.importing => l10n.importBusyImportingSubtitle,
      _ => '',
    };
    if (lifecycleStatus == AppLifecycleStatus.foreground) {
      return base;
    }
    return l10n.importBusyBackgroundSuffix(base);
  }

  Widget _buildLifecycleWarning(
    BuildContext context,
    AppLifecycleStatus lifecycleStatus,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final message = switch (lifecycleStatus) {
      AppLifecycleStatus.background => l10n.importLifecycleBackgroundWarning,
      AppLifecycleStatus.inactive => l10n.importLifecycleInactiveWarning,
      AppLifecycleStatus.detached => l10n.importLifecycleDetachedWarning,
      AppLifecycleStatus.foreground => '',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.35),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.pause_circle_outline,
                color: theme.colorScheme.tertiary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _resolvePreviewOriginalPath(FileTreeNode node) {
    final baseName = node.relativePath.isNotEmpty
        ? node.relativePath
        : node.name;
    if (p.extension(baseName).isNotEmpty) return baseName;

    final mime = node.mimeType?.toLowerCase();
    final ext = switch (mime) {
      'video/mp4' => '.mp4',
      'video/quicktime' => '.mov',
      'video/webm' => '.webm',
      'video/x-matroska' => '.mkv',
      'audio/mpeg' => '.mp3',
      'audio/mp4' => '.m4a',
      'audio/wav' => '.wav',
      'audio/aac' => '.aac',
      'application/pdf' => '.pdf',
      _ => '',
    };

    return ext.isEmpty ? baseName : '$baseName$ext';
  }

  Widget _buildGuidanceCard(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          iconColor: theme.colorScheme.primary,
          collapsedIconColor: theme.colorScheme.primary,
          title: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.importDescriptionTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.importDescriptionContent,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTreeNodes(
    BuildContext context,
    WidgetRef ref,
    FileTreeNode node,
    int depth,
    AppLocalizations l10n, {
    required bool isEnabled,
  }) {
    final widgets = <Widget>[];

    // フィルター判定
    if (!_matchesFilter(node, _activeFilter)) {
      return widgets;
    }

    widgets.add(
      _TreeNodeTile(
        node: node,
        depth: depth,
        isEnabled: isEnabled,
        onToggleExpanded: () => ref
            .read(importFlowNotifierProvider.notifier)
            .toggleExpanded(node.relativePath),
        onToggleCollection: () => ref
            .read(importFlowNotifierProvider.notifier)
            .toggleImportSelection(node.relativePath),
        onPreviewFile: () => _openMediaViewer(context, node),
      ),
    );

    if (node.isExpanded) {
      final nextLevelEnabled = isEnabled && node.includeInImport;

      for (final child in node.children) {
        widgets.addAll(
          _buildTreeNodes(
            context,
            ref,
            child,
            depth + 1,
            l10n,
            isEnabled: nextLevelEnabled,
          ),
        );
      }
    }

    return widgets;
  }
}

class _TreeNodeTile extends StatelessWidget {
  final FileTreeNode node;
  final int depth;
  final bool isEnabled;
  final VoidCallback onToggleExpanded;
  final VoidCallback onToggleCollection;
  final VoidCallback onPreviewFile;

  const _TreeNodeTile({
    required this.node,
    required this.depth,
    required this.isEnabled,
    required this.onToggleExpanded,
    required this.onToggleCollection,
    required this.onPreviewFile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: isEnabled
          ? (node.isDirectory ? onToggleExpanded : onPreviewFile)
          : null,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.45,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
          ),
          padding: EdgeInsets.only(
            left: 8.0 + (depth * 18.0),
            right: 12.0,
            top: 6,
            bottom: 6,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 展開アイコン（フォルダのみ）
              SizedBox(
                width: 48,
                height: 48,
                child: node.isDirectory
                    ? IconButton(
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        tooltip: node.isExpanded
                            ? l10n.commonCollapse
                            : l10n.commonExpand,
                        icon: Icon(
                          node.isExpanded
                              ? Icons.arrow_drop_down
                              : Icons.arrow_right,
                          size: 24,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: isEnabled ? onToggleExpanded : null,
                      )
                    : null,
              ),

              // ミニサムネイル / アイコン
              _buildLeadingThumbnail(context),

              const SizedBox(width: 10),

              // ファイル/フォルダ名・情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      node.name,
                      style: TextStyle(
                        fontWeight: node.isDirectory || node.isCatalog
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 13,
                        height: 1.3,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    _buildMetaRow(context, theme, l10n),
                  ],
                ),
              ),

              const SizedBox(width: 4),

              // チェックボックス
              SizedBox(
                width: 48,
                height: 48,
                child: Checkbox(
                  value: node.includeInImport,
                  onChanged: isEnabled ? (_) => onToggleCollection() : null,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingThumbnail(BuildContext context) {
    final theme = Theme.of(context);

    if (node.isDirectory) {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(
          node.isExpanded ? Icons.folder_open : Icons.folder,
          color: theme.colorScheme.primary,
          size: 22,
        ),
      );
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: _FileThumbnailImage(node: node, size: 38, fallbackIconSize: 20),
    );
  }

  Widget _buildMetaRow(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Row(
      children: [
        if (!node.isDirectory) ...[
          Text(
            node.size == null
                ? l10n.importSizeUnknown
                : FileSizeUtils.formatBytes(node.size!),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (node.isDirectory) ...[
          Text(
            l10n.libraryItemCount(node.children.length),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (node.isCatalog)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CatalogizeIcon(size: 10, color: theme.colorScheme.primary),
                const SizedBox(width: 3),
                Text(
                  l10n.importCollectionRegisteredLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FileThumbnailImage extends ConsumerWidget {
  final FileTreeNode node;
  final double size;
  final double fallbackIconSize;

  const _FileThumbnailImage({
    required this.node,
    required this.size,
    required this.fallbackIconSize,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = p.extension(node.name).toLowerCase();
    final isImageOrVideo =
        const {
          '.jpg',
          '.jpeg',
          '.png',
          '.webp',
          '.gif',
          '.heic',
          '.heif',
          '.bmp',
          '.mp4',
          '.mov',
          '.webm',
          '.mkv',
          '.avi',
        }.contains(ext) ||
        (node.mimeType?.startsWith('image/') ?? false) ||
        (node.mimeType?.startsWith('video/') ?? false);

    if (isImageOrVideo) {
      final asyncThumbnail = ref.watch(fileTreeNodeThumbnailProvider(node));
      return asyncThumbnail.when(
        data: (bytes) {
          if (bytes != null && bytes.isNotEmpty) {
            return Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) =>
                  _buildFallback(theme, ext),
            );
          }
          return _buildFallback(theme, ext);
        },
        loading: () => _buildFallback(theme, ext),
        error: (error, stackTrace) => _buildFallback(theme, ext),
      );
    }

    return _buildFallback(theme, ext);
  }

  Widget _buildFallback(ThemeData theme, String ext) {
    final (icon, iconColor, badgeText) = _inferFileTypeInfo(theme, ext);

    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(icon, size: fallbackIconSize, color: iconColor),
        if (badgeText.isNotEmpty)
          Positioned(
            right: 1.5,
            bottom: 1.5,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 2.5,
                vertical: 0.5,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.scrim.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(2.5),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontSize: 7.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  (IconData, Color, String) _inferFileTypeInfo(ThemeData theme, String ext) {
    final cleanExt = ext.startsWith('.')
        ? ext.substring(1).toUpperCase()
        : ext.toUpperCase();

    if (const {
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
      '.gif',
      '.heic',
      '.bmp',
      '.heif',
    }.contains(ext)) {
      return (Icons.image_rounded, theme.colorScheme.primary, cleanExt);
    }
    if (const {
      '.mp4',
      '.mov',
      '.mkv',
      '.avi',
      '.webm',
      '.flv',
      '.wmv',
      '.m4v',
    }.contains(ext)) {
      return (Icons.movie_rounded, theme.colorScheme.tertiary, cleanExt);
    }
    if (const {
      '.mp3',
      '.m4a',
      '.wav',
      '.flac',
      '.aac',
      '.ogg',
      '.opus',
    }.contains(ext)) {
      return (Icons.audiotrack_rounded, theme.colorScheme.secondary, cleanExt);
    }
    if (const {
      '.pdf',
      '.epub',
      '.txt',
      '.doc',
      '.docx',
      '.cbz',
      '.cbr',
    }.contains(ext)) {
      return (Icons.description_rounded, theme.colorScheme.primary, cleanExt);
    }
    return (
      Icons.insert_drive_file_outlined,
      theme.colorScheme.onSurfaceVariant,
      cleanExt,
    );
  }
}
