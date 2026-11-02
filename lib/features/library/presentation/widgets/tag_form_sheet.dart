import 'package:flutter/material.dart';
import 'package:private_shelf/shared/widgets/feedback/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/core/error/user_safe_error_message.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_facet_view_model.dart';
import 'package:private_shelf/shared/widgets/sheets/app_bottom_sheet.dart';
import 'package:private_shelf/shared/widgets/tag/app_tag.dart';
import 'package:private_shelf/shared/widgets/dialogs/dialog_actions.dart';

/// タグ新規作成/編集のボトムシートを表示するヘルパー関数
Future<bool?> showTagFormSheet(
  BuildContext context, {
  Tag? tag,
  int? initialFacetId,
  String? initialName,
  ValueChanged<Tag>? onCreated,
}) {
  final l10n = AppLocalizations.of(context)!;
  final saveInProgress = ValueNotifier(false);
  return showAppBottomSheet<bool>(
    context,
    useRootNavigator: true,
    dismissBlocked: saveInProgress,
    title: tag != null ? l10n.tagEditDialogTitle : l10n.tagNewDialogTitle,
    child: TagFormSheet(
      tag: tag,
      initialFacetId: initialFacetId,
      initialName: initialName,
      onCreated: onCreated,
      saveInProgress: saveInProgress,
    ),
  ).whenComplete(saveInProgress.dispose);
}

// Session-scoped drafts survive accidental sheet dismissal without a confirmation.
// They are cleared only after a successful save or deletion.
final _tagFormDraftsProvider = Provider(
  (ref) => <(int?, int?, String?), _TagFormDraft>{},
);

class _TagFormDraft {
  const _TagFormDraft(this.name, this.facetId, this.parentId, this.isHidden);

  final String name;
  final int? facetId;
  final int? parentId;
  final bool isHidden;
}

/// タグの新規作成/編集を行うボトムシートウィジェット
class TagFormSheet extends ConsumerStatefulWidget {
  /// 編集対象のタグ（nullの場合は新規作成モード）
  final Tag? tag;

  /// 新規作成時の初期Facet ID
  final int? initialFacetId;

  final String? initialName;
  final ValueChanged<Tag>? onCreated;
  final ValueNotifier<bool>? saveInProgress;

  const TagFormSheet({
    super.key,
    this.tag,
    this.initialFacetId,
    this.initialName,
    this.onCreated,
    this.saveInProgress,
  });

  @override
  ConsumerState<TagFormSheet> createState() => _TagFormSheetState();
}

class _TagFormSheetState extends ConsumerState<TagFormSheet> {
  late final TextEditingController _nameController;
  int? _selectedFacetId;
  int? _selectedParentId;
  bool _isHidden = false;
  bool _isSaving = false;
  bool _isConfirmingDelete = false;
  bool _hasSaved = false;
  String? _saveError;

  bool get _isEditMode => widget.tag != null;
  (int?, int?, String?) get _draftKey => (
    widget.tag?.id,
    widget.initialFacetId,
    widget.tag == null ? widget.initialName : null,
  );
  late final Map<(int?, int?, String?), _TagFormDraft> _drafts;

  void _keepDraft() {
    if (_hasSaved) return;
    final name = _nameController.text;
    final initialName = widget.tag?.name ?? widget.initialName ?? '';
    final initialFacet = widget.tag?.facetId ?? widget.initialFacetId;
    if (name == initialName &&
        _selectedFacetId == initialFacet &&
        _selectedParentId == widget.tag?.parentId &&
        _isHidden == (widget.tag?.isHidden ?? false)) {
      _drafts.remove(_draftKey);
      return;
    }
    _drafts[_draftKey] = _TagFormDraft(
      name,
      _selectedFacetId,
      _selectedParentId,
      _isHidden,
    );
  }

