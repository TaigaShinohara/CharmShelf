import 'dart:async';

import 'package:flutter/material.dart';
import 'package:private_shelf/shared/widgets/feedback/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/features/library/data/services/tag_preset_service.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_preset_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_facet_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_view_model.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/core/error/user_safe_error_message.dart';
import 'package:private_shelf/core/theme/app_theme.dart';
import 'package:private_shelf/core/theme/app_tokens.dart';
import 'package:private_shelf/shared/widgets/widgets.dart';
import 'package:private_shelf/shared/widgets/sheets/app_bottom_sheet.dart';

Future<void> showTagImportSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showAppBottomSheet(
    context,
    title: l10n.settingsTagPresetImport,
    isScrollControlled: true,
    useSingleChildScrollView: false,
    builder: (context, scrollController) =>
        TagImportSheet(scrollController: scrollController),
  );
}

class TagImportSheet extends ConsumerStatefulWidget {
  final ScrollController? scrollController;
  const TagImportSheet({super.key, this.scrollController});

  @override
  ConsumerState<TagImportSheet> createState() => _TagImportSheetState();
}

class _TagImportSheetState extends ConsumerState<TagImportSheet> {
  static const Duration _previewDebounceDuration = Duration(milliseconds: 180);
  final _textController = TextEditingController();
  bool _isFileMode = true;
  List<TagPresetValidationIssue> _errors = [];
  bool _isValidating = false;
  bool _isValidated = false;
  bool _isImporting = false;
  TagPresetImportData? _previewData;
  int _textPanelIndex = 0;
  Timer? _previewDebounceTimer;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_updatePreview);
  }

  void _updatePreview() {
    _previewDebounceTimer?.cancel();
    final text = _textController.text;
    if (text.isEmpty) {
      setState(() => _previewData = null);
      return;
    }

    _previewDebounceTimer = Timer(_previewDebounceDuration, () {
      final latest = _textController.text;
      if (latest.isEmpty) {
        if (mounted) {
          setState(() => _previewData = null);
        }
        return;
      }
      ref.read(tagPresetServiceProvider.future).then((service) {
        if (!mounted || _textController.text != latest) return;
        try {
          final preview = service.parseSimplifiedText(latest);
          setState(() => _previewData = preview);
        } on Object {
          setState(() => _previewData = null);
        }
      });
    });
  }

  void _insertExample() {
    _textController.text = '''[Genre]
Fairy Tale
  Grimm
  Andersen
[Mood]
Happy
Exciting
''';
    setState(() {
      _isFileMode = false;
    });
  }

  @override
  void dispose() {
    _previewDebounceTimer?.cancel();
    _textController.removeListener(_updatePreview);
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleFileImport() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = AppSnackBarMessenger.of(context);
    if (_isImporting) return;
    try {
      final service = await ref.read(tagPresetServiceProvider.future);
      final jsonString = await service.pickPresetFileContent();
      if (jsonString == null) return;

      final keepPreview = await service.buildImportPreviewFromJsonString(
        jsonString,
      );
      final overwritePreview = await service.buildImportPreviewFromJsonString(
        jsonString,
        conflictPolicy: TagPresetConflictPolicy.overwrite,
      );
      if (!mounted) return;
      final conflictPolicy = await _showImportConfirmDialog(
        keepPreview: keepPreview,
        overwritePreview: overwritePreview,
      );
      if (conflictPolicy == null || !mounted) return;

      setState(() => _isImporting = true);
      final result = await service.importPresetsFromJsonString(
        jsonString,
        conflictPolicy: conflictPolicy,
      );
      ref.invalidate(tagListViewModelProvider);
      ref.invalidate(tagFacetListViewModelProvider);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: AppText(
            l10n.settingsTagPresetImportCompleted(
              result.createdCount,
              result.updatedCount,
              result.skippedCount,
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
      }
      messenger.showSnackBar(
        SnackBar(content: AppText(userSafeErrorMessage(e, l10n))),
      );
      return;
    }
    if (mounted) {
      setState(() => _isImporting = false);
    }
  }

  Future<void> _validateText() async {
    setState(() {
      _isValidating = true;
      _errors = [];
    });

    final service = await ref.read(tagPresetServiceProvider.future);
    final errors = service.validateSimplifiedText(_textController.text);

    if (!mounted) return;
    setState(() {
      _errors = errors;
      _isValidating = false;
      _isValidated = true;
    });
  }

  Future<void> _handleTextImport() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = AppSnackBarMessenger.of(context);
    if (_isImporting) return;

    if (_textController.text.trim().isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: AppText(l10n.settingsTagPresetImportNoData)),
      );
      return;
    }

    try {
      await _validateText();
      if (!mounted || _errors.isNotEmpty) return;

      final service = await ref.read(tagPresetServiceProvider.future);
      final keepPreview = await service.buildImportPreviewFromSimplifiedText(
        _textController.text,
      );
      final overwritePreview = await service
          .buildImportPreviewFromSimplifiedText(
            _textController.text,
            conflictPolicy: TagPresetConflictPolicy.overwrite,
          );
      if (!mounted) return;
      final conflictPolicy = await _showImportConfirmDialog(
        keepPreview: keepPreview,
        overwritePreview: overwritePreview,
      );
      if (conflictPolicy == null || !mounted) return;

      await _handleImportExecution(conflictPolicy);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isValidating = false;
          _isImporting = false;
        });
        messenger.showSnackBar(
          SnackBar(content: AppText(userSafeErrorMessage(e, l10n))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // AppBottomSheet側でタイトルとハンドルが表示されるため、ここではコンテンツのみを返す
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: true,
                label: Text(l10n.settingsTagPresetImportFromFile),
                icon: const Icon(Icons.file_present),
              ),
              ButtonSegment(
                value: false,
                label: Text(l10n.settingsTagPresetImportFromText),
                icon: const Icon(Icons.text_fields),
              ),
            ],
            selected: {_isFileMode},
            onSelectionChanged: (set) {
              if (_isImporting) return;
              setState(() {
                _isFileMode = set.first;
                _isValidated = false;
                _errors = [];
                _textPanelIndex = 0;
              });
            },
          ),
          const SizedBox(height: 16),
          if (_isFileMode)
            _buildFileMode(l10n, theme)
          else
            Expanded(child: _buildTextMode(l10n, theme)),
          const SizedBox(height: 16), // 下部の余白
        ],
      ),
    );
  }

  Widget _buildFileMode(AppLocalizations l10n, ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 32),
        Icon(
          LibraryActionIcons.importData,
          size: 64,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 16),
        AppText(
          l10n.settingsTagPresetImportSubtitle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _isImporting ? null : _handleFileImport,
          icon: _isImporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search),
          label: Text(
            _isImporting
                ? l10n.settingsTagPresetImporting
                : l10n.settingsTagPresetImportFromFile,
          ),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
          ),
        ),
      ],
    );
  }

  Widget _buildTextMode(AppLocalizations l10n, ThemeData theme) {
    final isCompact = MediaQuery.sizeOf(context).width < 900;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppText(
              l10n.settingsTagPresetImportType,
              style: theme.textTheme.labelMedium,
            ),
            Tooltip(
              message: l10n.settingsTagPresetImportExample,
              child: TextButton.icon(
                onPressed: _isImporting ? null : _insertExample,
                icon: const Icon(Icons.lightbulb_outline, size: 18),
                label: Text(l10n.settingsTagPresetImportExample),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (isCompact) ...[
          SegmentedButton<int>(
            segments: [
              ButtonSegment(
                value: 0,
                label: Text(l10n.settingsTagPresetImportFromText),
              ),
              ButtonSegment(
                value: 1,
                label: Text(l10n.settingsTagPresetImportPreview),
              ),
            ],
            selected: {_textPanelIndex},
            onSelectionChanged: (set) {
              if (_isImporting) return;
              setState(() => _textPanelIndex = set.first);
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _textPanelIndex == 0
                ? _buildInputEditor(l10n)
                : _buildPreview(l10n, theme),
          ),
        ] else
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 1, child: _buildInputEditor(l10n)),
                const SizedBox(width: 12),
                Expanded(flex: 1, child: _buildPreview(l10n, theme)),
              ],
            ),
          ),
        const SizedBox(height: 12),
        if (_errors.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _errors.length,
              itemBuilder: (context, index) {
                final error = _errors[index];
                return AppText(
                  l10n.settingsTagPresetImportFormatError(
                    error.line,
                    _validationMessage(l10n, error.code),
                  ),
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                );
              },
            ),
          ),
        if (_isValidated && _errors.isEmpty)
          Container(
            padding: AppSpacing.edgeInsetsSm,
            decoration: BoxDecoration(
              color: theme.appColors.successContainer,
              borderRadius: AppRadius.radiusSm,
              border: Border.all(color: theme.appColors.success),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: theme.appColors.success),
                AppSpacing.gapHorizontalSm,
                Expanded(
                  child: AppText(
                    l10n.settingsTagPresetImportValid,
                    style: TextStyle(color: theme.appColors.success),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: (_isValidating || _isImporting)
                    ? null
                    : _validateText,
                icon: _isValidating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fact_check),
                label: Text(l10n.settingsTagPresetImportCheck),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (_isValidated && _errors.isEmpty && !_isImporting)
                    ? _handleTextImport
                    : null,
                icon: _isImporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LibraryActionIcons.importData),
                label: Text(
                  _isImporting
                      ? l10n.settingsTagPresetImporting
                      : l10n.settingsTagPresetImportExecute,
                ),
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 56)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleImportExecution(
    TagPresetConflictPolicy conflictPolicy,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = AppSnackBarMessenger.of(context);
    try {
      setState(() => _isImporting = true);
      final service = await ref.read(tagPresetServiceProvider.future);
      final result = await service.importPresetsFromSimplifiedText(
        _textController.text,
        conflictPolicy: conflictPolicy,
      );
      ref.invalidate(tagListViewModelProvider);
      ref.invalidate(tagFacetListViewModelProvider);

      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: AppText(
            l10n.settingsTagPresetImportCompleted(
              result.createdCount,
              result.updatedCount,
              result.skippedCount,
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
      }
      messenger.showSnackBar(
        SnackBar(content: AppText(userSafeErrorMessage(e, l10n))),
      );
      return;
    }
    if (mounted) {
      setState(() => _isImporting = false);
    }
  }

  Future<TagPresetConflictPolicy?> _showImportConfirmDialog({
    required TagPresetImportPreview keepPreview,
    required TagPresetImportPreview overwritePreview,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    var overwriteExisting = false;
    return showDialog<TagPresetConflictPolicy>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final preview = overwriteExisting ? overwritePreview : keepPreview;
          return AlertDialog(
            title: Text(l10n.settingsTagPresetImportConfirmTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.settingsTagPresetImportConfirmMessage),
                  const SizedBox(height: 12),
                  _buildSummaryRow(
                    context,
                    l10n.settingsTagPresetImportConfirmFacets,
                    preview.createFacetCount,
                    preview.updateFacetCount,
                    preview.skipFacetCount,
                  ),
                  const SizedBox(height: 8),
                  _buildSummaryRow(
                    context,
                    l10n.settingsTagPresetImportConfirmTags,
                    preview.createTagCount,
                    preview.updateTagCount,
                    preview.skipTagCount,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: overwriteExisting,
                    title: Text(l10n.settingsTagPresetOverwriteExisting),
                    subtitle: Text(
                      l10n.settingsTagPresetOverwriteExistingSubtitle,
                    ),
                    onChanged: (value) {
                      setDialogState(() => overwriteExisting = value);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              DialogActionRow(
                leading: DialogCloseButton(
                  onPressed: () => Navigator.pop(context),
                  semanticLabel: l10n.commonCancel,
                ),
                trailing: TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    overwriteExisting
                        ? TagPresetConflictPolicy.overwrite
                        : TagPresetConflictPolicy.keepExisting,
                  ),
                  child: Text(l10n.commonConfirm),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    String title,
    int createCount,
    int updateCount,
    int skipCount,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          l10n.settingsTagPresetImportConfirmSummary(
            createCount,
            updateCount,
            skipCount,
          ),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildPreview(AppLocalizations l10n, ThemeData theme) {
    if (_previewData == null ||
        (_previewData!.facets.isEmpty && _previewData!.tags.isEmpty)) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Center(
          child: AppText(
            l10n.settingsTagPresetImportPreview,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final facets = _previewData!.facets;
    final tags = _previewData!.tags;
    final tagsByFacet = <String, List<TagPresetTagData>>{};
    for (final tag in tags) {
      final facetName = tag.facetName ?? l10n.libraryTagUncategorized;
      tagsByFacet.putIfAbsent(facetName, () => <TagPresetTagData>[]).add(tag);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppText(
            l10n.settingsTagPresetImportPreview,
            style: theme.textTheme.labelLarge,
          ),
          const Divider(),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              children: [
                ...facets.map((f) {
                  final facetName = f.name;
                  final facetTags =
                      tagsByFacet[facetName] ?? const <TagPresetTagData>[];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: AppText(
                            facetName,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                      ...facetTags.map((t) {
                        final tagName = t.name;
                        final hasParent = t.parentName != null;
                        return Padding(
                          padding: EdgeInsets.only(
                            left: hasParent ? 24.0 : 8.0,
                            top: 2,
                            bottom: 2,
                          ),
                          child: Row(
                            children: [
                              hasParent
                                  ? Icon(
                                      Icons.subdirectory_arrow_right,
                                      size: 14,
                                      color: theme.colorScheme.primary,
                                    )
                                  : CharmIcon(
                                      size: 14,
                                      color: theme.colorScheme.primary,
                                    ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: AppText(
                                  tagName,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputEditor(AppLocalizations l10n) {
    return TextField(
      controller: _textController,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      decoration: InputDecoration(
        hintText: l10n.settingsTagPresetImportTextHint,
        border: const OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      onChanged: (v) {
        if (_isImporting) return;
        if (_isValidated) {
          setState(() => _isValidated = false);
        }
      },
    );
  }

  String _validationMessage(
    AppLocalizations l10n,
    TagPresetValidationCode code,
  ) {
    return switch (code) {
      TagPresetValidationCode.emptyFacetName =>
        l10n.settingsTagPresetImportErrorEmptyFacet,
      TagPresetValidationCode.missingFacetHeader =>
        l10n.settingsTagPresetImportErrorNoFacet,
    };
  }
}
