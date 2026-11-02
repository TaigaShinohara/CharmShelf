import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/player_notifier.dart';
import 'package:video_player/video_player.dart';

class _Paths extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class _Audio extends Mock implements ja.AudioPlayer {}

class _Video extends Mock implements VideoPlayerController {}

class _VideoPlayback {
  _VideoPlayback({
    Duration position = const Duration(seconds: 35),
    Duration duration = const Duration(seconds: 120),
  }) : nativePosition = position,
       value = VideoPlayerValue(
         duration: duration,
         position: position,
         isInitialized: true,
         isPlaying: true,
       ) {
    when(() => controller.value).thenAnswer((_) => value);
    when(() => controller.position).thenAnswer((_) {
      nativeReads++;
      if (!positionRead.isCompleted) positionRead.complete();
      return readPosition?.call() ?? Future.value(nativePosition);
    });
    when(() => controller.pause()).thenAnswer((_) {
      value = value.copyWith(isPlaying: false);
      return pauseAck ?? Future.value();
    });
    when(() => controller.play()).thenAnswer((_) {
      value = value.copyWith(isPlaying: true, isCompleted: false);
      if (rewindOnPlay) nativePosition = Duration.zero;
      return playAck ?? Future.value();
    });
    when(() => controller.seekTo(any())).thenAnswer((invocation) async {
      final position = invocation.positionalArguments.single as Duration;
      seeks.add(position);
      if (!seekStarted.isCompleted) seekStarted.complete();
      await seekAck?.call(position);
      nativePosition = position;
      value = value.copyWith(position: position);
    });
    when(() => controller.dispose()).thenAnswer((_) async {});
    when(() => controller.setPlaybackSpeed(any())).thenAnswer((
      invocation,
    ) async {
      value = value.copyWith(
        playbackSpeed: invocation.positionalArguments.single as double,
      );
    });
  }

  final controller = _Video();
  final positionRead = Completer<void>();
  final seekStarted = Completer<void>();
  final seeks = <Duration>[];
  VideoPlayerValue value;
  Duration? nativePosition;
  Future<Duration?> Function()? readPosition;
  Future<void> Function(Duration)? seekAck;
  Future<void>? pauseAck;
  Future<void>? playAck;
  bool rewindOnPlay = false;
  int nativeReads = 0;
}