  @override
  void initState() {
    super.initState();
    _drafts = ref.read(_tagFormDraftsProvider);
    final draft = _drafts[_draftKey];
    _nameController = TextEditingController(
      text: draft?.name ?? widget.tag?.name ?? widget.initialName ?? '',
    );
    _selectedFacetId = draft != null
        ? draft.facetId
        : widget.tag?.facetId ?? widget.initialFacetId;
    _selectedParentId = draft != null ? draft.parentId : widget.tag?.parentId;
    _isHidden = draft?.isHidden ?? widget.tag?.isHidden ?? false;
    _nameController.addListener(_keepDraft);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final asyncFacets = ref.watch(tagFacetListViewModelProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: asyncFacets.when(
        data: (facets) => _buildForm(context, l10n, theme, facets),
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => SizedBox(
          height: 200,
          child: Center(child: Text(userSafeErrorMessage(e, l10n))),
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    List<TagFacet> facets,
  ) {
    final facetColorMap = {
      for (final f in facets)
        if (f.colorValue != null) f.id: Color(f.colorValue!),
    };

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // タグ名入力
          _SectionHeader(title: l10n.tagNewDialogHint),
          const SizedBox(height: 8),
          TextField(
            enabled: !_isSaving,
            controller: _nameController,
            decoration: InputDecoration(
              hintText: l10n.tagNameExample,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
            ),
            autofocus: !_isEditMode,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 20),

          // Facet 選択
          _SectionHeader(title: l10n.tagFacetLabel),
          const SizedBox(height: 8),
          if (facets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l10n.tagFacetEmptyHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: facets.map((facet) {
                final isSelected = _selectedFacetId == facet.id;
                final color =
                    facetColorMap[facet.id] ?? theme.colorScheme.primary;
                return FacetChip(
                  label: facet.name,
                  color: color,
                  isSelected: isSelected,
                  onSelected: _isSaving
                      ? null
                      : (selected) {
                          setState(() {
                            _selectedFacetId = selected ? facet.id : null;
                            _selectedParentId = null;
                            _keepDraft();
                          });
                        },
                );
              }).toList(),
            ),
          const SizedBox(height: 28),

          if (_saveError != null) ...[
            Text(
              _saveError!,
              key: const ValueKey('tag-form-save-error'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 12),
          ],
          // 保存ボタン
          FilledButton(
            onPressed: _isSaving ? null : _handleSave,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _isEditMode ? l10n.commonUpdate : l10n.tagCreate,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          if (_isEditMode) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _handleDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.commonDelete),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppSnackBarMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.tagTitleRequired)));
      return;
    }

    widget.saveInProgress?.value = true;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      if (_isEditMode) {
        await ref
            .read(tagListViewModelProvider.notifier)
            .updateTag(
              widget.tag!,
              name: name,
              facetId: _selectedFacetId,
              parentId: _selectedParentId,
              isHidden: _isHidden,
            );
      } else {
        final created = await ref
            .read(tagListViewModelProvider.notifier)
            .addTag(
              name,
              facetId: _selectedFacetId,
              parentId: _selectedParentId,
              isHidden: _isHidden,
            );
        widget.onCreated?.call(created);
      }
      widget.saveInProgress?.value = false;
      _hasSaved = true;
      _drafts.remove(_draftKey);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      widget.saveInProgress?.value = false;
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveError = userSafeErrorMessage(e, l10n);
        });
      }
    }
  }

  Future<void> _handleDelete() async {
    if (_isSaving || _isConfirmingDelete) return;
    final tag = widget.tag;
    if (tag == null) return;

    final l10n = AppLocalizations.of(context)!;
    _isConfirmingDelete = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.tagDeleteConfirm),
        content: Text(l10n.tagDeleteMessage(tag.name)),
        actions: [
          DialogActionRow(
            leading: DialogCloseButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              semanticLabel: l10n.commonCancel,
            ),
            trailing: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: Text(l10n.commonDelete),
            ),
          ),
        ],
      ),
    ).whenComplete(() => _isConfirmingDelete = false);

    if (confirmed != true || !mounted) return;
    widget.saveInProgress?.value = true;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      await ref.read(tagListViewModelProvider.notifier).deleteTag(tag.id);
      widget.saveInProgress?.value = false;
      _hasSaved = true;
      _drafts.remove(_draftKey);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      widget.saveInProgress?.value = false;
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveError = userSafeErrorMessage(e, l10n);
        });
      }
    }
  }
}

/// セクションヘッダーウィジェット
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
    );
  }
}
