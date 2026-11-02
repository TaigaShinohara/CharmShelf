import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:isar/isar.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:private_shelf/core/providers/isar_provider.dart';
import 'package:private_shelf/features/home/presentation/home_page.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/player_notifier.dart';
import 'package:private_shelf/features/library/presentation/screens/library_screen.dart';
import 'package:private_shelf/features/samples/presentation/sample_preview_screen.dart';
import 'package:private_shelf/features/onboarding/presentation/legacy_welcome_screen.dart';
import 'package:private_shelf/features/tab_navigation/presentation/main_tab_page.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/main.dart' as app;

import 'support/release_qa_audio_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('fresh QA install: welcome, sample preview, database, audio, home', (
    tester,
  ) async {
    // Run only in the isolated QA copy, never against an existing user library.
    expect(
      kDebugMode,
      isFalse,
      reason:
          'Run with flutter drive --profile; debug engine assets are '
          'stored in the private directory checked by fresh-start recovery.',
    );
    final info = await PackageInfo.fromPlatform();
    expect(
      RegExp(
        r'^com\.tsmusic\.privateshelf\.opensource\.performanceqa(?:[0-9]{1,8})?$',
      ).hasMatch(info.packageName),
      isTrue,
      reason: 'Only isolated QA packages may initialize this fixture library',
    );
    final testErrorHandler = FlutterError.onError;
    final platformErrorHandler =
        WidgetsBinding.instance.platformDispatcher.onError;
    addTearDown(() {
      FlutterError.onError = testErrorHandler;
      WidgetsBinding.instance.platformDispatcher.onError = platformErrorHandler;
    });
    app.main();
    // Let the test binding report failures rather than the app crash logger.
    FlutterError.onError = testErrorHandler;
    WidgetsBinding.instance.platformDispatcher.onError = platformErrorHandler;
    await _until(
      tester,
      () => find.byType(LegacyWelcomeScreen).evaluate().isNotEmpty,
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(LegacyWelcomeScreen)),
    )!;
    await _until(
      tester,
      () => find.text(l10n.legacyFirstUse).hitTestable().evaluate().isNotEmpty,
    );
    await tester.tap(find.text(l10n.legacyFirstUse));
    await _until(tester, () {
      if (find.text(l10n.freshStartConfirmTitle).evaluate().isNotEmpty) {
        throw TestFailure('Unexpected reset confirmation on fresh QA install');
      }
      if (find.text(l10n.freshStartFailure).evaluate().isNotEmpty) {
        throw TestFailure('Fresh-start storage reset failed');
      }
      return find
          .byKey(const ValueKey('onboarding-sample'))
          .hitTestable()
          .evaluate()
          .isNotEmpty;
    });
    await tester.tap(find.byKey(const ValueKey('onboarding-sample')));
    await _until(tester, () {
      return find.byType(SamplePreviewScreen).evaluate().isNotEmpty &&
          find.byType(CircularProgressIndicator).evaluate().isEmpty &&
          tester
              .widgetList<RawImage>(find.byType(RawImage))
              .any((image) => image.image != null);
    });
    expect(find.text(l10n.samplePreviewLoadError), findsNothing);
    final previewBack = find
        .descendant(
          of: find.byType(SamplePreviewScreen),
          matching: find.byType(BackButton),
        )
        .hitTestable();
    await _until(tester, () => previewBack.evaluate().isNotEmpty);
    await tester.tap(previewBack);
    await _until(tester, () {
      return find.byType(SamplePreviewScreen).evaluate().isEmpty &&
          find.byType(MainTabPage).evaluate().isNotEmpty &&
          find.byType(LibraryScreen).hitTestable().evaluate().isNotEmpty;
    });
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MainTabPage)),
    );
    final db = await _withFrames(tester, container.read(isarProvider.future));
    final initialItems = await _withFrames(
      tester,
      db.mediaItems.where().findAll(),
    );
    expect(
      initialItems,
      isEmpty,
      reason: 'Sample preview must not populate the library',
    );
    final track = await _withFrames(
      tester,
      importReleaseQaAudioFixture(container),
    );
    final items = await _withFrames(tester, db.mediaItems.where().findAll());
    expect(items, hasLength(1));
    expect(items.single.path, track.path);
    final player = container.read(playerNotifierProvider.notifier);
    try {
      await _withFrames(
        tester,
        player.play(track, isExpanded: false, showMiniPlayer: false),
      );
      await _until(tester, () {
        final state = container.read(playerNotifierProvider);
        return state.audioPlayer != null &&
            state.audioPlayer!.position > const Duration(seconds: 1);
      });
      final state = container.read(playerNotifierProvider);
      expect(state.error, isNull);
      expect(state.audioPlayer!.duration!.inSeconds, greaterThan(60));
      await _withFrames(tester, player.pause());
      expect(container.read(playerNotifierProvider).isPlaying, isFalse);
    } finally {
      await _withFrames(tester, player.stop());
    }
    await tester.tap(find.byKey(const ValueKey('bottom-navigation-tab-1')));
    await _until(tester, () => find.byType(HomePage).evaluate().isNotEmpty);
    // Import actions now open native pickers directly. Verify the entry
    // controls here; native picker selection/cancellation is separate device QA.
    final addFiles = find.byKey(const ValueKey('home-add-files'));
    final addFolders = find.byKey(const ValueKey('home-add-folders'));
    await _until(tester, () => addFiles.evaluate().isNotEmpty);
    await tester.ensureVisible(addFiles);
    await _until(tester, () => addFiles.hitTestable().evaluate().isNotEmpty);
    expect(addFolders, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bottom-navigation-tab-0')));
    await _until(
      tester,
      () => find.byType(LibraryScreen).hitTestable().evaluate().isNotEmpty,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 300));
    if (ready()) return;
  }
  throw TestFailure('QA operation did not finish within 60 seconds');
}

Future<T> _withFrames<T>(WidgetTester tester, Future<T> operation) async {
  var finished = false;
  T? value;
  Object? error;
  operation.then(
    (result) {
      value = result;
      finished = true;
    },
    onError: (Object exception) {
      error = exception;
      finished = true;
    },
  );
  await _until(tester, () => finished);
  if (error != null) throw error!;
  return value as T;
}
