import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/snackbar_service.dart';
import '../../../core/providers/tab_navigation_provider.dart';
import '../../../core/providers/tutorial_providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/tab_navigator.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../../../shared/widgets/tutorial/tutorial_catalog.dart';
import '../../../shared/widgets/settings/settings_section.dart';
import '../../../shared/widgets/settings/settings_tile.dart';
import '../../../shared/widgets/widgets.dart';
import '../../onboarding/presentation/onboarding_screen.dart';

class TutorialListPage extends ConsumerWidget {
  const TutorialListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          PremiumSliverAppBar(
            titleText: l10n.settingsTutorialSection,
            inlineTitle: true,
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.sm,
                ),
                child: AppText(
                  l10n.settingsTutorialListDescription,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              SettingsSection(
                title: l10n.settingsTutorialListTitle,
                icon: Icons.school_outlined,
                children: [
                  SettingsTile(
                    icon: Icons.auto_awesome_outlined,
                    title: l10n.tutorialOnboardingTitle,
                    subtitle: l10n.tutorialSceneOnboarding,
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => _showOnboarding(context),
                  ),
                  SettingsTile(
                    icon: Icons.library_books_outlined,
                    title: l10n.tutorialLibraryTitle,
                    subtitle: l10n.tutorialSceneLibrary,
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => _reviewOnScreen(
                      context,
                      ref,
                      TutorialIds.library,
                      home: false,
                    ),
                  ),
                  SettingsTile(
                    icon: Icons.home_outlined,
                    title: l10n.tutorialHomeTitle,
                    subtitle: l10n.tutorialSceneHome,
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => _reviewOnScreen(
                      context,
                      ref,
                      TutorialIds.home,
                      home: true,
                    ),
                  ),
                  SettingsTile(
                    icon: Icons.visibility_off_outlined,
                    title: l10n.tutorialHiddenTitle,
                    subtitle: l10n.tutorialSceneAfterHide,
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => _reviewOnScreen(
                      context,
                      ref,
                      TutorialIds.firstHide,
                      home: false,
                    ),
                  ),
                  SettingsTile(
                    icon: Icons.archive_outlined,
                    title: l10n.tutorialArchiveTitle,
                    subtitle: l10n.tutorialSceneAfterArchive,
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => _reviewOnScreen(
                      context,
                      ref,
                      TutorialIds.firstArchive,
                      home: false,
                    ),
                  ),
                  SettingsTile(
                    icon: Icons.add_to_photos_outlined,
                    title: l10n.tutorialImportPickerTitle,
                    subtitle: l10n.tutorialSceneImport,
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => _reviewOnScreen(
                      context,
                      ref,
                      TutorialIds.importPicker,
                      home: false,
                    ),
                  ),
                ],
              ),
              SettingsSection(
                title: l10n.tutorialGuidebookSectionTitle,
                icon: Icons.menu_book_outlined,
                children: [
                  SettingsTile(
                    icon: Icons.auto_stories_outlined,
                    title: l10n.tutorialWelcomeGuideTitle,
                    subtitle: l10n.tutorialWelcomeGuideSubtitle,
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => ref
                        .read(currentTabIndexProvider.notifier)
                        .goToLibrary(),
                  ),
                ],
              ),
              SettingsSection(
                title: l10n.settingsTutorialManagementTitle,
                icon: Icons.restart_alt,
                children: [
                  SettingsTile(
                    icon: Icons.restart_alt,
                    title: l10n.settingsTutorialReset,
                    subtitle: l10n.settingsTutorialResetSubtitle,
                    onTap: () => _confirmTutorialReset(context, ref),
                  ),
                ],
              ),
            ]),
          ),
        ],
      ),
    );
  }

  void _reviewOnScreen(
    BuildContext context,
    WidgetRef ref,
    String tutorialId, {
    required bool home,
  }) {
    TabNavigator.popUntilFirst(context);
    final tabs = ref.read(currentTabIndexProvider.notifier);
    if (home) {
      tabs.goToHome();
    } else {
      tabs.goToLibrary();
    }
    ref.read(tutorialReviewRequestProvider.notifier).request(tutorialId);
  }

  Future<void> _showOnboarding(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (routeContext) => OnboardingScreen(
          preview: true,
          onComplete: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
  }

  Future<void> _confirmTutorialReset(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.settingsTutorialResetConfirmTitle,
      message: l10n.settingsTutorialResetConfirmMessage,
      confirmLabel: l10n.commonExecute,
      cancelLabel: l10n.commonCancel,
    );
    if (!confirmed || !context.mounted) return;

    await ref.read(tutorialStateProvider.notifier).resetAll();
    if (!context.mounted) return;
    ref
        .read(snackBarServiceProvider)
        .success(context: context, message: l10n.settingsTutorialResetDone);
  }
}
