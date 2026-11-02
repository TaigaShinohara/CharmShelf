import 'package:flutter/material.dart';

import '../../../../gen_l10n/app_localizations.dart';
import '../../../../shared/widgets/icon/catalogize_icon.dart';
import '../../../samples/domain/sample_catalog.dart';

/// Decorative, local-only examples: no media, repository or player dependency.
class OnboardingPreview extends StatelessWidget {
  const OnboardingPreview({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppLocalizations.of(context)!.onboardingPreviewLabel,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class ExampleShelf extends StatelessWidget {
  const ExampleShelf({
    super.key,
    required this.labels,
    this.animate = false,
    this.onArrivalComplete,
  });

  final List<String> labels;
  final bool animate;
  final VoidCallback? onArrivalComplete;

  @override
  Widget build(BuildContext context) {
    final shelf = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < labels.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: SizedBox.square(
                        dimension: 44,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child:
                              labels[index] ==
                                  AppLocalizations.of(
                                    context,
                                  )!.onboardingExampleMemory
                              ? _BundledCover(
                                  asset: _sample(
                                    context,
                                    SampleKind.photos,
                                  ).assets.first,
                                  fallback: Icons.photo_library_outlined,
                                )
                              : _PaperLines(
                                  personal:
                                      labels[index] ==
                                      AppLocalizations.of(
                                        context,
                                      )!.onboardingExamplePrivate,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(labels[index])),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
    if (!animate || MediaQuery.disableAnimationsOf(context)) return shelf;
    return TweenAnimationBuilder<double>(
      key: const ValueKey('onboarding-shelf-arrival'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      onEnd: onArrivalComplete,
      child: shelf,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

class CopyPreview extends StatelessWidget {
  const CopyPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        _CopyCard(
          label: l10n.onboardingExampleOriginal,
          icon: Icons.insert_drive_file_outlined,
        ),
        const Padding(
          padding: EdgeInsets.all(8),
          child: ExcludeSemantics(child: Icon(Icons.south_rounded)),
        ),
        _CopyCard(label: l10n.onboardingExampleCopy, icon: Icons.copy_outlined),
      ],
    );
  }
}

class _CopyCard extends StatelessWidget {
  const _CopyCard({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      ExcludeSemantics(child: Icon(icon, size: 32)),
      const SizedBox(width: 12),
      Expanded(child: Text(label)),
    ],
  );
}

SampleCatalog _sample(BuildContext context, SampleKind kind) =>
    SampleCatalog.forLocale(
      Localizations.localeOf(context).languageCode,
    ).firstWhere((sample) => sample.kind == kind);

/// A local-only group of individual files managed as one catalog.
/// Loading an example never creates a library record or audio session.
class CatalogExamplePreview extends StatelessWidget {
  const CatalogExamplePreview({
    super.key,
    required this.selectedIndex,
    this.label,
  });

  final int selectedIndex;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labels = [
      l10n.onboardingCatalogPhotoBook,
      l10n.onboardingCatalogMusicAlbum,
      l10n.onboardingCatalogIllustrationCollection,
      l10n.onboardingCatalogTextBook,
    ];
    final kind = [
      SampleKind.photos,
      SampleKind.music,
      SampleKind.art,
      SampleKind.text,
    ][selectedIndex];
    final assets = _sample(context, kind).assets;
    final icon = switch (kind) {
      SampleKind.photos => Icons.photo_outlined,
      SampleKind.music => Icons.music_note_rounded,
      SampleKind.art => Icons.palette_outlined,
      SampleKind.text => Icons.description_outlined,
    };
    final colors = Theme.of(context).colorScheme;
    final title = label ?? labels[selectedIndex];
    return Semantics(
      label: title,
      child: ExcludeSemantics(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CatalogizeIcon(size: 26, color: colors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        for (var index = 0; index < 3; index++) ...[
                          if (index > 0)
                            CatalogizeIcon(size: 18, color: colors.primary),
                          Expanded(
                            child: _ExampleFile(
                              icon: icon,
                              child: kind == SampleKind.text
                                  ? const _PaperLines()
                                  : _BundledCover(
                                      asset: assets[index % assets.length],
                                      fallback: icon,
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExampleFile extends StatelessWidget {
  const _ExampleFile({required this.icon, required this.child});

  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ColoredBox(
        color: colors.surfaceContainerLow,
        child: Column(
          children: [
            SizedBox(height: 66, width: double.infinity, child: child),
            Padding(
              padding: const EdgeInsets.all(5),
              child: Icon(icon, size: 16, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _BundledCover extends StatelessWidget {
  const _BundledCover({required this.asset, required this.fallback});

  final String asset;
  final IconData fallback;

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    fit: BoxFit.cover,
    cacheWidth: 480,
    excludeFromSemantics: true,
    errorBuilder: (context, error, stackTrace) => ColoredBox(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Center(child: Icon(fallback, size: 28)),
    ),
  );
}

class _PaperLines extends StatelessWidget {
  const _PaperLines({this.personal = false});
  final bool personal;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(7),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (personal)
            Icon(
              Icons.favorite_outline,
              size: 14,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          for (var i = 0; i < (personal ? 2 : 3); i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Container(
                height: 2,
                color: Theme.of(
                  context,
                ).colorScheme.onSecondaryContainer.withValues(alpha: .45),
              ),
            ),
        ],
      ),
    ),
  );
}
