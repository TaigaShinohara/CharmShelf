import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

import '../../../core/error/app_error.dart';
import '../../../core/error/user_safe_error_message.dart';
import '../../../core/feedback/feedback_providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../widgets.dart';

/// 共通エラー表示ウィジェット
class ErrorStateWidget extends ConsumerWidget {
  const ErrorStateWidget({super.key, required this.error, this.onRetry});

  final AppError error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: AppSpacing.edgeInsetsXl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: AppIconSize.xxl,
              color: theme.colorScheme.error,
            ),
            AppSpacing.gapVerticalMd,
            AppText(
              userSafeErrorMessage(error, l10n),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (onRetry != null) ...[
              AppSpacing.gapVerticalLg,
              FilledButton.icon(
                onPressed: () {
                  ref.read(feedbackServiceProvider).lightImpact();
                  onRetry?.call();
                },
                icon: const Icon(Icons.refresh, size: AppIconSize.sm),
                label: AppText(l10n.commonRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// CustomScrollView 内で使用できる Sliver 版エラー表示ウィジェット
class SliverErrorStateWidget extends ConsumerWidget {
  const SliverErrorStateWidget({super.key, required this.error, this.onRetry});

  final AppError error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: ErrorStateWidget(error: error, onRetry: onRetry),
    );
  }
}
