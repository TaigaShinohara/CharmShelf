import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/preferences/app_preferences.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/dialogs/modern_dialog.dart';
import 'package:private_shelf/shared/widgets/dialogs/dialog_actions.dart';

/// 初回だけ、インポートしても元ファイルが残ることを案内する。
class ImportPickerGuideDialog extends ConsumerStatefulWidget {
  const ImportPickerGuideDialog({super.key, this.preview = false});

  final bool preview;

  static Future<bool> ensureGuideShown(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final prefs = await ref.read(appPreferencesProvider.future);
    if (prefs.importPickerGuideDismissed) return true;
    if (!context.mounted) return false;
    return await showModernDialog<bool>(
          context,
          child: const ImportPickerGuideDialog(),
        ) ??
        false;
  }

  static Future<void> showPreview(BuildContext context) async {
    await showModernDialog<bool>(
      context,
      child: const ImportPickerGuideDialog(preview: true),
    );
  }

  @override
  ConsumerState<ImportPickerGuideDialog> createState() =>
      _ImportPickerGuideDialogState();
}

class _ImportPickerGuideDialogState
    extends ConsumerState<ImportPickerGuideDialog> {
  bool _proceeding = false;

  Future<void> _proceed() async {
    if (_proceeding) return;
    setState(() => _proceeding = true);
    if (!widget.preview) {
      try {
        final prefs = await ref.read(appPreferencesProvider.future);
        await prefs.setImportPickerGuideDismissed(true);
      } catch (error, stack) {
        // 案内の既読状態を保存できなくても、ファイル選択自体は続行する。
        AppLogger.e(LogTag.ui, 'ファイル選択案内の既読状態を保存できませんでした', error, stack);
      }
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.importPickerGuideOriginalsSafeTitle,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.content_copy_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(l10n.importPickerGuideOriginalsSafeBody)),
          ],
        ),
        const SizedBox(height: 24),
        if (widget.preview)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              key: const ValueKey('picker-guide-proceed'),
              onPressed: _proceeding ? null : _proceed,
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text(l10n.commonClose, textAlign: TextAlign.center),
            ),
          )
        else
          DialogActionRow(
            leading: DialogCloseButton(
              onPressed: _proceeding
                  ? null
                  : () => Navigator.of(context).pop(false),
              semanticLabel: l10n.commonCancel,
            ),
            trailing: FilledButton(
              key: const ValueKey('picker-guide-proceed'),
              onPressed: _proceeding ? null : _proceed,
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text(
                l10n.importPickerGuideProceed,
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
