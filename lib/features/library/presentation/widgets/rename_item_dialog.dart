import 'dart:async';
import 'package:flutter/material.dart';
import 'package:private_shelf/core/feedback/haptics_service.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/core/utils/file_name_validator.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/dialogs/dialog_actions.dart';

/// ファイル・フォルダのリネーム用共通ダイアログ
class RenameItemDialog extends StatefulWidget {
  final String initialName;
  final bool isFolder;
  final Iterable<String>? existingNames;

  const RenameItemDialog({
    super.key,
    required this.initialName,
    this.isFolder = false,
    this.existingNames,
  });

  @override
  State<RenameItemDialog> createState() => _RenameItemDialogState();
}

class _RenameItemDialogState extends State<RenameItemDialog> {
  late final TextEditingController _controller;
  late final String _extension;
  late final String _originalBaseName;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    if (widget.isFolder) {
      _extension = '';
      _originalBaseName = widget.initialName;
    } else {
      _extension = p.extension(widget.initialName);
      _originalBaseName = p.basenameWithoutExtension(widget.initialName);
    }

    _controller = TextEditingController(text: _originalBaseName);
    // 初期選択範囲をベース名全体（0〜長さ）に設定
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _originalBaseName.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate(String value, AppLocalizations l10n) {
    final trimmed = value.trim();
    final fullName = _extension.isNotEmpty ? '$trimmed$_extension' : trimmed;

    // 1. 基本ファイル名バリデーション
    var error = FileNameValidator.validateWithL10n(fullName, l10n);

    // 2. 同一階層内の同名重複チェック（変更前と同一はOK）
    if (error == null && widget.existingNames != null && trimmed.isNotEmpty) {
      final normalizedCurrent = widget.initialName.trim().toLowerCase();
      final normalizedNew = fullName.toLowerCase();

      if (normalizedCurrent != normalizedNew) {
        final isDuplicate = widget.existingNames!.any(
          (name) => name.trim().toLowerCase() == normalizedNew,
        );
        if (isDuplicate) {
          error = l10n.validationFileNameDuplicate;
        }
      }
    }

    setState(() {
      _errorText = error;
    });
  }

  void _onConfirm() {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty || _errorText != null) return;

    final fullName = _extension.isNotEmpty ? '$trimmed$_extension' : trimmed;
    unawaited(HapticsService.lightTap());
    Navigator.pop(context, fullName);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final trimmed = _controller.text.trim();
    final isNameEmpty = trimmed.isEmpty;
    final isUnchanged =
        (_extension.isNotEmpty ? '$trimmed$_extension' : trimmed) ==
        widget.initialName;
    final canSave = _errorText == null && !isNameEmpty && !isUnchanged;

    return AlertDialog(
      title: Text(l10n.viewerRename),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.commonRenameHint,
                suffixText: _extension.isNotEmpty ? _extension : null,
                suffixStyle: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
              onChanged: (val) => _validate(val, l10n),
              onSubmitted: (_) {
                if (canSave) _onConfirm();
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
          trailing: FilledButton(
            onPressed: canSave ? _onConfirm : null,
            child: Text(l10n.commonSave),
          ),
        ),
      ],
    );
  }
}

/// リネームダイアログを表示するヘルパー関数
Future<String?> showRenameItemDialog(
  BuildContext context, {
  required String initialName,
  bool isFolder = false,
  Iterable<String>? existingNames,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => RenameItemDialog(
      initialName: initialName,
      isFolder: isFolder,
      existingNames: existingNames,
    ),
  );
}
