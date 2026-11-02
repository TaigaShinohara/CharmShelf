import 'package:flutter/material.dart';

import '../../../gen_l10n/app_localizations.dart';
import '../../../shared/widgets/onboarding/onboarding_page.dart';
import '../../../shared/widgets/onboarding/onboarding_view.dart';
import 'widgets/onboarding_collection_story.dart';
import 'widgets/onboarding_journey.dart';
import 'widgets/onboarding_preview.dart';

/// A short entry point. Reading the guide is optional and never marks it read.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({
    super.key,
    required this.onComplete,
    this.onTrySample,
    this.preview = false,
    this.afterWelcome = false,
  });

  final VoidCallback onComplete;
  final VoidCallback? onTrySample;
  final bool preview;
  // Retained for the existing initialization flow, without resetting its state.
  final bool afterWelcome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return OnboardingView(
      completionLabel: preview ? l10n.onboardingClose : l10n.onboardingStart,
      secondaryActionLabel: l10n.onboardingTrySample,
      onSecondaryAction: preview ? null : onTrySample,
      pages: [
        OnboardingPage(
          title: l10n.onboardingWelcomeTitle,
          description: l10n.onboardingWelcomeMessage,
          icon: Icons.linear_scale_rounded,
          descriptionBeforeContent: true,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const JourneyMotion(
                scene: 'welcome',
                active: true,
                child: OnboardingCollectionStory(),
              ),
              const SizedBox(height: 12),
              TextButton(
                key: const ValueKey('onboarding-guide'),
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (guideContext) => _OnboardingGuide(
                      onClose: () => Navigator.of(guideContext).pop(),
                    ),
                  ),
                ),
                child: Text(
                  l10n.onboardingGuideAction,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
      onComplete: onComplete,
    );
  }
}

class _OnboardingGuide extends StatefulWidget {
  const _OnboardingGuide({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_OnboardingGuide> createState() => _OnboardingGuideState();
}

class _OnboardingGuideState extends State<_OnboardingGuide> {
  int _catalog = 0;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.onboardingGuideTitle),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            key: const ValueKey('onboarding-guide-close'),
            tooltip: l10n.onboardingClose,
            onPressed: widget.onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: OnboardingView(
        onPageChanged: (index) => setState(() => _page = index),
        completionLabel: l10n.onboardingClose,
        onComplete: widget.onClose,
        pages: [
          OnboardingPage(
            title: l10n.onboardingCatalogTitle,
            description: l10n.onboardingCatalogMessage,
            icon: Icons.linear_scale_rounded,
            descriptionBeforeContent: true,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final choice in [
                      (
                        index: 0,
                        key: 'photos',
                        label: l10n.onboardingCatalogChoicePhotos,
                        icon: Icons.photo_outlined,
                      ),
                      (
                        index: 1,
                        key: 'music',
                        label: l10n.onboardingCatalogChoiceMusic,
                        icon: Icons.music_note_rounded,
                      ),
                    ])
                      ChoiceChip(
                        key: ValueKey('onboarding-catalog-${choice.key}'),
                        avatar: ExcludeSemantics(
                          child: Icon(choice.icon, size: 18),
                        ),
                        label: Text(choice.label),
                        selected: _catalog == choice.index,
                        onSelected: (_) =>
                            setState(() => _catalog = choice.index),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                JourneyMotion(
                  scene: 'catalog',
                  active: _page == 0,
                  child: OnboardingPreview(
                    child: CatalogExamplePreview(selectedIndex: _catalog),
                  ),
                ),
              ],
            ),
          ),
          OnboardingPage(
            title: l10n.onboardingTaggingTitle,
            description: l10n.onboardingTaggingMessage,
            icon: Icons.sell_outlined,
            descriptionBeforeContent: true,
            content: JourneyMotion(
              scene: 'charms',
              active: _page == 1,
              child: const JourneyCharmExample(),
            ),
          ),
          OnboardingPage(
            title: l10n.onboardingDataTitle,
            description: l10n.onboardingDataMessage,
            label: l10n.onboardingDataLimits,
            icon: Icons.phone_android_rounded,
            descriptionBeforeContent: true,
            content: JourneyMotion(
              scene: 'data',
              active: _page == 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  JourneyInfoCard(
                    icon: Icons.copy_outlined,
                    label: l10n.onboardingDataCopy,
                  ),
                  const SizedBox(height: 10),
                  JourneyInfoCard(
                    icon: Icons.folder_open_outlined,
                    label: l10n.onboardingDataReference,
                  ),
                  const SizedBox(height: 10),
                  JourneyInfoCard(
                    icon: Icons.save_alt_rounded,
                    label: l10n.onboardingDataBackup,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
