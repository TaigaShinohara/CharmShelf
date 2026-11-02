import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/core/error/user_safe_error_message.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/player_notifier.dart';
import 'package:private_shelf/shared/widgets/dialogs/dialog_actions.dart';

class MediaThumbnailPreviewDialog extends ConsumerStatefulWidget {
  final MediaItem item;
  final int positionMs;

  const MediaThumbnailPreviewDialog({
    super.key,
    required this.item,
    required this.positionMs,
  });

  @override
  ConsumerState<MediaThumbnailPreviewDialog> createState() =>
      _MediaThumbnailPreviewDialogState();
}

class _MediaThumbnailPreviewDialogState
    extends ConsumerState<MediaThumbnailPreviewDialog> {
  String? _tempPreviewPath;
  Object? _error;
  bool _isGenerating = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _generatePreview();
  }

  Future<void> _generatePreview() async {
    final result = await ref
        .read(playerNotifierProvider.notifier)
        .generateVideoThumbnailPreview(widget.positionMs);

    if (!mounted) return;

    setState(() {
      _isGenerating = false;
      result.when(
        success: (path) => _tempPreviewPath = path,
        failure: (err) => _error = err,
      );
    });
  }

  Future<void> _confirmThumbnail() async {
    if (_tempPreviewPath == null) return;

    setState(() {
      _isSaving = true;
    });

    final result = await ref
        .read(playerNotifierProvider.notifier)
        .updateThumbnailWithPath(_tempPreviewPath!);

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    result.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (err) {
        setState(() {
          _error = err;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final docsDir = ref.watch(applicationDocumentsPathProvider).value;

    return AlertDialog(
      title: Text(l10n.viewerThumbnailPreviewTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: _isGenerating
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            userSafeErrorMessage(_error, l10n),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _tempPreviewPath != null && docsDir != null
                    ? Image.file(
                        File(p.join(docsDir, _tempPreviewPath!)),
                        fit: BoxFit.contain,
                      )
                    : const Center(child: Icon(Icons.image_not_supported)),
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.viewerThumbnailSetConfirm),
          ],
        ),
      ),
      actions: [
        DialogActionRow(
          leading: DialogCloseButton(
            onPressed: _isSaving
                ? null
                : () => Navigator.of(context).pop(false),
            semanticLabel: l10n.commonCancel,
          ),
          trailing: ElevatedButton(
            onPressed:
                _isGenerating ||
                    _isSaving ||
                    _tempPreviewPath == null ||
                    _error != null
                ? null
                : _confirmThumbnail,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.viewerSetThumbnail),
          ),
        ),
      ],
    );
  }
}
