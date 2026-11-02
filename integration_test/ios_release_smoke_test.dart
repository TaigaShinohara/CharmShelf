import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kProfileMode, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:integration_test/common.dart' show Failure;
import 'package:isar/isar.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:private_shelf/core/providers/isar_provider.dart';
import 'package:private_shelf/features/home/presentation/home_page.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/player_notifier.dart';
import 'package:private_shelf/features/library/presentation/screens/library_screen.dart';
import 'package:private_shelf/features/samples/presentation/sample_preview_screen.dart';
import 'package:private_shelf/features/splash/presentation/screens/app_splash_screen.dart';
import 'package:private_shelf/features/tab_navigation/presentation/main_tab_page.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/main.dart' as app;

import 'support/release_qa_audio_fixture.dart';

void main() {
  _QaArtifactStore? artifacts;
  late final Future<_QaArtifactStore?> startup;
  late final Future<void> completedArtifacts;
  Timer? overallTimer;
  final registeredAt = DateTime.now();
  // test_api executes tearDownAll callbacks in reverse registration order.
  // Register this before creating the binding, whose teardown completes
  // allTestsPassed, so saving results never waits on a later teardown.
  tearDownAll(() async => completedArtifacts);
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  completedArtifacts = binding.allTestsPassed.future.then((passed) async {
    overallTimer?.cancel();
    final store = await startup;
    if (store == null) {
      return; // No writes when the platform/bundle gate failed.
    }
    final report = binding.reportData ??= <String, dynamic>{};
    report['completed'] = true;
    final harnessErrors = report['harnessErrors'] as List<String>?;
    report['allTestsPassed'] = passed && (harnessErrors?.isEmpty ?? true);
    report['completedAtUtc'] = DateTime.now().toUtc().toIso8601String();
    report['failureDetails'] = <Map<String, dynamic>>[
      for (final failure in binding.failureMethodsDetails)
        <String, dynamic>{
          'methodName': failure.methodName,
          'details': failure.details,
        },
    ];
    await _phase(binding, store, 'completed');
  });
  // Start native package/path lookup now, independently of the first test
  // frame. Registration below stays synchronous for test_compat's collector.
  startup = _prepareArtifacts(binding).then<_QaArtifactStore?>(
    (store) {
      artifacts = store;
      return store;
    },
    onError: (Object error, StackTrace stack) {
      _recordHarnessFailure(binding, 'startup', error, stack);
      return null; // The test body also fails when it consumes this result.
    },
  );
  overallTimer = Timer(_overallTimeout, () {
    if (binding.allTestsPassed.isCompleted) {
      return;
    }
    _recordHarnessFailure(
      binding,
      'overall-timeout',
      TestFailure('iOS QA did not finish within $_overallTimeout'),
      StackTrace.current,
    );
    final store = artifacts;
    if (store != null) {
      unawaited(
        _phase(binding, store, 'overall-timeout').catchError((
          Object error,
          StackTrace stack,
        ) {
          _recordHarnessFailure(binding, 'timeout-diagnostics', error, stack);
        }),
      );
    }
  });
  testWidgets(
    _smokeTestName,
    (tester) async {
      try {
        // Startup rejects other platforms/bundles before app initialization can
        // create or migrate data. A null result is an explicitly reported error.
        final store = await startup;
        if (store == null) {
          throw TestFailure(
            'iOS QA startup failed; see harnessErrors or console',
          );
        }
        await _phase(binding, store, 'body-started');
        final testErrorHandler = FlutterError.onError;
        final platformErrorHandler =
            WidgetsBinding.instance.platformDispatcher.onError;
        addTearDown(() {
          FlutterError.onError = testErrorHandler;
          WidgetsBinding.instance.platformDispatcher.onError =
              platformErrorHandler;
        });
        try {
          app.main();
        } finally {
          // Keep failures visible even if app initialization throws immediately.
          FlutterError.onError = testErrorHandler;
          WidgetsBinding.instance.platformDispatcher.onError =
              platformErrorHandler;
        }
        await _phase(binding, store, 'app-main-called');
        await _until(
          tester,
          () => binding.lifecycleState == AppLifecycleState.resumed,
        );
        await _withFrames(tester, binding.waitUntilFirstFrameRasterized);
        await _until(
          tester,
          () => find.byType(AppSplashScreen).evaluate().isEmpty,
        );
        await _phase(binding, store, 'foreground-ready');

        final sampleAction = find.byKey(const ValueKey('onboarding-sample'));
        await _until(
          tester,
          () => sampleAction.hitTestable().evaluate().isNotEmpty,
        );
        await _phase(binding, store, 'onboarding-ready');
        await tester.tap(sampleAction);
        await _until(
          tester,
          () => find.byType(SamplePreviewScreen).evaluate().isNotEmpty,
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(SamplePreviewScreen)),
        )!;
        await _until(tester, () {
          return find.byType(CircularProgressIndicator).evaluate().isEmpty &&
              tester
                  .widgetList<RawImage>(find.byType(RawImage))
                  .any((image) => image.image != null);
        });
        expect(find.text(l10n.samplePreviewLoadError), findsNothing);
        await _screenshot(binding, tester, store, 'ios-sample-preview');
        final previewBack = find
            .descendant(
              of: find.byType(SamplePreviewScreen),
              matching: find.byType(BackButton),
            )
            .hitTestable();
        await _until(tester, () => previewBack.evaluate().isNotEmpty);
        expect(previewBack, findsOneWidget);
        await _phase(binding, store, 'sample-preview-back-started');
        await tester.tap(previewBack);
        await _until(tester, () {
          return find.byType(SamplePreviewScreen).evaluate().isEmpty &&
              find.byType(MainTabPage).evaluate().isNotEmpty &&
              find.byType(LibraryScreen).hitTestable().evaluate().isNotEmpty;
        });
        expect(find.byType(SamplePreviewScreen), findsNothing);
        await _phase(binding, store, 'library-ready');

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MainTabPage)),
        );
        final db = await _withFrames(
          tester,
          container.read(isarProvider.future),
        );
        final initialItems = await _withFrames(
          tester,
          db.mediaItems.where().findAll(),
        );
        expect(
          initialItems,
          isEmpty,
          reason: 'Sample preview must not populate the library',
        );
        binding.reportData!['initialItemCount'] = initialItems.length;
        final track = await _withFrames(
          tester,
          importReleaseQaAudioFixture(container),
        );
        final items = await _withFrames(
          tester,
          db.mediaItems.where().findAll(),
        );
        expect(items, hasLength(1));
        expect(items.single.path, track.path);
        binding.reportData!['audioFixtureImported'] = true;
        binding.reportData!['itemCount'] = items.length;
        binding.reportData!['sampleTrackPath'] = track.path;
        await _phase(binding, store, 'database-verified');
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
          expect(state.audioPlayer!.duration, isNotNull);
          expect(state.audioPlayer!.duration!.inSeconds, greaterThan(60));
          binding.reportData!['audioDurationMs'] =
              state.audioPlayer!.duration!.inMilliseconds;
          binding.reportData!['audioPositionMs'] =
              state.audioPlayer!.position.inMilliseconds;
          await _phase(binding, store, 'audio-progress-verified');
          await _withFrames(tester, player.pause());
          expect(container.read(playerNotifierProvider).isPlaying, isFalse);
          binding.reportData!['pauseVerified'] = true;
          await _phase(binding, store, 'audio-pause-verified');
        } finally {
          await _withFrames(tester, player.stop());
        }
        await _screenshot(binding, tester, store, 'ios-library');

        final homeTab = find.byKey(const ValueKey('bottom-navigation-tab-1'));
        await _until(tester, () => homeTab.hitTestable().evaluate().isNotEmpty);
        await tester.tap(homeTab);
        await _until(tester, () {
          return find.byType(LibraryScreen).evaluate().isEmpty &&
              find.byType(HomePage).hitTestable().evaluate().isNotEmpty;
        });
        await _screenshot(binding, tester, store, 'ios-home');
        final libraryTab = find.byKey(
          const ValueKey('bottom-navigation-tab-0'),
        );
        await _until(
          tester,
          () => libraryTab.hitTestable().evaluate().isNotEmpty,
        );
        await tester.tap(libraryTab);
        await _until(tester, () {
          return find.byType(HomePage).evaluate().isEmpty &&
              find.byType(LibraryScreen).hitTestable().evaluate().isNotEmpty;
        });
        expect(find.byType(HomePage), findsNothing);
        expect(tester.takeException(), isNull);
        binding.reportData!['returnedToLibrary'] = true;
        if (DateTime.now().difference(registeredAt) >= _overallTimeout) {
          throw TestFailure('iOS QA exceeded its overall deadline');
        }
        await _phase(binding, store, 'body-finished');
      } catch (error, stack) {
        _recordHarnessFailure(binding, 'test-body', error, stack);
        rethrow;
      }
    },
    // The watchdog records a binding Failure first; the test runner then exits
    // a stalled pre-body pump instead of keeping its default Timeout.none.
    timeout: Timeout(_overallTimeout + const Duration(seconds: 5)),
  );
}

