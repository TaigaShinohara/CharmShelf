import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../widgets.dart';

/// 共通ローディング表示ウィジェット
class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key, this.message, this.compact = false});

  final String? message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = message ?? l10n.commonLoading;

    if (compact) {
      return const Center(
        child: Padding(
          padding: AppSpacing.edgeInsetsMd,
          child: SizedBox(
            width: AppIconSize.lg,
            height: AppIconSize.lg,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    return Center(
      child: Semantics(
        container: true,
        liveRegion: true,
        label: label,
        value: message,
        child: ExcludeSemantics(
          child: Padding(
            padding: AppSpacing.edgeInsetsXl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                if (message != null) ...[
                  AppSpacing.gapVerticalMd,
                  AppText(
                    message!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// CustomScrollView 内で使用できる Sliver 版ローディングウィジェット
class SliverLoadingWidget extends StatelessWidget {
  const SliverLoadingWidget({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: LoadingWidget(message: message),
    );
  }
}
