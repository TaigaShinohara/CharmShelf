import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';

/// ボトムシートの最上部に表示するドラッグハンドル
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      height: 4,
      width: 32,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        borderRadius: AppRadius.radiusXs,
      ),
    );
  }
}
