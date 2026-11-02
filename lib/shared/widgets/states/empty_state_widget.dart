import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// 共通空状態表示ウィジェット
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.action,
    this.iconColor,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ?? theme.colorScheme.outline;

    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.edgeInsetsXl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppIconSize.emptyState, color: effectiveIconColor),
            AppSpacing.gapVerticalMd,
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (subtitle != null) ...[
              AppSpacing.gapVerticalSm,
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[AppSpacing.gapVerticalLg, action!],
          ],
        ),
      ),
    );
  }
}

/// CustomScrollView 内で使用できる Sliver 版空状態ウィジェット
class SliverEmptyStateWidget extends StatelessWidget {
  const SliverEmptyStateWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.action,
    this.iconColor,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: EmptyStateWidget(
        title: title,
        subtitle: subtitle,
        icon: icon,
        action: action,
        iconColor: iconColor,
      ),
    );
  }
}
