import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/feedback_providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../accessibility/semantic_wrapper.dart';

/// 単一選択ダイアログの選択肢定義
class SelectionOption<T> {
  const SelectionOption({
    required this.value,
    required this.title,
    this.subtitle,
    this.icon,
  });

  final T value;
  final String title;
  final String? subtitle;
  final IconData? icon;
}

/// 統一された単一選択ダイアログコンポーネント
class AppSelectionDialog<T> extends ConsumerWidget {
  const AppSelectionDialog({
    super.key,
    required this.title,
    required this.options,
    required this.selectedValue,
    this.onSelected,
  });

  final String title;
  final List<SelectionOption<T>> options;
  final T? selectedValue;
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Text(title),
      contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((option) {
            final isSelected = option.value == selectedValue;
            return SemanticWrapper(
              isButton: true,
              label: option.title,
              value: isSelected ? '選択中' : null,
              excludeSemantics: true,
              onTap: () {
                ref.read(feedbackServiceProvider).selection();
                if (onSelected != null) {
                  onSelected!(option.value);
                }
                Navigator.of(context).pop(option.value);
              },
              child: InkWell(
                onTap: () {
                  ref.read(feedbackServiceProvider).selection();
                  if (onSelected != null) {
                    onSelected!(option.value);
                  }
                  Navigator.of(context).pop(option.value);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: AppIconSize.md,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      if (option.icon != null) ...[
                        AppSpacing.gapHorizontalMd,
                        Icon(
                          option.icon,
                          size: AppIconSize.md,
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ],
                      AppSpacing.gapHorizontalMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              option.title,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.onSurface,
                              ),
                            ),
                            if (option.subtitle != null) ...[
                              AppSpacing.gapVerticalXs,
                              Text(
                                option.subtitle!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// 単一選択ダイアログを表示するヘルパー関数
Future<T?> showAppSelectionDialog<T>(
  BuildContext context, {
  required String title,
  required List<SelectionOption<T>> options,
  T? selectedValue,
  bool barrierDismissible = true,
  bool useRootNavigator = false,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    useRootNavigator: useRootNavigator,
    builder: (context) => AppSelectionDialog<T>(
      title: title,
      options: options,
      selectedValue: selectedValue,
    ),
  );
}
