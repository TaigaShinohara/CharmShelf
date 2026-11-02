import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/feedback_providers.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../widgets.dart';

class SettingsTile extends ConsumerWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.value,
    this.valueIcon,
    this.onTap,
    this.iconColor,
    this.iconBackgroundColor,
    this.semanticLabel,
    this.onInfoTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String? value;
  final IconData? valueIcon;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final String? semanticLabel;
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

    final tile = LayoutBuilder(
      builder: (context, constraints) {
        final stackValue =
            trailing == null &&
            value != null &&
            constraints.maxWidth < 480 &&
            MediaQuery.textScalerOf(context).scale(16) > 22;
        final description = subtitle == null
            ? null
            : AppText(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              );
        return ListTile(
          enableFeedback: false,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 2,
          ),
          leading: Container(
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
          subtitle: stackValue
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // build_runner's analyzer does not parse null-aware
                    // collection elements yet.
                    // ignore: use_null_aware_elements
                    if (description != null) description,
                    const SizedBox(height: 6),
                    _SettingsValueBadge(
                      label: value!,
                      icon: valueIcon,
                      showChevron: false,
                      wrapLabel: true,
                    ),
                  ],
                )
              : description,
          trailing:
              trailing ??
              (stackValue
                  ? (onTap == null
                        ? null
                        : Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: colorScheme.outline,
                          ))
                  : (value == null
                        ? null
                        : _SettingsValueBadge(
                            label: value!,
                            icon: valueIcon,
                            showChevron: onTap != null,
                          ))),
          onTap: onTap == null
              ? null
              : () {
                  ref.read(feedbackServiceProvider).lightImpact();
                  onTap?.call();
                },
        );
      },
    );

    if (semanticLabel != null) {
      return Semantics(
        label: semanticLabel,
        button: onTap != null,
        child: tile,
      );
    }

    return tile;
  }
}

class _SettingsValueBadge extends StatelessWidget {
  const _SettingsValueBadge({
    required this.label,
    required this.showChevron,
    this.icon,
    this.wrapLabel = false,
  });

  final String label;
  final bool showChevron;
  final IconData? icon;
  final bool wrapLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: wrapLabel ? double.infinity : 132,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: colorScheme.onSecondaryContainer),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: AppText(
                    label,
                    maxLines: wrapLabel ? null : 1,
                    overflow: wrapLabel
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showChevron) ...[
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 18, color: colorScheme.outline),
        ],
      ],
    );
  }
}
