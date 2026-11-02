import 'package:flutter/material.dart';

import '../widgets.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.cardWrapped = true,
    this.icon,
    this.badgeText,
    this.description,
  });

  final String title;
  final List<Widget> children;
  final bool cardWrapped;
  final IconData? icon;
  final String? badgeText;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final visibleChildren = children.where((child) {
      if (child == const SizedBox.shrink()) return false;
      if (child is SizedBox &&
          child.width == 0 &&
          child.height == 0 &&
          child.child == null) {
        return false;
      }
      return true;
    }).toList();

    if (visibleChildren.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget contentWidget;
    if (cardWrapped) {
      // 子要素間にDividerを挟む
      final dividedChildren = <Widget>[];
      for (var i = 0; i < visibleChildren.length; i++) {
        dividedChildren.add(visibleChildren[i]);
        if (i < visibleChildren.length - 1) {
          dividedChildren.add(
            Divider(
              height: 1,
              thickness: 0.5,
              indent: 64,
              endIndent: 16,
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          );
        }
      }

      contentWidget = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Material(
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
              width: 0.8,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          elevation: 0.5,
          shadowColor: colorScheme.shadow.withValues(alpha: 0.08),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: dividedChildren,
          ),
        ),
      );
    } else {
      contentWidget = Column(
        mainAxisSize: MainAxisSize.min,
        children: visibleChildren,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(
                            alpha: 0.55,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Icon(icon, size: 16, color: colorScheme.primary),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: AppText(
                        title,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (badgeText != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer.withValues(
                            alpha: 0.8,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.5,
                            ),
                            width: 0.5,
                          ),
                        ),
                        child: AppText(
                          badgeText!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  AppText(
                    description!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          contentWidget,
        ],
      ),
    );
  }
}
