import 'package:flutter/material.dart';

import '../../../../shared/widgets/icon/catalogize_icon.dart';
import '../../../../shared/widgets/icon/charm_icon.dart';

/// A decorative file group with attached charms, using the app's shared symbols.
/// Arrival motion belongs to the surrounding JourneyMotion so reduced-motion
/// settings and page navigation retain the existing behavior.
class OnboardingChainHero extends StatelessWidget {
  const OnboardingChainHero({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      key: const ValueKey('onboarding-chain-hero'),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(child: _HeroFile(Icons.photo_outlined)),
                      CatalogizeIcon(size: 20, color: colors.primary),
                      const Expanded(
                        child: _HeroFile(Icons.music_note_rounded),
                      ),
                      CatalogizeIcon(size: 20, color: colors.primary),
                      const Expanded(
                        child: _HeroFile(Icons.description_outlined),
                      ),
                    ],
                  ),
                  Container(width: 2, height: 14, color: colors.outlineVariant),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _HeroCharm(
                        color: colors.secondaryContainer,
                        foreground: colors.onSecondaryContainer,
                      ),
                      const SizedBox(width: 10),
                      _HeroCharm(
                        color: colors.tertiaryContainer,
                        foreground: colors.onTertiaryContainer,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroFile extends StatelessWidget {
  const _HeroFile(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Icon(icon, size: 28, color: colors.onSurfaceVariant),
    );
  }
}

class _HeroCharm extends StatelessWidget {
  const _HeroCharm({required this.color, required this.foreground});

  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: CharmIcon(size: 24, color: foreground),
    ),
  );
}
