import 'package:flutter/material.dart';

/// Keeps the dismiss/back action and the primary action on one horizontal row.
///
/// [AlertDialog] lays separate actions out with an [OverflowBar], which changes
/// to a vertical stack when the labels no longer fit. Passing this widget as
/// the dialog's single action keeps the relationship between the two actions
/// horizontal, while still allowing each button label to wrap internally.
class DialogActionRow extends StatelessWidget {
  const DialogActionRow({
    super.key,
    required this.leading,
    required this.trailing,
  });

  final Widget leading;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: leading,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: trailing,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialogs use a compact close action on the left and a primary action on the
/// right. The visible icon stays language neutral while the semantic label
/// remains available to screen readers and tooltips.
class DialogCloseButton extends StatelessWidget {
  const DialogCloseButton({
    super.key,
    required this.onPressed,
    required this.semanticLabel,
  });

  final VoidCallback? onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel,
        child: IconButton(
          onPressed: onPressed,
          tooltip: semanticLabel,
          icon: const Icon(Icons.close_rounded, size: 28, weight: 700),
        ),
      ),
    );
  }
}
