import 'package:flutter/material.dart';

import '../../../../gen_l10n/app_localizations.dart';
import '../../../../shared/widgets/icon/catalogize_icon.dart';
import '../../../../shared/widgets/icon/charm_icon.dart';
import 'onboarding_preview.dart';

bool _reduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    MediaQuery.accessibleNavigationOf(context);

/// One finite arrival per visible scene. Navigation never waits for this.
class JourneyMotion extends StatelessWidget {
  const JourneyMotion({
    super.key,
    required this.scene,
    required this.active,
    required this.child,
  });

  final String scene;
  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!active || _reduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey('onboarding-motion-$scene'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, 12 * (1 - value)),
        child: child,
      ),
    );
  }
}

/// Decorative cards and circles echo the app's catalog/charm language.
/// Meaning is conveyed by the page text, rather than decorative icon names.
class JourneyHero extends StatelessWidget {
  const JourneyHero({
    super.key,
    required this.scene,
    required this.active,
    required this.icon,
    required this.satellites,
    this.compact = false,
  });

  final String scene;
  final bool active;
  final IconData icon;
  final List<IconData> satellites;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
    final height = compact || largeText ? 112.0 : 180.0;
    return JourneyMotion(
      scene: scene,
      active: active,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: Center(
            child: SizedBox(
              width: 260,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: height,
                    height: height,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          colors.primaryContainer,
                          colors.primaryContainer.withValues(alpha: .12),
                        ],
                      ),
                    ),
                  ),
                  Transform.rotate(
                    angle: -.08,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: .2),
                        ),
                      ),
                      child: Icon(
                        icon,
                        size: 44,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                  for (var i = 0; i < satellites.length; i++)
                    Align(
                      alignment: [
                        const Alignment(-.85, -.6),
                        const Alignment(.85, -.35),
                        const Alignment(.55, .85),
                      ][i],
                      child: Transform.rotate(
                        angle: i.isEven ? -.12 : .12,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: i.isEven
                                ? colors.tertiaryContainer
                                : colors.secondaryContainer,
                            borderRadius: BorderRadius.circular(
                              i == 1 ? 22 : 12,
                            ),
                            border: Border.all(color: colors.outlineVariant),
                          ),
                          child: Icon(
                            satellites[i],
                            size: 24,
                            color: i.isEven
                                ? colors.onTertiaryContainer
                                : colors.onSecondaryContainer,
                          ),
                        ),
                      ),
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

class JourneyInfoCard extends StatelessWidget {
  const JourneyInfoCard({
    super.key,
    required this.icon,
    required this.label,
    this.iconWidget,
    this.color,
    this.foreground,
  });

  final IconData icon;
  final String label;
  final Widget? iconWidget;
  final Color? color;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? colors.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ExcludeSemantics(
              child: IconTheme.merge(
                data: IconThemeData(
                  size: 28,
                  color: foreground ?? colors.onPrimaryContainer,
                ),
                child: iconWidget ?? Icon(icon),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: foreground ?? colors.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class JourneyLabel extends StatelessWidget {
  const JourneyLabel({
    super.key,
    required this.label,
    this.secondary = false,
    this.charm = false,
  });

  final String label;
  final bool secondary;
  final bool charm;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: secondary ? colors.tertiaryContainer : colors.secondaryContainer,
        borderRadius: BorderRadius.circular(charm ? 20 : 14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (charm) ...[
              ExcludeSemantics(
                child: CharmIcon(
                  size: 18,
                  color: secondary
                      ? colors.onTertiaryContainer
                      : colors.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: secondary
                      ? colors.onTertiaryContainer
                      : colors.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A static illustration of charms attached to the same catalog.
class JourneyCharmExample extends StatelessWidget {
  const JourneyCharmExample({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return OnboardingPreview(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CatalogExamplePreview(
            selectedIndex: 0,
            label: l10n.onboardingExampleMemory,
          ),
          Center(
            child: Container(
              width: 2,
              height: 14,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              JourneyLabel(label: l10n.onboardingCharmTravel, charm: true),
              JourneyLabel(
                label: l10n.onboardingCharmLandscape,
                secondary: true,
                charm: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class JourneySearchExample extends StatelessWidget {
  const JourneySearchExample({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => OnboardingPreview(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JourneyInfoCard(
          icon: Icons.search,
          iconWidget: const CharmIcon.search(),
          label: label,
        ),
        const Padding(
          padding: EdgeInsets.all(10),
          child: ExcludeSemantics(child: Icon(Icons.south_rounded)),
        ),
        JourneyInfoCard(
          icon: Icons.photo_library_outlined,
          iconWidget: const CatalogizeIcon(),
          label: AppLocalizations.of(context)!.onboardingExampleMemory,
          color: Theme.of(context).colorScheme.tertiaryContainer,
          foreground: Theme.of(context).colorScheme.onTertiaryContainer,
        ),
      ],
    ),
  );
}

class JourneyNeedChoice extends StatelessWidget {
  const JourneyNeedChoice({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? colors.primaryContainer : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: _reduceMotion(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? colors.primary : colors.outlineVariant,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    icon,
                    color: selected
                        ? colors.onPrimaryContainer
                        : colors.onSurface,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: selected
                          ? colors.onPrimaryContainer
                          : colors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ExcludeSemantics(
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
