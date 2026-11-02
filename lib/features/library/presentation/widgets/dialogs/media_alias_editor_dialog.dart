import 'package:flutter/material.dart';
import 'package:private_shelf/shared/widgets/feedback/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/core/error/user_safe_error_message.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/media_viewer_view_model.dart';
import 'package:private_shelf/shared/widgets/dialogs/dialog_actions.dart';

class MediaAliasEditorDialog extends StatefulWidget {
  final String? initialAlias;

  const MediaAliasEditorDialog({super.key, this.initialAlias});

  static Future<void> show(
    BuildContext context,
    WidgetRef ref,
    MediaCollection collection,
    MediaItem currentItem,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<String>(
      context: context,
      builder: (context) =>
          MediaAliasEditorDialog(initialAlias: collection.alias),
    );

    if (result != null) {
      final newAlias = result.trim().isEmpty ? null : result.trim();
      try {
        await ref
            .read(mediaViewerViewModelProvider.notifier)
            .updateAlias(collection, currentItem, newAlias);
      } catch (e) {
        if (context.mounted) {
          AppSnackBarMessenger.of(context).showSnackBar(
            SnackBar(content: Text(userSafeErrorMessage(e, l10n))),
          );
        }
      }
    }
  }

  @override
  State<MediaAliasEditorDialog> createState() => _MediaAliasEditorDialogState();
}

class _MediaAliasEditorDialogState extends State<MediaAliasEditorDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialAlias);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.settingsCollectionAlias),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsCollectionAliasDescription,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: l10n.settingsCollectionAliasHint,
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        DialogActionRow(
          leading: DialogCloseButton(
            onPressed: () => Navigator.pop(context),
            semanticLabel: l10n.commonCancel,
          ),
          trailing: ElevatedButton(
            onPressed: () => Navigator.pop(context, _controller.text),
            child: Text(l10n.commonSave),
          ),
        ),
      ],
    );
  }
}
