import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/shared/widgets/feedback/app_menu_action_feedback.dart';

/// アクションシート内のグループセクションコンテナ
class ActionSheetSection extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final bool isDanger;

  const ActionSheetSection({
    super.key,
    this.title,
    required this.children,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDanger
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDanger
              ? theme.colorScheme.error.withValues(alpha: 0.2)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                title!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isDanger
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ...children,
        ],
      ),
    );
  }
}

/// アクションシート内の各操作行タイル
class ActionSheetTile extends ConsumerWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final String? subtitle;
  final int? subtitleMaxLines;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? iconColor;
  final Color? textColor;

  const ActionSheetTile({
    super.key,
    this.icon,
    this.iconWidget,
    required this.label,
    this.subtitle,
    this.subtitleMaxLines = 1,
    required this.onTap,
    this.trailing,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ?? theme.colorScheme.primary;
    final effectiveTextColor = textColor ?? theme.colorScheme.onSurface;

    return AppMenuActionFeedback(
      // Keep the feedback path available for the tile while allowing the
      // catalog action to render its authored SVG symbol.
      icon: icon,
      iconWidget: iconWidget,
      iconColor: effectiveIconColor,
      onPressed: () {
        unawaited(ref.read(feedbackServiceProvider).lightImpact());
        onTap();
      },
      builder: (context, animatedIcon, onPressed) => InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: effectiveIconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconTheme.merge(
                  data: IconThemeData(color: effectiveIconColor, size: 20),
                  child: Center(child: iconWidget ?? animatedIcon),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: effectiveTextColor,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.75,
                          ),
                          fontSize: 11,
                        ),
                        maxLines: subtitleMaxLines,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: theme.colorScheme.outlineVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// スイッチ付きのトグル操作行タイル（非表示やアーカイブ用）
class ActionSheetSwitchTile extends ConsumerWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;

  const ActionSheetSwitchTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = value
        ? (activeColor ?? theme.colorScheme.primary)
        : theme.colorScheme.onSurfaceVariant;

    return AppMenuActionFeedback(
      icon: icon,
      iconColor: color,
      onPressed: () {
        unawaited(ref.read(feedbackServiceProvider).lightImpact());
        onChanged(!value);
      },
      builder: (context, animatedIcon, onPressed) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: value
                    ? color.withValues(alpha: 0.12)
                    : theme.colorScheme.surfaceContainerHigh.withValues(
                        alpha: 0.6,
                      ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: animatedIcon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: value ? color : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.75,
                        ),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              activeTrackColor: activeColor,
              onChanged: (_) => onPressed(),
            ),
          ],
        ),
      ),
    );
  }
}

/// プロパティ表示用のカードタイル（2列グリッドや全幅での複数行プレビューに対応）
class ActionSheetPropertyCard extends ConsumerWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Color? iconColor;
  final int maxLines;
  final VoidCallback onTap;

  const ActionSheetPropertyCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.iconColor,
    this.maxLines = 1,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ?? theme.colorScheme.primary;

    return AppMenuActionFeedback(
      icon: icon,
      iconColor: effectiveIconColor,
      onPressed: () {
        unawaited(ref.read(feedbackServiceProvider).lightImpact());
        onTap();
      },
      builder: (context, animatedIcon, onPressed) => InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh.withValues(
              alpha: 0.5,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: maxLines > 1
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.only(top: maxLines > 1 ? 2.0 : 0.0),
                child: animatedIcon,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: valueColor ?? theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.3,
                      ),
                      maxLines: maxLines,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: EdgeInsets.only(top: maxLines > 1 ? 2.0 : 0.0),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
