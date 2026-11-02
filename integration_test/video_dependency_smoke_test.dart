import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:private_shelf/core/services/app_lifecycle_service.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/player_notifier.dart';
import 'package:video_player/video_player.dart';

// Dedicated Android QA only. The host supplies base64-encoded red/blue clips:
// silent, synthetic 64x64, 10fps, 120-second videos. This UID creates the files
// itself inside a new private-cache directory; host-owned external files are
// deliberately not used under Android scoped storage.
// Required defines: TAGSHELF_DEPENDENCY_QA_SOURCE_HASH,
// TAGSHELF_VIDEO_QA_RED_BASE64, TAGSHELF_VIDEO_QA_BLUE_BASE64,
// TAGSHELF_VIDEO_QA_RED_SHA256, TAGSHELF_VIDEO_QA_BLUE_SHA256.
// No app.main, database, or provider mocks.
// Native playback and lifecycle assertions do not establish visual/audio quality.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const allowedPackage = 'com.tsmusic.privateshelf.opensource.performanceqa26102605';
  const sourceHash = String.fromEnvironment(
    'TAGSHELF_DEPENDENCY_QA_SOURCE_HASH',
  );
  const redPayload = String.fromEnvironment('TAGSHELF_VIDEO_QA_RED_BASE64');
  const bluePayload = String.fromEnvironment('TAGSHELF_VIDEO_QA_BLUE_BASE64');
  const redHash = String.fromEnvironment('TAGSHELF_VIDEO_QA_RED_SHA256');
  const blueHash = String.fromEnvironment('TAGSHELF_VIDEO_QA_BLUE_SHA256');
  var packageName = '';
  var stage = 'guard';

  void report(String event, [Map<String, Object?> values = const {}]) {
    // Only synthetic test metadata is reported, never media paths or bytes.
    // ignore: avoid_print
    print(
      'TAGSHELF_VIDEO_DEPENDENCY_QA ${jsonEncode({'event': event, 'stage': stage, 'pid': pid, 'package': packageName, 'sourceHash': sourceHash, ...values})}',
    );
  }

  binding.allTestsPassed.future.then((passed) {
    report('completed', {'allTestsPassed': passed});
  });

  testWidgets('native video survives view changes and pauses for real HOME', (
    tester,
  ) async {
    expect(Platform.isAndroid, isTrue);
    packageName = (await PackageInfo.fromPlatform()).packageName;
    expect(packageName, allowedPackage);
    for (final hash in [sourceHash, redHash, blueHash]) {
      expect(RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(hash), isTrue);
    }
    expect(redHash.toLowerCase(), isNot(blueHash.toLowerCase()));
    final cache = await getTemporaryDirectory();
    final ownedPath = await cache.resolveSymbolicLinks();
    final fixtureDirectory = await cache.createTemp('dependency-video-');
    final canonicalFixtures = await fixtureDirectory.resolveSymbolicLinks();
    expect(
      p.isWithin(ownedPath, canonicalFixtures),
      isTrue,
      reason: 'Fixtures must remain inside this QA UID private cache',
    );
    final red = await _fixture(
      fixtureDirectory,
      'red.mp4',
      redPayload,
      redHash,
      1,
    );
    final blue = await _fixture(
      fixtureDirectory,
      'blue.mp4',
      bluePayload,
      blueHash,
      2,
    );
    report('fixturesVerified');

    stage = 'unconfigured-local-auth';
    final authentication = LocalAuthentication();
    final supported = await authentication.isDeviceSupported().timeout(
      const Duration(seconds: 10),
    );
    final biometrics = await authentication.getAvailableBiometrics().timeout(
      const Duration(seconds: 10),
    );
    report('localAuthenticationCapabilities', {
      'deviceSupported': supported,
      'enrolledBiometricCount': biometrics.length,
    });
    expect(biometrics, isEmpty);
    expect(
      supported,
      isFalse,
      reason:
          'This fresh QA emulator must have no lock credential or biometrics',
    );
    // local_auth 3.0.2 disables error dialogs. Android 2.3.0 returns
    // NO_CREDENTIALS before constructing AuthenticationHelper when unsupported,
    // so this guarded call cannot open an enrollment/settings prompt.
    try {
      await authentication
          .authenticate(
            localizedReason: 'Synthetic unconfigured-device dependency QA',
            biometricOnly: true,
            persistAcrossBackgrounding: false,
          )
          .timeout(const Duration(seconds: 10));
      fail('Expected a typed unconfigured-device authentication error');
    } on LocalAuthException catch (error) {
      expect(
        error.code,
        isIn(const [
          LocalAuthExceptionCode.noCredentialsSet,
          LocalAuthExceptionCode.noBiometricsEnrolled,
          LocalAuthExceptionCode.noBiometricHardware,
        ]),
      );
      report('unconfiguredAuthenticationRejected', {'code': error.code.name});
    }

    final container = ProviderContainer();
    final homeClock = Stopwatch();
    var awaitingHome = false;
    Duration? backgroundAt;
    Duration? foregroundAt;
    Duration? pausedPosition;
    // Retain the real autoDispose player, as the real app's player UI does.
    final playerSubscription = container.listen(playerNotifierProvider, (
      previous,
      next,
    ) {
      if (awaitingHome &&
          !next.isPlaying &&
          next.videoPlayerController != null &&
          container.read(appLifecycleProvider) !=
              AppLifecycleStatus.foreground) {
        pausedPosition ??= next.videoPlayerController!.value.position;
      }
    });
    final lifecycleSubscription = container.listen(appLifecycleProvider, (
      previous,
      next,
    ) {
      if (!awaitingHome) return;
      if (next == AppLifecycleStatus.background) {
        backgroundAt ??= homeClock.elapsed;
      } else if (next == AppLifecycleStatus.foreground &&
          backgroundAt != null) {
        foregroundAt ??= homeClock.elapsed;
      }
    });
    final player = container.read(playerNotifierProvider.notifier);
    final navigator = GlobalKey<NavigatorState>();
    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: navigator,
            home: const Scaffold(
              body: Center(child: Text('Video dependency QA home')),
            ),
          ),
        ),
      );

      stage = 'initial-playback';
      final initialOwner = Object();
      final firstRoute = navigator.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => _VideoRoute(
            onExit: () => player.minimizeToMiniPlayer(owner: initialOwner),
          ),
        ),
      );
      await _withFrames(
        tester,
        player.play(red.item, file: red.file, owner: initialOwner),
      );
      final initialController = await _playing(tester, container, red.item.id);
      expect(find.byType(Chewie), findsOneWidget);
      report('initialPlaybackAdvanced', {
        'positionMs': initialController.value.position.inMilliseconds,
      });

      stage = 'view-exit';
      await tester.tap(find.byKey(const ValueKey('leave-video-qa')));
      await _withFrames(tester, firstRoute);
      await _until(
        tester,
        () => find.byKey(const ValueKey('video-qa-route')).evaluate().isEmpty,
      );
      final afterExit = container.read(playerNotifierProvider);
      expect(afterExit.videoPlayerController, same(initialController));
      expect(afterExit.isExpanded, isFalse);
      expect(afterExit.showMiniPlayer, isTrue);
      final leftAt = initialController.value.position;
      await _until(
        tester,
        () =>
            initialController.value.position - leftAt >=
            const Duration(milliseconds: 500),
      );
      expect(initialController.value.isPlaying, isTrue);
      report('viewExitRetainedPlayback');

      stage = 'rapid-switch';
      final finalOwner = Object();
      unawaited(
        navigator.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => _VideoRoute(
              onExit: () => player.minimizeToMiniPlayer(owner: finalOwner),
            ),
          ),
        ),
      );
      final switchErrors = <Object>[];
      final switches = <Future<void>>[];
      for (final fixture in [blue, red, blue]) {
        switches.add(
          _capture(
            player.play(fixture.item, file: fixture.file, owner: finalOwner),
            switchErrors,
          ),
        );
        await tester.pump(const Duration(milliseconds: 30));
      }
      await _withFrames(tester, Future.wait(switches));
      expect(switchErrors, isEmpty);
      final activeController = await _playing(tester, container, blue.item.id);
      expect(find.byType(Chewie), findsOneWidget);
      await _withFrames(tester, player.stop(owner: initialOwner));
      expect(
        container.read(playerNotifierProvider).videoPlayerController,
        same(activeController),
      );
      expect(activeController.value.isPlaying, isTrue);
      report('rapidSwitchesCompleted', {'switchCount': switches.length});

      stage = 'home-and-return';
      awaitingHome = true;
      homeClock.start();
      // Host: HOME, wait three real seconds, then reopen this same Activity
      // without force-stop/reinstall. The final result must retain this PID.
      report('awaitingBackground');
      await _until(
        tester,
        () => backgroundAt != null && foregroundAt != null,
        timeout: const Duration(seconds: 90),
      );
      expect(
        foregroundAt! - backgroundAt!,
        greaterThanOrEqualTo(const Duration(seconds: 2)),
      );
      expect(pausedPosition, isNotNull);
      expect(container.read(playerNotifierProvider).isPlaying, isFalse);
      expect(activeController.value.isPlaying, isFalse);
      expect(
        (activeController.value.position - pausedPosition!).abs(),
        lessThanOrEqualTo(const Duration(seconds: 1)),
      );
      final returnedAt = activeController.value.position;
      await tester.pump(const Duration(milliseconds: 600));
      expect(activeController.value.isPlaying, isFalse);
      expect(
        (activeController.value.position - returnedAt).abs(),
        lessThanOrEqualTo(const Duration(milliseconds: 300)),
      );
      report('foregroundRestoredPaused', {
        'backgroundMs': (foregroundAt! - backgroundAt!).inMilliseconds,
      });

      stage = 'explicit-resume';
      await _withFrames(tester, player.resume());
      await _until(
        tester,
        () =>
            activeController.value.isPlaying &&
            activeController.value.position - returnedAt >=
                const Duration(milliseconds: 500),
      );
      report('resumedPlaybackAdvanced');
      stage = 'finished';
      expect(tester.takeException(), isNull);
    } finally {
      try {
        // Detach the real Chewie view before disposing its native controller.
        await tester.pumpWidget(const SizedBox.shrink());
        await _withFrames(tester, player.stop());
        expect(container.read(playerNotifierProvider).currentItem, isNull);
      } finally {
        playerSubscription.close();
        lifecycleSubscription.close();
        container.dispose();
      }
    }
  }, timeout: const Timeout(Duration(minutes: 6)));
}

