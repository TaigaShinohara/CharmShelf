import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/feedback/app_menu_action_feedback.dart';

/// 危険操作（削除・カタログ解除等）セクション
class ActionSheetDangerSection extends ConsumerWidget {
  final List<DangerAction> actions;

  const ActionSheetDangerSection({super.key, required this.actions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (actions.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              l10n.librarySectionDanger,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _buildDangerButton(context, ref, actions[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDangerButton(
    BuildContext context,
    WidgetRef ref,
    DangerAction action,
  ) {
    final theme = Theme.of(context);
    return AppMenuActionFeedback(
      icon: action.icon,
      iconWidget: action.iconWidget == null
          ? null
          : IconTheme.merge(
              data: IconThemeData(color: theme.colorScheme.error, size: 18),
              child: action.iconWidget!,
            ),
      iconColor: theme.colorScheme.error,
      iconSize: 18,
      onPressed: () {
        unawaited(ref.read(feedbackServiceProvider).heavyImpact());
        action.onTap();
      },
      builder: (context, animatedIcon, onPressed) => InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.error.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              animatedIcon,
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  action.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DangerAction {
  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final VoidCallback onTap;

  const DangerAction({
    this.icon,
    this.iconWidget,
    required this.label,
    required this.onTap,
  }) : assert(icon != null || iconWidget != null);
}
