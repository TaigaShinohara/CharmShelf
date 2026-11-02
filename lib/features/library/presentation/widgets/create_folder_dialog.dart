import 'package:flutter/material.dart';
import 'package:private_shelf/core/utils/file_name_validator.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/dialogs/dialog_actions.dart';

/// 新規フォルダ作成用ダイアログ
class CreateFolderDialog extends StatefulWidget {
  final String? initialName;

  const CreateFolderDialog({super.key, this.initialName});

  @override
  State<CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<CreateFolderDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  void _validate(String value, AppLocalizations l10n) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      if (_errorText != null) {
        setState(() {
          _errorText = null;
        });
      }
      return;
    }
    final error = FileNameValidator.validateWithL10n(value, l10n);
    if (_errorText != error) {
      setState(() {
        _errorText = error;
      });
    }
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty &&
        _errorText == null &&
        FileNameValidator.isValid(text)) {
      Navigator.of(context).pop(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isNameEmpty = _controller.text.trim().isEmpty;
    final canCreate =
        _errorText == null &&
        !isNameEmpty &&
        FileNameValidator.isValid(_controller.text.trim());

    return AlertDialog(
      title: Text(l10n.libraryNewFolder),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: l10n.libraryNewFolderHint,
          errorText: _errorText,
        ),
        textInputAction: TextInputAction.done,
        onChanged: (val) => _validate(val, l10n),
        onSubmitted: (_) {
          if (canCreate) {
            _submit();
          }
        },
      ),
      actions: [
        DialogActionRow(
          leading: DialogCloseButton(
            onPressed: () => Navigator.of(context).pop(),
            semanticLabel: l10n.commonCancel,
          ),
          trailing: FilledButton(
            onPressed: canCreate ? _submit : null,
            child: Text(l10n.commonCreate),
          ),
        ),
      ],
    );
  }
}
