import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import '../widgets.dart';
import '../feedback/app_menu_action_feedback.dart';
import 'sheet_handle.dart';

import '../../../core/feedback/feedback_providers.dart';

class ActionSheetItem<T> {
  const ActionSheetItem({
    required this.label,
    required this.value,
    this.icon,
    this.iconWidget,
    this.isDestructive = false,
    this.enabled = true,
    this.selected = false,
  });

  final String label;
  final T value;
  final IconData? icon;
  final Widget? iconWidget;
  final bool isDestructive;
  final bool enabled;
  final bool selected;
}

/// 複数選択肢を提示するボトムシート
class ActionBottomSheet<T> extends ConsumerWidget {
  const ActionBottomSheet({
    super.key,
    required this.items,
    this.title,
    this.cancelLabel,
    this.scrollController,
    this.enableSelectionFeedback = true,
  });

  final String? title;
  final String? cancelLabel;
  final List<ActionSheetItem<T>> items;
  final ScrollController? scrollController;
  final bool enableSelectionFeedback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: AppText(
                title!,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const Divider(height: 1),
          ],
          Flexible(
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final item in items)
                    _ActionBottomSheetItemTile<T>(
                      item: item,
                      enableSelectionFeedback: enableSelectionFeedback,
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: ListTile(
              enableFeedback: false,
              title: Center(child: AppText(cancelLabel ?? l10n.commonCancel)),
              onTap: () {
                ref.read(feedbackServiceProvider).lightImpact();
                Navigator.of(context).pop<T?>(null);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBottomSheetItemTile<T> extends ConsumerWidget {
  const _ActionBottomSheetItemTile({
    required this.item,
    required this.enableSelectionFeedback,
  });

  final ActionSheetItem<T> item;
  final bool enableSelectionFeedback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor = item.isDestructive
        ? scheme.error
        : (item.enabled ? null : scheme.onSurface.withValues(alpha: 0.38));
    final titleColor = item.isDestructive
        ? scheme.error
        : (item.enabled ? null : scheme.onSurface.withValues(alpha: 0.38));

    Widget buildTile(Widget? leading, VoidCallback? onTap) {
      return ListTile(
        enableFeedback: false,
        leading: leading,
        title: AppText(item.label, style: TextStyle(color: titleColor)),
        enabled: item.enabled,
        trailing: item.selected
            ? Icon(Icons.check, color: scheme.primary)
            : null,
        onTap: onTap,
      );
    }

    if (item.icon == null && item.iconWidget == null) {
      return buildTile(
        null,
        item.enabled
            ? () {
                ref.read(feedbackServiceProvider).lightImpact();
                Navigator.of(context).pop<T>(item.value);
              }
            : null,
      );
    }

    if (!enableSelectionFeedback) {
      return buildTile(
        item.iconWidget ?? Icon(item.icon, color: iconColor),
        item.enabled
            ? () {
                ref.read(feedbackServiceProvider).lightImpact();
                Navigator.of(context).pop<T>(item.value);
              }
            : null,
      );
    }

    return AppMenuActionFeedback(
      icon: item.icon,
      iconWidget: item.iconWidget,
      iconColor: iconColor,
      onPressed: () => ref.read(feedbackServiceProvider).lightImpact(),
      onFeedbackComplete: () => Navigator.of(context).pop<T>(item.value),
      builder: (context, animatedIcon, onPressed) =>
          buildTile(animatedIcon, item.enabled ? onPressed : null),
    );
  }
}

class _AdaptiveActionBottomSheet<T> extends StatefulWidget {
  const _AdaptiveActionBottomSheet({
    required this.title,
    required this.cancelLabel,
    required this.items,
    required this.enableSelectionFeedback,
  });

  final String? title;
  final String? cancelLabel;
  final List<ActionSheetItem<T>> items;
  final bool enableSelectionFeedback;

  @override
  State<_AdaptiveActionBottomSheet<T>> createState() =>
      _AdaptiveActionBottomSheetState<T>();
}

class _AdaptiveActionBottomSheetState<T>
    extends State<_AdaptiveActionBottomSheet<T>> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ActionBottomSheet<T>(
      title: widget.title,
      cancelLabel: widget.cancelLabel,
      items: widget.items,
      enableSelectionFeedback: widget.enableSelectionFeedback,
      scrollController: _scrollController,
    );
  }
}

/// ActionBottomSheet を表示して、選択された value を返します（キャンセルは null）。
Future<T?> showActionBottomSheet<T>(
  BuildContext context, {
  String? title,
  String? cancelLabel,
  required List<ActionSheetItem<T>> items,
  bool enableSelectionFeedback = true,
  double initialChildSize = 0.95,
  double minChildSize = 0.25,
  double maxChildSize = 0.95,
}) {
  assert(minChildSize >= 0 && minChildSize <= 1);
  assert(initialChildSize >= 0 && initialChildSize <= 1);
  assert(maxChildSize >= 0 && maxChildSize <= 1);
  assert(minChildSize <= maxChildSize);

  final maxHeightFactor = initialChildSize > maxChildSize
      ? initialChildSize
      : maxChildSize;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (context) {
      final mediaQuery = MediaQuery.of(context);
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: mediaQuery.size.height * maxHeightFactor,
        ),
        child: _AdaptiveActionBottomSheet<T>(
          title: title,
          cancelLabel: cancelLabel,
          items: items,
          enableSelectionFeedback: enableSelectionFeedback,
        ),
      );
    },
  );
}
