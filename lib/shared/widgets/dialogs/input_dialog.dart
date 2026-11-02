import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import '../widgets.dart';

import '../../../core/feedback/feedback_providers.dart';

/// テキスト入力付きダイアログ
class InputDialog extends ConsumerStatefulWidget {
  const InputDialog({
    super.key,
    required this.title,
    this.message,
    this.initialText,
    this.hintText,
    this.okLabel,
    this.cancelLabel,
    this.keyboardType,
    this.maxLength,
    this.obscureText = false,
    this.validator,
  });

  final String title;
  final String? message;
  final String? initialText;
  final String? hintText;
  final String? okLabel;
  final String? cancelLabel;
  final TextInputType? keyboardType;
  final int? maxLength;
  final bool obscureText;
  final String? Function(String value)? validator;

  @override
  ConsumerState<InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends ConsumerState<InputDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final ok = _formKey.currentState?.validate() ?? true;
    if (!ok) return;
    Navigator.of(context).pop<String>(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: AppText(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.message != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: AppText(widget.message!),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _controller,
              keyboardType: widget.keyboardType,
              maxLength: widget.maxLength,
              obscureText: widget.obscureText,
              autofocus: true,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: InputDecoration(hintText: widget.hintText),
              validator: (v) {
                if (widget.validator == null) return null;
                return widget.validator!(v ?? '');
              },
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        DialogActionRow(
          leading: DialogCloseButton(
            onPressed: () {
              ref.read(feedbackServiceProvider).lightImpact();
              Navigator.of(context).pop<String?>(null);
            },
            semanticLabel: widget.cancelLabel ?? l10n.commonCancel,
          ),
          trailing: FilledButton(
            style: FilledButton.styleFrom(enableFeedback: false),
            onPressed: () {
              ref.read(feedbackServiceProvider).lightImpact();
              _submit();
            },
            child: AppText(widget.okLabel ?? l10n.commonOk),
          ),
        ),
      ],
    );
  }
}

/// 入力ダイアログを表示して、入力された文字列を返します（キャンセルは null）。
Future<String?> showInputDialog(
  BuildContext context, {
  required String title,
  String? message,
  String? initialText,
  String? hintText,
  String? okLabel,
  String? cancelLabel,
  TextInputType? keyboardType,
  int? maxLength,
  bool obscureText = false,
  String? Function(String value)? validator,
  bool barrierDismissible = false,
  bool useRootNavigator = false,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: barrierDismissible,
    useRootNavigator: useRootNavigator,
    builder: (context) => InputDialog(
      title: title,
      message: message,
      initialText: initialText,
      hintText: hintText,
      okLabel: okLabel,
      cancelLabel: cancelLabel,
      keyboardType: keyboardType,
      maxLength: maxLength,
      obscureText: obscureText,
      validator: validator,
    ),
  );
}
