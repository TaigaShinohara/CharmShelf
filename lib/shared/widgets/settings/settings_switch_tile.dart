import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/feedback_providers.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../widgets.dart';

class SettingsSwitchTile extends ConsumerWidget {
  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.iconColor,
    this.iconBackgroundColor,
    this.onInfoTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final VoidCallback? onInfoTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final effectiveIconColor = iconColor ?? colorScheme.primary;
    final effectiveIconBg =
        iconBackgroundColor ??
        colorScheme.primaryContainer.withValues(alpha: 0.5);

    final titleWidget = onInfoTap == null
        ? AppText(
            title,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: AppText(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  Icons.info_outline,
                  size: 18,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
                tooltip: l10n?.tooltipInfo ?? '',
                onPressed: () {
                  ref.read(feedbackServiceProvider).lightImpact();
                  onInfoTap?.call();
                },
              ),
            ],
          );

    return SwitchListTile(
      enableFeedback: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: effectiveIconBg,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: effectiveIconColor),
      ),
      title: titleWidget,
      subtitle: subtitle != null
          ? AppText(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      value: value,
      onChanged: enabled
          ? (next) {
              ref.read(feedbackServiceProvider).lightImpact();
              onChanged(next);
            }
          : null,
    );
  }
}
