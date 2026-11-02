import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/config/feature_flags.dart';
import 'package:private_shelf/features/library/presentation/screens/internal_library_screen.dart';
import 'package:private_shelf/features/library/presentation/providers/library_fab_visibility_provider.dart';
import 'package:private_shelf/core/providers/tutorial_providers.dart';
import 'package:private_shelf/features/library/presentation/dialogs/import_picker_guide_dialog.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/tutorial/tutorial_catalog.dart';
import 'package:private_shelf/shared/widgets/tutorial/tutorial_overlay.dart';

/// ライブラリ画面のエントリーポイント。
/// 取り込み済みコピーのライブラリを表示する。
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  void _listenForLibraryTutorialReview(BuildContext context, WidgetRef ref) {
    ref.listen(tutorialReviewRequestProvider, (previous, next) {
      if (next == null) return;
      if (next.id != TutorialIds.firstHide &&
          next.id != TutorialIds.firstArchive &&
          next.id != TutorialIds.importPicker) {
        return;
      }
      final token = next.token;
      final id = next.id;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!context.mounted) return;
        if (ref.read(tutorialReviewRequestProvider)?.token != token) return;
        if (id == TutorialIds.importPicker) {
          await ImportPickerGuideDialog.showPreview(context);
        } else {
          final hasPasscode =
              ref.read(hasPasscodeProvider).value ?? false;
          final l10n = AppLocalizations.of(context)!;
          await TutorialOverlay.show(
            context,
            ref: ref,
            tutorialId: id,
            preview: true,
            steps: id == TutorialIds.firstHide
                ? hideTutorialSteps(l10n, hasPasscode: hasPasscode)
                : archiveTutorialSteps(l10n, hasPasscode: hasPasscode),
          );
        }
        if (ref.read(tutorialReviewRequestProvider)?.token == token) {
          ref.read(tutorialReviewRequestProvider.notifier).clear();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    const child = InternalLibraryScreen();

    final l10n = AppLocalizations.of(context)!;
    final review = ref.watch(tutorialReviewRequestProvider);
    final previewLibrary = review?.id == TutorialIds.library;
    _listenForLibraryTutorialReview(context, ref);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (!FeatureFlags.enableLibraryFabAutoHide) return false;

        if (notification is ScrollUpdateNotification) {
          final delta = notification.scrollDelta ?? 0;
          if (delta > 2.0) {
            // 下スクロール: 非表示
            ref.read(libraryFabVisibilityProvider.notifier).hide();
          } else if (delta < -2.0) {
            // 上スクロール: 表示
            ref.read(libraryFabVisibilityProvider.notifier).show();
          }
        }
        return false;
      },
      child: TutorialOverlay(
        enabled: FeatureFlags.enableTutorial || previewLibrary,
        preview: previewLibrary,
        onPreviewDismissed: () {
          ref.read(tutorialReviewRequestProvider.notifier).clear();
        },
        tutorialId: TutorialIds.library,
        steps: libraryTutorialSteps(l10n),
        child: child,
      ),
    );
  }
}
