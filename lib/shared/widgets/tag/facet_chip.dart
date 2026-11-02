import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:private_shelf/core/feedback/haptics_service.dart';

/// 分類（Facet）の選択・フィルタリングに特化した共通UIチップ
class FacetChip extends StatelessWidget {
  final String label;
  final Color? color;
  final int? count;
  final bool isSelected;
  final ValueChanged<bool>? onSelected;
  final VoidCallback? onTap;
  final bool showDot;

  const FacetChip({
    super.key,
    required this.label,
    this.color,
    this.count,
    this.isSelected = false,
    this.onSelected,
    this.onTap,
    this.showDot = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;
    final isEnabled = onSelected != null || onTap != null;
    final side = BorderSide(
      color: isSelected
          ? theme.colorScheme.primary
          : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: side,
    );
    final semanticsLabel = count == null ? label : '$label, $count';

    void handleSelected(bool selected) {
      unawaited(HapticsService.selection());
      if (onSelected != null) {
        onSelected!(selected);
      } else {
        onTap?.call();
      }
    }

    return Semantics(
      container: true,
      button: isEnabled,
      enabled: isEnabled,
      label: semanticsLabel,
      selected: isSelected,
      onTap: isEnabled ? () => handleSelected(!isSelected) : null,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const padding = EdgeInsets.symmetric(horizontal: 4, vertical: 2);
            const boundedLabelPadding = EdgeInsets.symmetric(horizontal: 8);
            const dotSlot = 28.0;
            final bounded = constraints.hasBoundedWidth;
            final labelWidth = bounded
                ? math.max(
                    0.0,
                    constraints.maxWidth -
                        shape.dimensions.horizontal -
                        padding.horizontal -
                        boundedLabelPadding.horizontal -
                        (showDot ? dotSlot : 0),
                  )
                : double.infinity;
            // Ink also reserves the shape border inside the available width.
            // RawChip measures height before subtracting its avatar/padding.
            // Cap the label itself so both measurements use the final width.
            final nameText = Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            );
            final chipLabel = ConstrainedBox(
              constraints: BoxConstraints(maxWidth: labelWidth),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    fit: FlexFit.loose,
                    // RawChip defaults to one line without wrapping. Reset
                    // that inherited limit only for a bounded label.
                    child: bounded
                        ? DefaultTextStyle(
                            style:
                                theme.chipTheme.labelStyle ??
                                theme.textTheme.labelLarge ??
                                const TextStyle(),
                            softWrap: true,
                            overflow: TextOverflow.visible,
                            child: nameText,
                          )
                        : nameText,
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.onPrimary.withValues(
                                alpha: 0.22,
                              )
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: FilterChip(
                selected: isSelected,
                showCheckmark: false,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                visualDensity: VisualDensity.standard,
                labelPadding: bounded ? boundedLabelPadding : null,
                avatarBoxConstraints: bounded && showDot
                    ? const BoxConstraints.tightFor(
                        width: dotSlot,
                        height: dotSlot,
                      )
                    : null,
                avatar: showDot
                    ? Center(
                        widthFactor: 1,
                        heightFactor: 1,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : effectiveColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
                label: chipLabel,
                backgroundColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.35),
                selectedColor: theme.colorScheme.primary,
                side: side,
                shape: shape,
                padding: padding,
                onSelected: isEnabled ? handleSelected : null,
              ),
            );
          },
        ),
      ),
    );
  }
}