const _smokeTestName =
    'fresh iOS QA install: sample preview, database, native audio, tabs';
const _overallTimeout = Duration(minutes: 5);

Future<_QaArtifactStore> _prepareArtifacts(
  IntegrationTestWidgetsFlutterBinding binding,
) async {
  if (!Platform.isIOS) {
    throw StateError('Refusing iOS QA startup on another platform');
  }
  final info = await PackageInfo.fromPlatform().timeout(
    const Duration(seconds: 30),
  );
  if (!_allowedQaPackages.contains(info.packageName)) {
    throw StateError('Refusing artifact writes for bundle ${info.packageName}');
  }
  const sourceHash = String.fromEnvironment('TAGSHELF_IOS_QA_SOURCE_HASH');
  if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sourceHash)) {
    throw StateError('A hex64 TAGSHELF_IOS_QA_SOURCE_HASH is required');
  }
  binding.reportData = <String, dynamic>{
    'packageName': info.packageName,
    'platform': Platform.operatingSystem,
    'buildNumber': info.buildNumber,
    'sourceHash': sourceHash,
    'buildMode': kReleaseMode
        ? 'release'
        : kProfileMode
        ? 'profile'
        : 'debug',
    'startedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'artifactDirectory': 'Library/Application Support/release-qa',
    'completed': false,
    'allTestsPassed': false,
  };
  // All gates precede path lookup and writes to the dedicated QA container.
  final store = await _QaArtifactStore.create(
    info.packageName,
  ).timeout(const Duration(seconds: 30));
  await _phase(binding, store, 'registered');
  return store;
}

