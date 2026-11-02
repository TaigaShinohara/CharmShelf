import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/shared/widgets/dialogs/dialog_actions.dart';
import 'package:private_shelf/shared/widgets/dialogs/unsaved_data_dialog.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/core/error/user_safe_error_message.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/media_viewer_view_model.dart';

class MediaNotesEditorDialog extends StatefulWidget {
  final String? initialNotes;
  final Future<void> Function(String? notes)? onSave;

  const MediaNotesEditorDialog({super.key, this.initialNotes, this.onSave});

  static Future<void> show(
    BuildContext context,
    WidgetRef ref,
    MediaCollection collection,
    MediaItem currentItem,
  ) async {
    await showDialog<String>(
      context: context,
      builder: (context) => MediaNotesEditorDialog(
        initialNotes: collection.notes,
        onSave: (notes) => ref
            .read(mediaViewerViewModelProvider.notifier)
            .updateNotes(collection, currentItem, notes),
      ),
    );
  }

  @override
  State<MediaNotesEditorDialog> createState() => _MediaNotesEditorDialogState();
}

class _MediaNotesEditorDialogState extends State<MediaNotesEditorDialog> {
  late final TextEditingController _controller;
  bool _isSaving = false;
  bool _isConfirmingClose = false;
  String? _errorMessage;

  String? _normalizedNotes(String? notes) {
    final value = notes?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  bool get _hasChanges =>
      _normalizedNotes(_controller.text) !=
      _normalizedNotes(widget.initialNotes);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNotes);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving || _isConfirmingClose) return;
    final notes = _normalizedNotes(_controller.text);
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await widget.onSave?.call(notes);
      if (!mounted) return;
      Navigator.of(context).pop(_controller.text);
    } catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _isSaving = false;
        _errorMessage =
            '${l10n.viewerNotesSaveFailed}\n${userSafeErrorMessage(error, l10n)}';
      });
    }
  }

  Future<void> _requestClose() async {
    if (_isSaving || _isConfirmingClose) return;
    if (!_hasChanges) {
      Navigator.of(context).pop();
      return;
    }
    _isConfirmingClose = true;
    final discard = await showUnsavedDataDialog(context);
    _isConfirmingClose = false;
    if (mounted && discard) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope<String>(
      canPop: !_isSaving && !_hasChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _requestClose();
      },
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        scrollable: true,
        title: Text(l10n.settingsCollectionNotes),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const ValueKey('media-notes-input'),
                controller: _controller,
                enabled: !_isSaving,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: l10n.settingsCollectionNotesHint,
                ),
                maxLines: 5,
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _errorMessage!,
                    key: const ValueKey('media-notes-save-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          DialogActionRow(
            leading: DialogCloseButton(
              onPressed: _isSaving ? null : _requestClose,
              semanticLabel: l10n.commonCancel,
            ),
            trailing: ElevatedButton(
              key: const ValueKey('media-notes-save'),
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Flexible(child: Text(l10n.viewerNotesSaving)),
                      ],
                    )
                  : Text(
                      _errorMessage == null
                          ? l10n.commonSave
                          : l10n.commonRetry,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
