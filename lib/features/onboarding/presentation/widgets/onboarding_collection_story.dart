import 'package:flutter/material.dart';

import '../../../../gen_l10n/app_localizations.dart';
import '../../../../shared/widgets/icon/charm_icon.dart';
import '../../../samples/domain/sample_catalog.dart';

/// The same local photos, first collected and then given a cover and charms.
/// This illustration never creates library items or starts a media session.
class OnboardingCollectionStory extends StatelessWidget {
  const OnboardingCollectionStory({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final photos = SampleCatalog.forLocale(
      Localizations.localeOf(context).languageCode,
    ).firstWhere((sample) => sample.kind == SampleKind.photos).assets;

    return Column(
      key: const ValueKey('onboarding-collection-story'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StoryStep(
          key: const ValueKey('onboarding-collect-step'),
          label: l10n.onboardingCollectLabel,
          message: l10n.onboardingCollectMessage,
          child: _PhotoFolder(photos: photos),
        ),
        const SizedBox(height: 16),
        _StoryStep(
          key: const ValueKey('onboarding-personalize-step'),
          label: l10n.onboardingPersonalizeLabel,
          message: l10n.onboardingPersonalizeMessage,
          child: _PersonalizedCatalog(photos: photos),
        ),
      ],
    );
  }
}

class _StoryStep extends StatelessWidget {
  const _StoryStep({
    super.key,
    required this.label,
    required this.message,
    required this.child,
  });

  final String label;
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(message, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _PhotoFolder extends StatelessWidget {
  const _PhotoFolder({required this.photos});

  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Column(
        key: const ValueKey('onboarding-collection-folder'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 56,
              height: 7,
              margin: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
                border: Border.all(color: colors.outlineVariant),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Row(
              children: [
                for (var index = 0; index < photos.length; index++) ...[
                  if (index > 0) const SizedBox(width: 6),
                  Expanded(
                    child: _StoryPhoto(asset: photos[index], height: 52),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalizedCatalog extends StatelessWidget {
  const _PersonalizedCatalog({required this.photos});

  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
    final charms = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _StoryCharm(
          label: l10n.onboardingCharmTravel,
          background: colors.secondaryContainer,
          foreground: colors.onSecondaryContainer,
        ),
        _StoryCharm(
          label: l10n.onboardingCharmLandscape,
          background: colors.tertiaryContainer,
          foreground: colors.onTertiaryContainer,
        ),
      ],
    );
    final catalogContent = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: _StoryPhoto(asset: photos.first, height: 104),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.onboardingExampleMemory,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (var index = 0; index < photos.length; index++) ...[
                    if (index > 0) const SizedBox(width: 5),
                    SizedBox(
                      width: 26,
                      child: _StoryPhoto(asset: photos[index], height: 24),
                    ),
                  ],
                ],
              ),
              if (!largeText) ...[const SizedBox(height: 8), charms],
            ],
          ),
        ),
      ],
    );
    return Container(
      key: const ValueKey('onboarding-personalized-catalog'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withValues(alpha: .3)),
      ),
      child: largeText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [catalogContent, const SizedBox(height: 8), charms],
            )
          : catalogContent,
    );
  }
}

class _StoryCharm extends StatelessWidget {
  const _StoryCharm({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: CharmIcon(size: 14, color: foreground)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    ),
  );
}

class _StoryPhoto extends StatelessWidget {
  const _StoryPhoto({required this.asset, required this.height});

  final String asset;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: SizedBox(
          height: height,
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            cacheWidth: 320,
            errorBuilder: (context, error, stackTrace) => ColoredBox(
              color: colors.surfaceContainerLow,
              child: Center(
                child: Icon(
                  Icons.photo_outlined,
                  size: height < 32 ? 16 : 24,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
