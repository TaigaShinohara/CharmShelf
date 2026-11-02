import 'package:flutter/material.dart';
import 'package:private_shelf/shared/widgets/feedback/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/core/error/user_safe_error_message.dart';
import 'package:private_shelf/core/theme/app_colors.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_facet_view_model.dart';
import 'package:private_shelf/shared/widgets/sheets/app_bottom_sheet.dart';

/// Facet新規作成/編集のボトムシートを表示するヘルパー関数
Future<bool?> showFacetFormSheet(BuildContext context, {TagFacet? facet}) {
  final l10n = AppLocalizations.of(context)!;
  final saveInProgress = ValueNotifier(false);
  return showAppBottomSheet<bool>(
    context,
    dismissBlocked: saveInProgress,
    title: facet != null ? l10n.tagFacetEditTitle : l10n.tagFacetAddTitle,
    child: FacetFormSheet(facet: facet, saveInProgress: saveInProgress),
  ).whenComplete(saveInProgress.dispose);
}

final _facetFormDraftsProvider = Provider((ref) => <int?, (String, int?)>{});

/// Facetの新規作成/編集を行うボトムシートウィジェット
class FacetFormSheet extends ConsumerStatefulWidget {
  /// 編集対象のFacet（nullの場合は新規作成モード）
  final TagFacet? facet;

  final ValueNotifier<bool>? saveInProgress;

  const FacetFormSheet({super.key, this.facet, this.saveInProgress});

  @override
  ConsumerState<FacetFormSheet> createState() => _FacetFormSheetState();
}

class _FacetFormSheetState extends ConsumerState<FacetFormSheet> {
  late final TextEditingController _nameController;
  int? _selectedColorValue;
  bool _isSaving = false;
  bool _hasSaved = false;
  String? _saveError;

  bool get _isEditMode => widget.facet != null;
  late final Map<int?, (String, int?)> _drafts;

  void _keepDraft() {
    if (_hasSaved) return;
    if (_nameController.text == (widget.facet?.name ?? '') &&
        _selectedColorValue == widget.facet?.colorValue) {
      _drafts.remove(widget.facet?.id);
    } else {
      _drafts[widget.facet?.id] = (_nameController.text, _selectedColorValue);
    }
  }

  @override
  void initState() {
    super.initState();
    _drafts = ref.read(_facetFormDraftsProvider);
    final draft = _drafts[widget.facet?.id];
    _nameController = TextEditingController(
      text: draft?.$1 ?? widget.facet?.name ?? '',
    );
    _selectedColorValue = draft != null ? draft.$2 : widget.facet?.colorValue;
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

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Facet名入力
            _SectionHeader(title: l10n.tagFacetLabel, icon: Icons.view_list),
            const SizedBox(height: 8),
            TextField(
              enabled: !_isSaving,
              controller: _nameController,
              decoration: InputDecoration(
                hintText: l10n.tagFacetNameHint,
                prefixIcon: const Icon(Icons.view_list),
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              autofocus: !_isEditMode,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 28),

            // 色選択
            _SectionHeader(
              title: l10n.tagColorLabel,
              icon: Icons.palette_outlined,
            ),
            const SizedBox(height: 12),
            _buildColorPalette(theme, l10n),
            const SizedBox(height: 32),

            if (_saveError != null) ...[
              Text(
                _saveError!,
                key: const ValueKey('facet-form-save-error'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 12),
            ],
            // 保存ボタン
            FilledButton.icon(
              onPressed: _isSaving ? null : _handleSave,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_isEditMode ? Icons.save : Icons.add),
              label: Text(
                _isEditMode ? l10n.commonUpdate : l10n.commonCreate,
                style: const TextStyle(fontSize: 16),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPalette(ThemeData theme, AppLocalizations l10n) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: AppColors.tagColors.asMap().entries.map((entry) {
        final index = entry.key;
        final color = entry.value;
        final colorValue = color.toARGB32();
        final isSelected = _selectedColorValue == colorValue;
        return Semantics(
          key: ValueKey('facet-color-$index'),
          button: true,
          selected: isSelected,
          label: '${l10n.tagColorLabel} ${index + 1}',
          child: GestureDetector(
            onTap: _isSaving
                ? null
                : () => setState(() {
                    _selectedColorValue = colorValue;
                    _keepDraft();
                  }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: theme.colorScheme.primary, width: 3)
                    : Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      size: 20,
                      color: color.computeLuminance() > 0.5
                          ? Colors.black87
                          : Colors.white,
                    )
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppSnackBarMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.tagFacetNameRequired)));
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
            .read(tagFacetListViewModelProvider.notifier)
            .updateFacet(
              widget.facet!,
              name: name,
              colorValue: _selectedColorValue,
            );
      } else {
        await ref
            .read(tagFacetListViewModelProvider.notifier)
            .addFacet(name, colorValue: _selectedColorValue);
      }
      widget.saveInProgress?.value = false;
      _hasSaved = true;
      _drafts.remove(widget.facet?.id);
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
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
