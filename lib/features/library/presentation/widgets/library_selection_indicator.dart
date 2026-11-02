import 'package:flutter/material.dart';

/// ライブラリのリスト／グリッドで共通利用する丸型の選択マーク。
class LibrarySelectionIndicator extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onPressed;

  const LibrarySelectionIndicator({
    super.key,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox.square(
      dimension: 48,
      child: Center(
        child: Transform.scale(
          scale: 1.3,
          child: Checkbox(
            value: isSelected,
            shape: const CircleBorder(),
            side: BorderSide(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
              width: 1.8,
            ),
            fillColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return colorScheme.primary;
              }
              return colorScheme.surface.withValues(alpha: 0.92);
            }),
            checkColor: colorScheme.onPrimary,
            onChanged: (_) => onPressed(),
          ),
        ),
      ),
    );
  }
}