Future<({MediaItem item, File file})> _fixture(
  Directory directory,
  String name,
  String encodedPayload,
  String expectedHash,
  int id,
) async {
  const maximumBytes = 8 * 1024 * 1024;
  const maximumBase64Length = ((maximumBytes + 2) ~/ 3) * 4;
  expect(name, isIn(const ['red.mp4', 'blue.mp4']));
  expect(encodedPayload.length, inInclusiveRange(1, maximumBase64Length));
  late final List<int> bytes;
  try {
    bytes = base64Decode(encodedPayload);
  } on FormatException {
    // FormatException can include the input; never expose the encoded payload.
    throw TestFailure('Synthetic video payload is not valid base64');
  }
  expect(bytes.length, inInclusiveRange(1, maximumBytes));
  final file = File(p.join(directory.path, name));
  expect(await file.exists(), isFalse);
  await file.writeAsBytes(bytes, flush: true);
  final canonical = await file.resolveSymbolicLinks();
  expect(p.isWithin(await directory.resolveSymbolicLinks(), canonical), isTrue);
  expect(await file.length(), inInclusiveRange(1, maximumBytes));
  final digest = await sha256
      .bind(file.openRead())
      .single
      .timeout(const Duration(seconds: 10));
  expect(digest.toString(), expectedHash.toLowerCase());
  return (
    item: MediaItem()
      ..id = id
      ..path = name
      ..mimeType = 'video/mp4',
    file: file,
  );
}