class _Player extends PlayerNotifier {
  @override
  PlayerState build() => PlayerState();
  void seed(PlayerState value) => state = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFallbackValue(Duration.zero);
  late ProviderContainer container;
  late _Player player;
  late Directory directory;
  late PathProviderPlatform originalPaths;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('player_lifecycle_');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(directory.path);
    player = _Player();
    container = ProviderContainer(
      overrides: [playerNotifierProvider.overrideWith(() => player)],
    );
    container.listen(playerNotifierProvider, (_, _) {});
  });
  tearDown(() async {
    await player.stop();
    container.dispose();
    PathProviderPlatform.instance = originalPaths;
    await directory.delete(recursive: true);
  });
  MediaItem item(int id) => MediaItem()
    ..id = id
    ..path = 'missing-$id.mp4'
    ..mimeType = 'video/mp4';

  void seedVideo(_VideoPlayback video, {int id = 1, bool isPlaying = true}) {
    player.seed(
      PlayerState(
        currentItem: item(id),
        videoPlayerController: video.controller,
        isPlaying: isPlaying,
      ),
    );
  }

  test('閉じた画面の遅延stopは別画面の再生を停止しない（同じファイルでも）', () async {
    final firstOwner = Object();
    final secondOwner = Object();
    final media = item(1);
    await player.play(media, owner: firstOwner);
    final next = player.play(media, owner: secondOwner);
    await player.stop(owner: firstOwner);
    await next;
    expect(container.read(playerNotifierProvider).currentItem?.id, 1);
    await player.stop(owner: secondOwner);
    expect(container.read(playerNotifierProvider).currentItem, isNull);
  });

  test('初期化完了前の画面破棄後に古い再生状態を書き戻さない', () async {
    final owner = Object();
    final pending = player.play(item(1), owner: owner);
    await player.stop(owner: owner);
    await pending;
    expect(container.read(playerNotifierProvider).currentItem, isNull);
    expect(container.read(playerNotifierProvider).isInitializing, isFalse);
  });

  test('画面を閉じても所有者が一致する再生はミニプレイヤーへ縮小する', () async {
    final owner = Object();
    await player.play(item(1), owner: owner, isExpanded: true);

    player.minimizeToMiniPlayer(owner: owner);

    final state = container.read(playerNotifierProvider);
    expect(state.currentItem?.id, 1);
    expect(state.isExpanded, isFalse);
    expect(state.showMiniPlayer, isTrue);
  });

  test('古い画面の所有者では再生状態をミニプレイヤーへ変更しない', () async {
    final owner = Object();
    final newerOwner = Object();
    await player.play(item(1), owner: owner, isExpanded: true);
    await player.play(item(2), owner: newerOwner, isExpanded: true);

    player.minimizeToMiniPlayer(owner: owner);

    final state = container.read(playerNotifierProvider);
    expect(state.currentItem?.id, 2);
    expect(state.isExpanded, isTrue);
  });

  test('古い音声の破棄を待つ間に開始した再生状態を消さない', () async {
    final audio = _Audio();
    final stopped = Completer<void>();
    when(() => audio.stop()).thenAnswer((_) => stopped.future);
    when(() => audio.dispose()).thenAnswer((_) async {});
    player.seed(PlayerState(currentItem: item(1), audioPlayer: audio));
    final oldStop = player.stop();
    await player.play(item(2), owner: Object());
    stopped.complete();
    await oldStop;
    expect(container.read(playerNotifierProvider).currentItem?.id, 2);
    verify(() => audio.dispose()).called(1);
  });

  test('完了済み音声は先頭へ戻して再生し終了までresumeを待機させない', () async {
    final audio = _Audio();
    final playback = Completer<void>();
    when(() => audio.processingState).thenReturn(ja.ProcessingState.completed);
    when(() => audio.seek(Duration.zero)).thenAnswer((_) async {});
    when(() => audio.play()).thenAnswer((_) => playback.future);
    when(() => audio.stop()).thenAnswer((_) async {});
    when(() => audio.dispose()).thenAnswer((_) async {});
    player.seed(PlayerState(currentItem: item(1), audioPlayer: audio));
    await player.resume().timeout(const Duration(seconds: 1));
    verifyInOrder([() => audio.seek(Duration.zero), () => audio.play()]);
    expect(container.read(playerNotifierProvider).isPlaying, isTrue);
    playback.complete();
  });

  test('動画の再開時にネイティブ位置が巻き戻ったら一時停止位置を復元する', () async {
    final video = _Video();
    const pausedPosition = Duration(seconds: 35);
    var nativePosition = pausedPosition;
    var value = const VideoPlayerValue(
      duration: Duration(seconds: 120),
      position: pausedPosition,
      isInitialized: true,
      isPlaying: true,
    );
    when(() => video.value).thenAnswer((_) => value);
    when(() => video.position).thenAnswer((_) async => nativePosition);
    when(() => video.pause()).thenAnswer((_) async {
      value = value.copyWith(isPlaying: false);
    });
    when(() => video.play()).thenAnswer((_) async {
      // The cached value has not caught up with the native player's rewind.
      nativePosition = Duration.zero;
      value = value.copyWith(isPlaying: true);
    });
    when(() => video.seekTo(pausedPosition)).thenAnswer((_) async {
      nativePosition = pausedPosition;
      value = value.copyWith(position: pausedPosition);
    });
    when(() => video.dispose()).thenAnswer((_) async {});
    player.seed(
      PlayerState(
        currentItem: item(1),
        videoPlayerController: video,
        isPlaying: true,
      ),
    );

    await player.pause();
    await player.resume();

    verify(() => video.seekTo(pausedPosition)).called(1);
    expect(nativePosition, pausedPosition);
    expect(container.read(playerNotifierProvider).isPlaying, isTrue);
  });

  test('再開後に届いた動画の一時停止ACKは再生中の状態を上書きしない', () async {
    final video = _Video();
    final paused = Completer<void>();
    var value = const VideoPlayerValue(
      duration: Duration(seconds: 120),
      position: Duration(seconds: 35),
      isInitialized: true,
      isPlaying: true,
    );
    when(() => video.value).thenAnswer((_) => value);
    when(() => video.position).thenAnswer((_) async => value.position);
    when(() => video.pause()).thenAnswer((_) {
      value = value.copyWith(isPlaying: false);
      return paused.future;
    });
    when(() => video.play()).thenAnswer((_) async {
      value = value.copyWith(isPlaying: true);
    });
    when(() => video.dispose()).thenAnswer((_) async {});
    player.seed(
      PlayerState(
        currentItem: item(1),
        videoPlayerController: video,
        isPlaying: true,
      ),
    );

    final pendingPause = player.pause();
    await player.resume();
    expect(container.read(playerNotifierProvider).isPlaying, isTrue);
    paused.complete();
    await pendingPause;

    expect(value.isPlaying, isTrue);
    expect(container.read(playerNotifierProvider).isPlaying, isTrue);
  });

  for (final position in [
    const Duration(seconds: 35),
    const Duration(milliseconds: 34500),
    // An immediate +1s result is a jump, not normal playback advancement.
    const Duration(milliseconds: 35499),
  ]) {
    test('正常な動画位置または500ms以内の差ではシークしない: $position', () async {
      final video = _VideoPlayback();
      seedVideo(video);
      await player.pause();
      video.nativePosition = position;

      await player.resume();

      expect(video.nativeReads, 1);
      expect(video.seeks, isEmpty);
      expect(container.read(playerNotifierProvider).isPlaying, isTrue);
    });
  }

  test('再開直後のネイティブ位置が前方へ飛んだら一時停止位置を復元する', () async {
    final video = _VideoPlayback();
    seedVideo(video);
    await player.pause();
    video.nativePosition = const Duration(seconds: 50);

    await player.resume();

    expect(video.seeks, [const Duration(seconds: 35)]);
    expect(video.nativePosition, const Duration(seconds: 35));
    expect(container.read(playerNotifierProvider).isPlaying, isTrue);
  });

  test('再開コマンドの実際の待ち時間内に進んだ動画位置を巻き戻さない', () async {
    final video = _VideoPlayback();
    seedVideo(video);
    await player.pause();
    video.nativePosition = const Duration(milliseconds: 35800);
    video.playAck = Future<void>.delayed(const Duration(milliseconds: 800));

    await player.resume();

    expect(video.seeks, isEmpty);
    expect(container.read(playerNotifierProvider).isPlaying, isTrue);
  });

  test('倍速から通常速度へ変わっても位置取得の待ち時間内の進行を戻さない', () async {
    final video = _VideoPlayback();
    video.value = video.value.copyWith(playbackSpeed: 2);
    video.readPosition = () async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      video.value = video.value.copyWith(playbackSpeed: 1);
      return const Duration(milliseconds: 35600);
    };
    seedVideo(video);
    await player.pause();

    await player.resume();

    expect(video.seeks, isEmpty);
    expect(container.read(playerNotifierProvider).isPlaying, isTrue);
  });

  for (final speed in [double.nan, double.infinity, 1e308]) {
    test('非有限または巨大な速度の前方進行を推測で補正しない: $speed', () async {
      final video = _VideoPlayback();
      video.value = video.value.copyWith(playbackSpeed: speed);
      seedVideo(video);
      await player.pause();
      video.nativePosition = const Duration(seconds: 50);

      await player.resume();

      expect(video.seeks, isEmpty);
      expect(container.read(playerNotifierProvider).isPlaying, isTrue);
    });
  }

  for (final nativePosition in [
    const Duration(milliseconds: 36200),
    Duration.zero,
  ]) {
    test('復帰判定中の速度変更では前方の推測だけを避け後退補正は維持する: $nativePosition', () async {
      final native = Completer<Duration?>();
      final video = _VideoPlayback()..readPosition = () => native.future;
      seedVideo(video);
      await player.pause();
      final pendingResume = player.resume();
      await video.positionRead.future;

      await player.setPlaybackSpeed(4);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await player.setPlaybackSpeed(1);
      native.complete(nativePosition);
      await pendingResume;

      expect(
        video.seeks,
        nativePosition == Duration.zero
            ? [const Duration(seconds: 35)]
            : isEmpty,
      );
      expect(container.read(playerNotifierProvider).isPlaying, isTrue);
    });
  }

  test('終了済み動画の再再生を以前の一時停止位置へ戻さない', () async {
    final video = _VideoPlayback()..rewindOnPlay = true;
    seedVideo(video);
    await player.pause();
    video.value = video.value.copyWith(
      position: video.value.duration,
      isCompleted: true,
    );

    await player.resume();

    expect(video.nativeReads, 0);
    expect(video.seeks, isEmpty);
    expect(container.read(playerNotifierProvider).isPlaying, isTrue);
  });

  test('長さが未確定の動画には一時停止位置の補正を行わない', () async {
    final video = _VideoPlayback(duration: Duration.zero)..rewindOnPlay = true;
    seedVideo(video);
    await player.pause();

    await player.resume();

    expect(video.nativeReads, 0);
    expect(video.seeks, isEmpty);
  });

  for (final invalid in <Duration?>[
    null,
    const Duration(milliseconds: -1),
    const Duration(seconds: 121),
  ]) {
    test('取得不能または範囲外のネイティブ動画位置を推測で補正しない: $invalid', () async {
      final video = _VideoPlayback();
      seedVideo(video);
      await player.pause();
      video.nativePosition = invalid;

      await player.resume();

      expect(video.nativeReads, 1);
      expect(video.seeks, isEmpty);
      expect(container.read(playerNotifierProvider).isPlaying, isTrue);
    });
  }

  test('ネイティブ位置の取得失敗でも推測シークせず再開を完了する', () async {
    final video = _VideoPlayback()
      ..readPosition = () async => throw StateError('position unavailable');
    seedVideo(video);
    await player.pause();

    await player.resume();

    expect(video.nativeReads, 1);
    expect(video.seeks, isEmpty);
    expect(container.read(playerNotifierProvider).isPlaying, isTrue);
  });

  test('ネイティブ位置の応答を無期限に待たず遅い結果も補正に使わない', () async {
    final native = Completer<Duration?>();
    final video = _VideoPlayback()..readPosition = () => native.future;
    seedVideo(video);
    await player.pause();

    final pendingResume = player.resume();
    await video.positionRead.future;
    video.value = video.value.copyWith(position: Duration.zero);
    video.nativePosition = Duration.zero;
    await pendingResume.timeout(const Duration(seconds: 2));
    native.complete(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(video.nativeReads, 1);
    expect(video.seeks, isEmpty);
    expect(container.read(playerNotifierProvider).isPlaying, isTrue);
    video.readPosition = null;
    await player.pause();
    await player.resume();
    expect(video.seeks, isEmpty);
  });

  test('ネイティブ位置の待機中に手動シークしたら古い位置と状態を復元しない', () async {
    final native = Completer<Duration?>();
    final video = _VideoPlayback()..readPosition = () => native.future;
    seedVideo(video);
    await player.pause();
    final pendingResume = player.resume();
    await video.positionRead.future;

    await player.seekVideoTo(const Duration(seconds: 10));
    native.complete(Duration.zero);
    await pendingResume;

    expect(video.seeks, [const Duration(seconds: 10)]);
    expect(container.read(playerNotifierProvider).isPlaying, isFalse);
  });

  test('補正シークの応答中に指定した最新の本人位置を最後に適用する', () async {
    final correction = Completer<void>();
    final video = _VideoPlayback()
      ..rewindOnPlay = true
      ..seekAck = (position) => position == const Duration(seconds: 35)
          ? correction.future
          : Future.value();
    seedVideo(video);
    await player.pause();
    final pendingResume = player.resume();
    await video.seekStarted.future;

    final supersededSeek = player.seekVideoTo(const Duration(seconds: 10));
    final latestSeek = player.seekVideoTo(const Duration(seconds: 20));
    expect(video.seeks, [const Duration(seconds: 35)]);
    correction.complete();
    await Future.wait([pendingResume, supersededSeek, latestSeek]);

    expect(video.seeks, [
      const Duration(seconds: 35),
      const Duration(seconds: 20),
    ]);
    expect(video.nativePosition, const Duration(seconds: 20));
    expect(container.read(playerNotifierProvider).isPlaying, isFalse);
  });

  for (final stage in ['play', 'position']) {
    for (final jumpedPosition in [Duration.zero, const Duration(seconds: 50)]) {
      test('復帰の$stage応答待ち中のpauseは元の位置を失わない: $jumpedPosition', () async {
        final playAck = Completer<void>();
        final native = Completer<Duration?>();
        final video = _VideoPlayback();
        seedVideo(video);
        await player.pause();
        if (stage == 'play') {
          video.playAck = playAck.future;
        } else {
          video.readPosition = () => native.future;
        }
        final pendingResume = player.resume();
        if (stage == 'position') await video.positionRead.future;
        video.value = video.value.copyWith(position: jumpedPosition);
        video.nativePosition = jumpedPosition;

        await player.pause();
        await player.pause();
        if (stage == 'play') {
          playAck.complete();
        } else {
          native.complete(jumpedPosition);
        }
        await pendingResume;
        expect(video.seeks, isEmpty);
        // A later duplicate lifecycle pause must also retain the intent after
        // the superseded resume's finally has released its own window.
        await player.pause();
        video.playAck = null;
        video.readPosition = null;
        await player.resume();

        expect(video.seeks, [const Duration(seconds: 35)]);
        expect(video.nativePosition, const Duration(seconds: 35));
        expect(container.read(playerNotifierProvider).isPlaying, isTrue);
      });
    }
  }

  test('復帰windowを引き継ぐresumeは先行800msの正常進行を巻き戻さない', () async {
    final firstPosition = Completer<Duration?>();
    var reads = 0;
    final video = _VideoPlayback()
      ..readPosition = () => ++reads == 1
          ? firstPosition.future
          : Future.value(const Duration(milliseconds: 35800));
    seedVideo(video);
    await player.pause();
    final firstResume = player.resume();
    await video.positionRead.future;
    await Future<void>.delayed(const Duration(milliseconds: 800));
    video.value = video.value.copyWith(
      position: const Duration(milliseconds: 35800),
    );
    video.nativePosition = const Duration(milliseconds: 35800);

    await player.resume();
    firstPosition.complete(const Duration(milliseconds: 35800));
    await firstResume;

    expect(video.nativeReads, 2);
    expect(video.seeks, isEmpty);
    expect(video.nativePosition, const Duration(milliseconds: 35800));
    expect(container.read(playerNotifierProvider).isPlaying, isTrue);
  });

  test('復帰windowの引継ぎに800msの一時停止時間を再生時間として足さない', () async {
    final firstPosition = Completer<Duration?>();
    var reads = 0;
    final video = _VideoPlayback()
      ..readPosition = () => ++reads == 1
          ? firstPosition.future
          : Future.value(const Duration(milliseconds: 35800));
    seedVideo(video);
    await player.pause();
    final firstResume = player.resume();
    await video.positionRead.future;

    await player.pause();
    await Future<void>.delayed(const Duration(milliseconds: 800));
    video.value = video.value.copyWith(
      position: const Duration(milliseconds: 35800),
    );
    video.nativePosition = const Duration(milliseconds: 35800);
    await player.resume();
    firstPosition.complete(const Duration(milliseconds: 35800));
    await firstResume;

    expect(video.nativeReads, 2);
    expect(video.seeks, [const Duration(seconds: 35)]);
    expect(video.nativePosition, const Duration(seconds: 35));
    expect(container.read(playerNotifierProvider).isPlaying, isTrue);
  });

  test('同じ目標でも古いresumeのfinallyは新しい復帰ownerを解放しない', () async {
    final firstPosition = Completer<Duration?>();
    final secondPosition = Completer<Duration?>();
    final secondStarted = Completer<void>();
    var reads = 0;
    final video = _VideoPlayback()
      ..readPosition = () {
        reads++;
        if (reads == 1) return firstPosition.future;
        if (reads == 2) {
          secondStarted.complete();
          return secondPosition.future;
        }
        return Future.value(Duration.zero);
      };
    seedVideo(video);
    await player.pause();
    final firstResume = player.resume();
    await video.positionRead.future;
    final secondResume = player.resume();
    await secondStarted.future;
    video.value = video.value.copyWith(position: Duration.zero);
    video.nativePosition = Duration.zero;

    firstPosition.complete(Duration.zero);
    await firstResume;
    await player.pause();
    secondPosition.complete(Duration.zero);
    await secondResume;
    await player.resume();

    expect(video.nativeReads, 3);
    expect(video.seeks, [const Duration(seconds: 35)]);
    expect(video.nativePosition, const Duration(seconds: 35));
  });

  for (final queryFails in [false, true]) {
    test('位置の取得不能後に完了した復帰windowを成功した位置として再利用しない: $queryFails', () async {
      final video = _VideoPlayback();
      video.readPosition = () async {
        video.value = video.value.copyWith(position: Duration.zero);
        video.nativePosition = Duration.zero;
        if (queryFails) throw StateError('position unavailable');
        return null;
      };
      seedVideo(video);
      await player.pause();
      await player.resume();
      video.readPosition = null;

      await player.pause();
      await player.resume();

      expect(video.seeks, isEmpty);
      expect(video.nativePosition, Duration.zero);
      expect(container.read(playerNotifierProvider).isPlaying, isTrue);
    });
  }

  for (final jumpedPosition in [Duration.zero, const Duration(seconds: 50)]) {
    test(
      '補正シーク中のpauseはジャンプ済みcached位置を次のbookmarkにしない: $jumpedPosition',
      () async {
        final correction = Completer<void>();
        final video = _VideoPlayback()
          ..seekAck = (position) => position == const Duration(seconds: 35)
              ? correction.future
              : Future.value();
        seedVideo(video);
        await player.pause();
        video.nativePosition = jumpedPosition;
        final pendingResume = player.resume();
        await video.seekStarted.future;
        // A normal native position poll can publish the rollback/jump while the
        // corrective native seek is still awaiting its acknowledgement.
        video.value = video.value.copyWith(position: jumpedPosition);

        await player.pause();
        correction.complete();
        await pendingResume;
        expect(video.nativePosition, const Duration(seconds: 35));
        await player.resume();

        expect(video.seeks, [const Duration(seconds: 35)]);
        expect(video.nativePosition, const Duration(seconds: 35));
        expect(container.read(playerNotifierProvider).isPlaying, isTrue);
      },
    );
  }

  test('補正シーク中にpauseして再開しても同じ補正を重ねない', () async {
    final correction = Completer<void>();
    final video = _VideoPlayback()..seekAck = (_) => correction.future;
    seedVideo(video);
    await player.pause();
    video.nativePosition = Duration.zero;
    final pendingResume = player.resume();
    await video.seekStarted.future;
    video.value = video.value.copyWith(position: Duration.zero);

    await player.pause();
    await player.resume();
    expect(video.nativeReads, 1);
    correction.complete();
    await pendingResume;

    expect(video.seeks, [const Duration(seconds: 35)]);
    expect(video.nativePosition, const Duration(seconds: 35));
    expect(container.read(playerNotifierProvider).isPlaying, isTrue);
  });

  test('補正シーク失敗後はpauseで保持した未成功の位置を再適用しない', () async {
    final correction = Completer<void>();
    final failure = StateError('correction failed');
    final video = _VideoPlayback()..seekAck = (_) => correction.future;
    seedVideo(video);
    await player.pause();
    video.nativePosition = Duration.zero;
    final pendingResume = player.resume();
    final resumeFailure = expectLater(pendingResume, throwsA(same(failure)));
    await video.seekStarted.future;
    video.value = video.value.copyWith(position: Duration.zero);

    await player.pause();
    correction.completeError(failure);
    await resumeFailure;
    await player.resume();

    expect(video.seeks, [const Duration(seconds: 35)]);
    expect(video.nativeReads, 1);
    expect(container.read(playerNotifierProvider).isPlaying, isTrue);
  });

  test('古い補正の失敗は新しい本人位置のpause bookmarkを破棄しない', () async {
    final correction = Completer<void>();
    final failure = StateError('old correction failed');
    final video = _VideoPlayback()
      ..seekAck = (position) => position == const Duration(seconds: 35)
          ? correction.future
          : Future.value();
    seedVideo(video);
    await player.pause();
    video.nativePosition = Duration.zero;
    final pendingResume = player.resume();
    final resumeFailure = expectLater(pendingResume, throwsA(same(failure)));
    await video.seekStarted.future;
    video.value = video.value.copyWith(position: Duration.zero);

    final manualSeek = player.seekVideoTo(const Duration(seconds: 10));
    await player.pause();
    correction.completeError(failure);
    await resumeFailure;
    await manualSeek;
    video.nativePosition = Duration.zero;
    await player.resume();

    expect(video.seeks, [
      const Duration(seconds: 35),
      const Duration(seconds: 10),
      const Duration(seconds: 10),
    ]);
    expect(video.nativePosition, const Duration(seconds: 10));
    expect(container.read(playerNotifierProvider).isPlaying, isTrue);
  });

  test('補正シークの応答が破棄後に届いても無効なRefへ状態を書かない', () async {
    final localPlayer = _Player();
    final localContainer = ProviderContainer(
      overrides: [playerNotifierProvider.overrideWith(() => localPlayer)],
    );
    localContainer.listen(playerNotifierProvider, (_, _) {});
    final correction = Completer<void>();
    final video = _VideoPlayback()..seekAck = (_) => correction.future;
    localPlayer.seed(
      PlayerState(
        currentItem: item(1),
        videoPlayerController: video.controller,
        isPlaying: true,
      ),
    );
    await localPlayer.pause();
    video.nativePosition = Duration.zero;
    final pendingResume = localPlayer.resume();
    await video.seekStarted.future;

    localContainer.dispose();
    correction.complete();
    await pendingResume;

    expect(video.seeks, [const Duration(seconds: 35)]);
  });

  for (final action in ['pause', 'resume']) {
    test('補正シーク待ちの本人位置指定は後続のpause/resumeで取り消さない: $action', () async {
      final correction = Completer<void>();
      final video = _VideoPlayback()
        ..rewindOnPlay = true
        ..seekAck = (position) => position == const Duration(seconds: 35)
            ? correction.future
            : Future.value();
      seedVideo(video);
      await player.pause();
      final pendingResume = player.resume();
      await video.seekStarted.future;

      final manualSeek = player.seekVideoTo(const Duration(seconds: 10));
      final latestTransport = action == 'pause'
          ? player.pause()
          : player.resume();
      await Future<void>.delayed(Duration.zero);
      correction.complete();
      await Future.wait([pendingResume, manualSeek, latestTransport]);

      expect(video.nativePosition, const Duration(seconds: 10));
      expect(video.seeks, [
        const Duration(seconds: 35),
        const Duration(seconds: 10),
      ]);
      expect(
        container.read(playerNotifierProvider).isPlaying,
        action == 'resume',
      );
      if (action == 'pause') {
        await player.resume();
        expect(video.nativePosition, const Duration(seconds: 10));
        expect(video.seeks.last, const Duration(seconds: 10));
        expect(container.read(playerNotifierProvider).isPlaying, isTrue);
      }
    });
  }

  test('待機中の本人シークが失敗したらその位置のpause bookmarkも破棄する', () async {
    final correction = Completer<void>();
    final manual = Completer<void>();
    final manualStarted = Completer<void>();
    final failure = StateError('manual seek failed');
    final video = _VideoPlayback()
      ..rewindOnPlay = true
      ..seekAck = (position) {
        if (position == const Duration(seconds: 35)) return correction.future;
        manualStarted.complete();
        return manual.future;
      };
    seedVideo(video);
    await player.pause();
    final pendingResume = player.resume();
    await video.seekStarted.future;
    final manualSeek = player.seekVideoTo(const Duration(seconds: 10));
    final manualFailure = expectLater(manualSeek, throwsA(same(failure)));

    await player.pause();
    correction.complete();
    await pendingResume;
    await manualStarted.future;
    manual.completeError(failure);
    await manualFailure;
    await player.resume();

    expect(video.seeks, [
      const Duration(seconds: 35),
      const Duration(seconds: 10),
    ]);
    expect(video.nativeReads, 1);
    expect(container.read(playerNotifierProvider).isPlaying, isTrue);
  });

  test('待機中の本人シークが終端ならpauseで以前の位置をbookmarkに戻さない', () async {
    final correction = Completer<void>();
    final video = _VideoPlayback()
      ..rewindOnPlay = true
      ..seekAck = (position) => position == const Duration(seconds: 35)
          ? correction.future
          : Future.value();
    seedVideo(video);
    await player.pause();
    final pendingResume = player.resume();
    await video.seekStarted.future;
    final manualSeek = player.seekVideoTo(const Duration(seconds: 120));

    await player.pause();
    correction.complete();
    await Future.wait([pendingResume, manualSeek]);
    await player.resume();

    expect(video.seeks, [
      const Duration(seconds: 35),
      const Duration(seconds: 120),
    ]);
    expect(video.nativeReads, 1);
    expect(container.read(playerNotifierProvider).isPlaying, isTrue);
  });

  test('別コントローラーのシークは古い補正シークの応答を待たない', () async {
    final correction = Completer<void>();
    final old = _VideoPlayback()
      ..rewindOnPlay = true
      ..seekAck = (_) => correction.future;
    seedVideo(old);
    await player.pause();
    final pendingResume = player.resume();
    await old.seekStarted.future;
    final current = _VideoPlayback();
    seedVideo(current, id: 2);

    await player
        .seekVideoTo(const Duration(seconds: 10))
        .timeout(const Duration(seconds: 1));
    correction.complete();
    await pendingResume;

    expect(current.seeks, [const Duration(seconds: 10)]);
    expect(container.read(playerNotifierProvider).currentItem?.id, 2);
    expect(container.read(playerNotifierProvider).isPlaying, isTrue);
  });

  test('補正シーク失敗を呼出元に返しても後続の本人シークは実行する', () async {
    final correction = Completer<void>();
    final failure = StateError('seek failed');
    final video = _VideoPlayback()
      ..rewindOnPlay = true
      ..seekAck = (position) => position == const Duration(seconds: 35)
          ? correction.future
          : Future.value();
    seedVideo(video);
    await player.pause();
    final pendingResume = player.resume();
    final resumeFailure = expectLater(pendingResume, throwsA(same(failure)));
    await video.seekStarted.future;

    final latestSeek = player.seekVideoTo(const Duration(seconds: 10));
    correction.completeError(failure);
    await resumeFailure;
    await latestSeek;

    expect(video.seeks, [
      const Duration(seconds: 35),
      const Duration(seconds: 10),
    ]);
    expect(video.nativePosition, const Duration(seconds: 10));
    expect(container.read(playerNotifierProvider).isPlaying, isFalse);
  });

  for (final action in ['stop', 'new-play']) {
    test('停止と新規再生は古い補正シークの応答を待たない: $action', () async {
      final correction = Completer<void>();
      final old = _VideoPlayback()
        ..rewindOnPlay = true
        ..seekAck = (_) => correction.future;
      seedVideo(old);
      await player.pause();
      final pendingResume = player.resume();
      await old.seekStarted.future;

      await (action == 'stop'
              ? player.stop()
              : player.play(item(2), owner: Object()))
          .timeout(const Duration(seconds: 1));
      correction.complete();
      await pendingResume;

      expect(
        container.read(playerNotifierProvider).currentItem?.id,
        action == 'stop' ? isNull : 2,
      );
      expect(container.read(playerNotifierProvider).isPlaying, isFalse);
    });
  }

  test('ネイティブ位置の待機中に停止したら古い動画を復元しない', () async {
    final native = Completer<Duration?>();
    final video = _VideoPlayback()..readPosition = () => native.future;
    seedVideo(video);
    await player.pause();
    final pendingResume = player.resume();
    await video.positionRead.future;

    await player.stop();
    native.complete(Duration.zero);
    await pendingResume;

    expect(video.seeks, isEmpty);
    expect(container.read(playerNotifierProvider).currentItem, isNull);
    expect(container.read(playerNotifierProvider).isPlaying, isFalse);
  });

  test('ネイティブ位置の待機中に別の再生を始めたら古い状態を戻さない', () async {
    final native = Completer<Duration?>();
    final video = _VideoPlayback()..readPosition = () => native.future;
    seedVideo(video);
    await player.pause();
    final pendingResume = player.resume();
    await video.positionRead.future;

    await player.play(item(2), owner: Object());
    native.complete(Duration.zero);
    await pendingResume;

    expect(video.seeks, isEmpty);
    expect(container.read(playerNotifierProvider).currentItem?.id, 2);
    expect(container.read(playerNotifierProvider).isPlaying, isFalse);
  });

  test('ネイティブ位置の待機中にコントローラーが替わっても新しい再生を守る', () async {
    final native = Completer<Duration?>();
    final old = _VideoPlayback()..readPosition = () => native.future;
    seedVideo(old);
    await player.pause();
    final pendingResume = player.resume();
    await old.positionRead.future;

    final current = _VideoPlayback();
    seedVideo(current, id: 2, isPlaying: false);
    await player.resume();
    native.complete(Duration.zero);
    await pendingResume;

    expect(old.seeks, isEmpty);
    expect(current.seeks, isEmpty);
    expect(container.read(playerNotifierProvider).currentItem?.id, 2);
    expect(container.read(playerNotifierProvider).isPlaying, isTrue);
  });

  test('古いSliderのシーク拒否は現在の一時停止位置を消さない', () async {
    final current = _VideoPlayback()..rewindOnPlay = true;
    final old = _Video();
    seedVideo(current);
    await player.pause();

    await player.seekVideoTo(
      const Duration(seconds: 10),
      expectedController: old,
    );
    await player.resume();

    expect(current.seeks, [const Duration(seconds: 35)]);
    verifyNever(() => old.seekTo(any()));
  });

  for (final action in ['relative', 'start', 'end']) {
    test('動画の明示シークで一時停止位置を破棄する: $action', () async {
      final video = _VideoPlayback()..rewindOnPlay = true;
      seedVideo(video);
      await player.pause();
      final expected = switch (action) {
        'relative' => const Duration(seconds: 40),
        'start' => Duration.zero,
        _ => const Duration(seconds: 120),
      };
      switch (action) {
        case 'relative':
          await player.seek(const Duration(seconds: 5));
        case 'start':
          await player.seekToStart();
        case 'end':
          await player.seekToEnd();
      }

      await player.resume();

      expect(video.seeks, [expected]);
      expect(video.nativeReads, 0);
    });
  }

  test('古いresume ACKは同じ動画の新しいpause状態を上書きしない', () async {
    final played = Completer<void>();
    final video = _VideoPlayback()..playAck = played.future;
    seedVideo(video);
    await player.pause();
    final pendingResume = player.resume();

    await player.pause();
    played.complete();
    await pendingResume;

    expect(video.value.isPlaying, isFalse);
    expect(video.nativeReads, 0);
    expect(container.read(playerNotifierProvider).isPlaying, isFalse);
  });

  test('古いpause ACKは別コントローラーの再生状態を上書きしない', () async {
    final paused = Completer<void>();
    final old = _VideoPlayback()..pauseAck = paused.future;
    seedVideo(old);
    final pendingPause = player.pause();
    final current = _VideoPlayback();
    seedVideo(current, id: 2);

    paused.complete();
    await pendingPause;

    expect(container.read(playerNotifierProvider).currentItem?.id, 2);
    expect(container.read(playerNotifierProvider).isPlaying, isTrue);
  });

  test('古いresume ACKは別コントローラーの停止状態を上書きしない', () async {
    final played = Completer<void>();
    final old = _VideoPlayback()..playAck = played.future;
    seedVideo(old);
    final pendingResume = player.resume();
    final current = _VideoPlayback();
    seedVideo(current, id: 2, isPlaying: false);

    played.complete();
    await pendingResume;

    expect(container.read(playerNotifierProvider).currentItem?.id, 2);
    expect(container.read(playerNotifierProvider).isPlaying, isFalse);
  });
}