void _recordHarnessFailure(
  IntegrationTestWidgetsFlutterBinding binding,
  String phase,
  Object error,
  StackTrace stack,
) {
  final details = '$phase: $error\n$stack';
  binding.results[_smokeTestName] = Failure(_smokeTestName, details);
  // reportData is created only after the bundle/hash gate. Keep ungated
  // failures visible in the console/results without creating device reports.
  final report = binding.reportData;
  if (report != null) {
    final errors = report['harnessErrors'] ??= <String>[];
    (errors as List<String>).add(details);
  }
  debugPrint('[tagshelf-ios-qa] $details');
}

Future<void> _phase(
  IntegrationTestWidgetsFlutterBinding binding,
  _QaArtifactStore store,
  String phase,
) async {
  final report = binding.reportData!;
  report['phase'] = phase;
  report['lifecycleState'] = binding.lifecycleState?.name;
  report['framesEnabled'] = binding.framesEnabled;
  final history = report['phaseHistory'] ??= <Map<String, dynamic>>[];
  (history as List<Map<String, dynamic>>).add(<String, dynamic>{
    'phase': phase,
    'atUtc': DateTime.now().toUtc().toIso8601String(),
    'lifecycleState': binding.lifecycleState?.name,
    'framesEnabled': binding.framesEnabled,
  });
  debugPrint('[tagshelf-ios-qa] $phase (${binding.lifecycleState?.name})');
  await store.writeDiagnostics(report).timeout(const Duration(seconds: 10));
}

