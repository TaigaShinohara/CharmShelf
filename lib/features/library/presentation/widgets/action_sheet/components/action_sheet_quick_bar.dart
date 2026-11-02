import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/shared/widgets/feedback/app_menu_action_feedback.dart';

/// 高頻度操作（共有・お気に入り・ピン・タグ・表紙等）を並べるクイックアクションバー
class ActionSheetQuickBar extends ConsumerWidget {
  final List<QuickBarAction> actions;

  const ActionSheetQuickBar({super.key, required this.actions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (actions.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(11) > 15;
          final columns = actions.length.clamp(
            1,
            largeText || constraints.maxWidth < 280 ? 2 : 4,
          );
          final width = (constraints.maxWidth - 4 * (columns - 1)) / columns;
          return Wrap(
            spacing: 4,
            runSpacing: 8,
            children: [
              for (final action in actions)
                SizedBox(
                  width: width,
                  child: _buildActionButton(context, ref, action),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    WidgetRef ref,
    QuickBarAction action,
  ) {
    final theme = Theme.of(context);
    final color = action.isActive
        ? (action.activeColor ?? theme.colorScheme.primary)
        : theme.colorScheme.onSurfaceVariant;

    return AppMenuActionFeedback(
      icon: action.icon,
      iconWidget: action.iconWidget == null
          ? null
          : IconTheme.merge(
              data: IconThemeData(color: color, size: 22),
              child: action.iconWidget!,
            ),
      iconColor: color,
      iconSize: 22,
      onPressed: () {
        unawaited(ref.read(feedbackServiceProvider).lightImpact());
        action.onTap();
      },
      builder: (context, animatedIcon, onPressed) => Semantics(
        button: true,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: action.isActive
                        ? color.withValues(alpha: 0.15)
                        : theme.colorScheme.surfaceContainerHigh.withValues(
                            alpha: 0.6,
                          ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: animatedIcon),
                ),
                const SizedBox(height: 5),
                Text(
                  action.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: action.isActive
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QuickBarAction {
  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final Color? activeColor;

  const QuickBarAction({
    this.icon,
    this.iconWidget,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.activeColor,
  }) : assert(icon != null || iconWidget != null);
}