Future<VideoPlayerController> _playing(
  WidgetTester tester,
  ProviderContainer container,
  int itemId,
) async {
  await _until(tester, () {
    final state = container.read(playerNotifierProvider);
    if (state.error != null) {
      throw TestFailure('Native player reported an error');
    }
    final video = state.videoPlayerController;
    return state.currentItem?.id == itemId &&
        state.chewieController != null &&
        video != null &&
        !video.value.hasError &&
        video.value.isInitialized &&
        video.value.isPlaying &&
        video.value.position >= const Duration(seconds: 1);
  });
  final video = container.read(playerNotifierProvider).videoPlayerController!;
  expect(video.value.size, const Size(64, 64));
  expect(video.value.duration.inSeconds, inInclusiveRange(119, 121));
  return video;
}

Future<void> _capture(Future<void> operation, List<Object> errors) async {
  try {
    await operation;
  } catch (error) {
    errors.add(error);
  }
}

Future<void> _until(
  WidgetTester tester,
  bool Function() ready, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    final error = tester.takeException();
    if (error != null) throw TestFailure('Video QA framework error: $error');
    if (ready()) return;
  }
  throw TestFailure('Video QA operation exceeded its deadline');
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

class _VideoRoute extends ConsumerStatefulWidget {
  const _VideoRoute({required this.onExit});
  final VoidCallback onExit;

  @override
  ConsumerState<_VideoRoute> createState() => _VideoRouteState();
}

class _VideoRouteState extends ConsumerState<_VideoRoute> {
  @override
  void dispose() {
    // Match the production non-preview route's minimize-on-exit policy.
    final onExit = widget.onExit;
    WidgetsBinding.instance.addPostFrameCallback((_) => onExit());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerNotifierProvider);
    final controller = state.chewieController;
    return Scaffold(
      key: const ValueKey('video-qa-route'),
      appBar: AppBar(
        title: const Text('Synthetic video dependency QA'),
        actions: [
          TextButton(
            key: const ValueKey('leave-video-qa'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Leave'),
          ),
        ],
      ),
      body: controller == null
          ? const Center(child: Text('Initializing synthetic video'))
          : Center(child: Chewie(controller: controller)),
    );
  }
}