Future<void> _screenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  _QaArtifactStore artifacts,
  String name,
) async {
  await _until(
    tester,
    () => binding.lifecycleState == AppLifecycleState.resumed,
  );
  await _withFrames(tester, binding.waitUntilFirstFrameRasterized);
  await tester
      .pump(const Duration(milliseconds: 500))
      .timeout(const Duration(seconds: 5));
  final bytes = await _withFrames(tester, binding.takeScreenshot(name));
  expect(binding.lifecycleState, AppLifecycleState.resumed);
  expect(bytes, isNotEmpty);
  await artifacts
      .writeScreenshot(name, bytes)
      .timeout(const Duration(seconds: 10));
  await _phase(binding, artifacts, 'screenshot-$name');
}

const _allowedQaPackages = <String>{
  'org.charmshelf.opensource.releaseqa',
  'org.charmshelf.opensource.releaseqa2',
  'org.charmshelf.opensource.releaseqa3',
  'org.charmshelf.opensource.releaseqa4',
  'org.charmshelf.opensource.releaseqa5',
  'org.charmshelf.opensource.releaseqa6',
};

class _QaArtifactStore {
  _QaArtifactStore(this.directory);

  final Directory directory;
  final _screenshotFiles = <String, Map<String, dynamic>>{};

  static Future<_QaArtifactStore> create(String packageName) async {
    if (!Platform.isIOS || !_allowedQaPackages.contains(packageName)) {
      throw StateError('Refusing artifact writes outside the iOS QA app');
    }
    // Keep diagnostics outside Documents, which app startup migrates into
    // PrivateShelf before initializing the library.
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/release-qa');
    await directory.create(recursive: true);
    return _QaArtifactStore(directory);
  }

  Future<void> writeScreenshot(String name, List<int> bytes) async {
    const pngHeader = <int>[137, 80, 78, 71, 13, 10, 26, 10];
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(name) ||
        bytes.length < pngHeader.length ||
        !List.generate(
          pngHeader.length,
          (i) => bytes[i] == pngHeader[i],
        ).every((matches) => matches)) {
      throw StateError('Invalid QA screenshot name or PNG bytes');
    }
    final file = File('${directory.path}/$name.png');
    final pending = File('${file.path}.pending');
    await pending.writeAsBytes(bytes, flush: true);
    await pending.rename(file.path);
    _screenshotFiles[name] = <String, dynamic>{
      'name': name,
      'fileName': '$name.png',
      'byteLength': bytes.length,
      'sha256': sha256.convert(bytes).toString(),
    };
  }

  Future<void> writeDiagnostics(Map<String, dynamic> data) async {
    final report = <String, dynamic>{...data};
    // integration_test retains raw PNG bytes for its optional host driver.
    // Device diagnostics retain names only; PNGs are separate flushed files.
    final screenshots = report.remove('screenshots') as List<dynamic>?;
    report['screenshotNames'] =
        screenshots
            ?.map((dynamic shot) => (shot as Map)['screenshotName'])
            .toList() ??
        <String>[];
    report['screenshotFiles'] = _screenshotFiles.values.toList();
    final file = File('${directory.path}/diagnostics.json');
    final pending = File('${file.path}.pending');
    await pending.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report),
      flush: true,
    );
    await pending.rename(file.path);
  }
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(deadline)) {
    await tester
        .pump(const Duration(milliseconds: 300))
        .timeout(const Duration(seconds: 5));
    if (ready()) return;
  }
  throw TestFailure('iOS QA operation did not finish within 60 seconds');
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
