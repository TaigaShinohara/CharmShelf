import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

import '../../../core/feedback/feedback_providers.dart';
import '../widgets.dart';

/// 「はい/いいえ」の確認ダイアログ
class ConfirmDialog extends ConsumerWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel,
    this.cancelLabel,
    this.isDestructive = false,
  });

  final String title;
  final String message;
  final String? confirmLabel;
  final String? cancelLabel;
  final bool isDestructive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final hasFormatting =
        message.contains('**') ||
        message.contains('[error]') ||
        message.contains('[primary]');

    return AlertDialog(
      title: AppText(title, wrapWords: false),
      content: hasFormatting
          ? AppFormattedText(message)
          : AppText(message, wrapWords: false),
      actions: [
        DialogActionRow(
          leading: DialogCloseButton(
            onPressed: () {
              ref.read(feedbackServiceProvider).lightImpact();
              Navigator.of(context).pop(false);
            },
            semanticLabel: cancelLabel ?? l10n.commonCancel,
          ),
          trailing: FilledButton(
            style: isDestructive
                ? FilledButton.styleFrom(
                    enableFeedback: false,
                    backgroundColor: scheme.error,
                  )
                : FilledButton.styleFrom(enableFeedback: false),
            onPressed: () {
              if (isDestructive) {
                ref.read(feedbackServiceProvider).heavyImpact();
              } else {
                ref.read(feedbackServiceProvider).lightImpact();
              }
              Navigator.of(context).pop(true);
            },
            child: AppText(confirmLabel ?? l10n.commonYes, wrapWords: false),
          ),
        ),
      ],
    );
  }
}

/// 確認ダイアログを表示します。
///
/// `barrierDismissible=false` が標準（誤タップで閉じない）。
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool isDestructive = false,
  bool barrierDismissible = false,
  bool useRootNavigator = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    useRootNavigator: useRootNavigator,
    builder: (context) => ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      isDestructive: isDestructive,
    ),
  );
  return result ?? false;
}
