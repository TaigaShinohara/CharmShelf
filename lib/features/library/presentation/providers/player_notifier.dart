import 'dart:async';
import 'dart:io';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/core/feedback/sound_service.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:video_player/video_player.dart';
import 'package:path/path.dart' as p;
import 'package:just_audio/just_audio.dart' as ja;
import 'package:just_audio_background/just_audio_background.dart' as jab;
import 'package:audio_session/audio_session.dart';

import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/services/app_lifecycle_service.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/private_storage_service.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/data/services/external_storage_service.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/features/library/presentation/providers/media_item_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/external_library_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';
import '../../domain/models/media_item.dart';

part 'player_notifier.g.dart';

/// 再生状態
class PlayerState {
  final MediaItem? currentItem;
  final VideoPlayerController? videoPlayerController;
  final ChewieController? chewieController;
  final ja.AudioPlayer? audioPlayer;
  final bool isPlaying;
  final bool isMuted;
  final double volume;
  final String? error;
  final bool isExpanded;
  final bool isInitializing;
  final bool showMiniPlayer;

  PlayerState({
    this.currentItem,
    this.videoPlayerController,
    this.chewieController,
    this.audioPlayer,
    this.isPlaying = false,
    this.isMuted = false,
    this.volume = 1.0,
    this.error,
    this.isExpanded = false,
    this.isInitializing = false,
    this.showMiniPlayer = true,
  });

  PlayerState copyWith({
    MediaItem? currentItem,
    VideoPlayerController? videoPlayerController,
    ChewieController? chewieController,
    ja.AudioPlayer? audioPlayer,
    bool? isPlaying,
    bool? isMuted,
    double? volume,
    String? error,
    bool? isExpanded,
    bool? isInitializing,
    bool? showMiniPlayer,
  }) {
    return PlayerState(
      currentItem: currentItem ?? this.currentItem,
      videoPlayerController:
          videoPlayerController ?? this.videoPlayerController,
      chewieController: chewieController ?? this.chewieController,
      audioPlayer: audioPlayer ?? this.audioPlayer,
      isPlaying: isPlaying ?? this.isPlaying,
      isMuted: isMuted ?? this.isMuted,
      volume: volume ?? this.volume,
      error: error ?? this.error,
      isExpanded: isExpanded ?? this.isExpanded,
      isInitializing: isInitializing ?? this.isInitializing,
      showMiniPlayer: showMiniPlayer ?? this.showMiniPlayer,
    );
  }
}

class _PausedVideoPosition {
  const _PausedVideoPosition(
    this.controller,
    this.sessionId,
    this.positionIntentId,
    this.position, {
    this.recoveryTiming,
  });

  final VideoPlayerController controller;
  final int sessionId;
  final int positionIntentId;
  final Duration position;
  final _VideoResumeTiming? recoveryTiming;
}

class _VideoResumeTiming {
  _VideoResumeTiming(this.maximumSpeed, this.speedIntentId);

  final clock = Stopwatch();
  double maximumSpeed;
  final int speedIntentId;
}

class _VideoResumeRecovery {
  _VideoResumeRecovery(this.target, this.timing);

  final _PausedVideoPosition target;
  final _VideoResumeTiming timing;
  bool isValid = true;
}

@riverpod
class PlayerNotifier extends _$PlayerNotifier {
  int _playSessionId = 0;
  int _transportIntentId = 0;
  int _videoPositionIntentId = 0;
  int _videoSpeedIntentId = 0;
  _PausedVideoPosition? _pausedVideoPosition;
  _PausedVideoPosition? _pendingVideoPosition;
  _PausedVideoPosition? _pendingVideoCorrection;
  _VideoResumeRecovery? _videoResumeRecovery;
  final _videoSeekTails = Expando<Future<void>>();
  Object? _playbackOwner;
  SoundService? _soundService;
  Object? _soundPlaybackOwner;
  StreamSubscription<ja.PlayerState>? _audioPlayerStateSubscription;
  StreamSubscription<void>? _becomingNoisySubscription;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;
  bool _isAudioSessionConfigured = false;
  bool _isAutoAdvancingAudio = false;
  bool _isAutoAdvancingVideo = false;
  List<MediaItem>? _currentPlaylist;

  /// 現在の再生対象一覧。ミニプレイヤーから展開したビューアーにも
  /// 同じページ送り対象を引き継ぐために公開する。
  List<MediaItem>? get currentPlaylist => _currentPlaylist;

  @override
  PlayerState build() {
    final initialState = PlayerState();
    var lastState = initialState;
    listenSelf((previous, next) => lastState = next);
    // 動画再生中にアプリがバックグラウンドへ移行した場合は自動で一時停止
    ref.listen<AppLifecycleStatus>(appLifecycleProvider, (prev, next) {
      if (next == AppLifecycleStatus.background ||
          next == AppLifecycleStatus.inactive) {
        final current = state.currentItem;
        if (current != null && current.isVideo && state.isPlaying) {
          AppLogger.i(LogTag.lifecycle, '動画再生中にアプリがバックグラウンドに移行したため一時停止します');
          unawaited(pause());
        }
      }
    });

    ref.onDispose(() {
      // Ref/state access is invalid during Riverpod 3 disposal.
      _playSessionId++;
      _invalidateVideoTransport();
      final vpc = lastState.videoPlayerController;
      final cc = lastState.chewieController;
      final ap = lastState.audioPlayer;
      final soundOwner = _soundPlaybackOwner;
      final soundService = _soundService;
      final sub = _audioPlayerStateSubscription;
      final noisySub = _becomingNoisySubscription;
      final interruptSub = _interruptionSubscription;
      _audioPlayerStateSubscription = null;
      _becomingNoisySubscription = null;
      _interruptionSubscription = null;
      _isAudioSessionConfigured = false;
      _isAutoAdvancingAudio = false;
      _isAutoAdvancingVideo = false;
      _currentPlaylist = null;
      vpc?.removeListener(_videoPlayerListener);
      unawaited(() async {
        await sub?.cancel();
        await noisySub?.cancel();
        await interruptSub?.cancel();
        await _disposePlayback(vpc, cc, ap);
        if (soundOwner != null) {
          soundService?.resumeAfterMediaPlayback(soundOwner);
        }
      }());
    });
    return initialState;
  }

  Future<void> _initAudioSession() async {
    if (_isAudioSessionConfigured) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      _becomingNoisySubscription?.cancel();
      _becomingNoisySubscription = session.becomingNoisyEventStream.listen((_) {
        AppLogger.i(LogTag.app, 'イヤホン抜去（Becoming Noisy）を検知したため自動一時停止します');
        unawaited(pause());
      });

      _interruptionSubscription?.cancel();
      _interruptionSubscription = session.interruptionEventStream.listen((
        event,
      ) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              if (state.audioPlayer != null) {
                unawaited(state.audioPlayer!.setVolume(state.volume * 0.5));
              }
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              AppLogger.i(LogTag.app, '割り込み検知のため自動一時停止します');
              unawaited(pause());
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              if (state.audioPlayer != null) {
                unawaited(
                  state.audioPlayer!.setVolume(
                    state.isMuted ? 0 : state.volume,
                  ),
                );
              }
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });
      _isAudioSessionConfigured = true;
    } catch (e, st) {
      AppLogger.w(LogTag.app, 'AudioSessionの初期化に失敗しました', e, st);
    }
  }

  /// 再生開始
  Future<void> play(
    MediaItem item, {
    File? file,
    bool isExpanded = true,
    bool showMiniPlayer = true,
    List<MediaItem>? playlist,
    Object? owner,
  }) async {
    if (!item.isImportPreview &&
        item.sourceType == MediaSourceType.externalReference) {
      throw StateError('Import this reference before playback');
    }
    _invalidateVideoTransport();
    _playbackOwner = owner;
    final soundOwner = Object();
    _soundPlaybackOwner = soundOwner;
    final soundService = ref.read<SoundService>(soundServiceProvider);
    _soundService = soundService;
    final soundsReleased = soundService.suspendForMediaPlayback(soundOwner);
    if (playlist != null) {
      _currentPlaylist = playlist;
    }
    final oldVpc = state.videoPlayerController;
    final oldCc = state.chewieController;
    final oldAp = state.audioPlayer;
    final currentVolume = state.volume;
    final currentMuted = state.isMuted;
    _isAutoAdvancingAudio = false;
    _isAutoAdvancingVideo = false;
    _playSessionId += 1;
    final sessionId = _playSessionId;
    oldVpc?.removeListener(_videoPlayerListener);
    await _audioPlayerStateSubscription?.cancel();
    _audioPlayerStateSubscription = null;
    await _disposePlayback(oldVpc, oldCc, oldAp);
    await soundsReleased;
    if (sessionId != _playSessionId) return;

    state = PlayerState(
      currentItem: item,
      error: null,
      isExpanded: isExpanded,
      volume: currentVolume,
      isMuted: currentMuted,
      isInitializing: true,
      showMiniPlayer: showMiniPlayer,
    );
    await _initPlayer(item, file, sessionId);
  }

  Future<void> _initPlayer(MediaItem item, File? file, int sessionId) async {
    VideoPlayerController? vpcToDispose;
    ChewieController? ccToDispose;
    ja.AudioPlayer? apToDispose;

    try {
      final docsDirFuture = getPrivateStorageDirectory();

      if (item.isAudio) {
        await _initAudioSession();

        final privacySettings = ref.read(privacySettingsNotifierProvider).value;
        final isSecret =
            (privacySettings?.useSecretThumbnailMode ?? false) ||
            (privacySettings?.isAppLockEnabled ?? false);

        final artUriFuture = (() async {
          if (isSecret) return null;
          final coverPath = item.collection.value?.coverImagePath;
          if (coverPath == null) return null;
          final docsDir = await getPrivateStorageDirectory();
          return Uri.file(p.join(docsDir.path, coverPath));
        })();

        if (sessionId != _playSessionId) return;
        final docsDir = await docsDirFuture;
        if (sessionId != _playSessionId) return;
        final artUri = await artUriFuture;
        if (sessionId != _playSessionId) return;

        final rawTitle =
            item.collection.value?.alias ??
            p.basenameWithoutExtension(item.path);
        final displayTitle = rawTitle.replaceAll('_', ' ');

        final notificationTitle = isSecret ? '音声再生中' : displayTitle;
        final notificationAlbum = isSecret
            ? 'CharmShelf'
            : (item.collection.value?.title ?? 'CharmShelf');

        final mediaItemTag = jab.MediaItem(
          id: item.id.toString(),
          album: notificationAlbum,
          title: notificationTitle,
          artUri: isSecret ? null : artUri,
        );

        final audioPlayer = ja.AudioPlayer();
        apToDispose = audioPlayer;
        if (item.requiresSourceAccess && file == null) {
          final storageService = await ref.read(
            externalStorageServiceProvider.future,
          );
          final fileName = p.basename(
            item.originalPath.isNotEmpty ? item.originalPath : item.path,
          );
          var uri = Uri.parse(item.path);
          if (!uri.hasScheme) {
            uri = Uri.file(item.path);
          }
          final tempPath = await storageService.copyToTemp(uri, fileName);
          if (tempPath == null) {
            throw Exception('外部オーディオファイルの一時コピーに失敗しました: ${item.path}');
          }
          await audioPlayer.setFilePath(tempPath, tag: mediaItemTag);
        } else {
          var targetFile = file;
          targetFile ??= File(p.join(docsDir.path, item.path));

          if (!targetFile.existsSync()) {
            if (sessionId == _playSessionId) {
              state = state.copyWith(
                error: 'ファイルが見つかりません: ${item.path}',
                isInitializing: false,
              );
            }
            return;
          }
          try {
            await audioPlayer.setFilePath(targetFile.path, tag: mediaItemTag);
          } catch (_) {
            final audioSource = ja.AudioSource.uri(
              Uri.file(targetFile.path),
              tag: mediaItemTag,
            );
            await audioPlayer.setAudioSource(audioSource);
          }
        }
        if (sessionId != _playSessionId) {
          await _disposePlayback(null, null, audioPlayer);
          return;
        }

        await audioPlayer.setVolume(state.isMuted ? 0 : state.volume);
        if (sessionId != _playSessionId) {
          await _disposePlayback(null, null, audioPlayer);
          return;
        }

        // 再生開始前に状態を一度更新（audioPlayer インスタンスをUIに渡し、ローディングを消す）
        state = state.copyWith(audioPlayer: audioPlayer, isInitializing: false);

        _audioPlayerStateSubscription = audioPlayer.playerStateStream.listen((
          playerState,
        ) {
          // セットされた直後の初回通知も通るように、インスタンスの不一致のみをチェック
          if (sessionId != _playSessionId) return;

          state = state.copyWith(
            isPlaying:
                playerState.playing &&
                playerState.processingState != ja.ProcessingState.completed,
          );
          if (playerState.processingState == ja.ProcessingState.completed &&
              !_isAutoAdvancingAudio) {
            _isAutoAdvancingAudio = true;
            unawaited(_autoPlayNextAudio());
          }
        });

        apToDispose = null; // 正常にセットされたので破棄対象から外す

        // just_audio completes play() only when playback pauses or ends.
        unawaited(_startAudioPlayback(audioPlayer, sessionId));
      } else {
        if (sessionId != _playSessionId) return;
        final docsDir = await docsDirFuture;
        if (sessionId != _playSessionId) return;

        VideoPlayerController vpc;
        if (item.requiresSourceAccess && file == null) {
          final storageService = await ref.read(
            externalStorageServiceProvider.future,
          );
          final fileName = p.basename(
            item.originalPath.isNotEmpty ? item.originalPath : item.path,
          );
          var uri = Uri.parse(item.path);
          if (!uri.hasScheme) {
            uri = Uri.file(item.path);
          }
          final tempPath = await storageService.copyToTemp(uri, fileName);
          if (tempPath == null) {
            throw Exception('外部動画ファイルの一時コピーに失敗しました: ${item.path}');
          }
          vpc = VideoPlayerController.file(File(tempPath));
        } else if (item.requiresSourceAccess && file != null) {
          vpc = VideoPlayerController.file(file);
        } else {
          var targetFile = file;
          targetFile ??= File(p.join(docsDir.path, item.path));

          if (!targetFile.existsSync()) {
            if (sessionId == _playSessionId) {
              state = state.copyWith(
                error: 'ファイルが見つかりません: ${item.path}',
                isInitializing: false,
              );
            }
            return;
          }
          vpc = VideoPlayerController.file(targetFile);
        }

        vpcToDispose = vpc;
        await _initializeVideoController(vpc);
        if (sessionId != _playSessionId) {
          await _disposePlayback(vpc, null, null);
          return;
        }
        await vpc.setVolume(state.isMuted ? 0 : state.volume);

        final rawRatio = vpc.value.aspectRatio;
        final safeAspectRatio =
            (rawRatio <= 0.0 || rawRatio.isNaN || rawRatio.isInfinite)
            ? (16.0 / 9.0)
            : rawRatio;

        final cc = ChewieController(
          videoPlayerController: vpc,
          autoPlay: true,
          looping: false,
          showControls: false,
          aspectRatio: safeAspectRatio,
          allowPlaybackSpeedChanging: true,
          playbackSpeeds: const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
          deviceOrientationsAfterFullScreen: [DeviceOrientation.portraitUp],
          deviceOrientationsOnEnterFullScreen: [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ],
        );
        ccToDispose = cc;

        vpc.addListener(_videoPlayerListener);

        if (sessionId != _playSessionId) {
          vpc.removeListener(_videoPlayerListener);
          await _disposePlayback(vpc, cc, null);
          return;
        }
        vpcToDispose = null; // 正常にセットされたので破棄対象から外す
        ccToDispose = null;
        state = state.copyWith(
          videoPlayerController: vpc,
          chewieController: cc,
          isPlaying: vpc.value.isPlaying,
          isInitializing: false,
        );
      }
    } catch (e, st) {
      AppLogger.e(
        LogTag.app,
        'プレイヤーの初期化中にエラーが発生しました itemId=${item.id} path=${item.path}',
        e,
        st,
      );
      if (sessionId == _playSessionId) {
        state = state.copyWith(
          error: '再生の初期化に失敗しました: $e',
          isInitializing: false,
        );
      }
      await _disposePlayback(vpcToDispose, ccToDispose, apToDispose);
    }
  }

  void expand() {
    state = state.copyWith(isExpanded: true);
  }

  void collapse() {
    state = state.copyWith(isExpanded: false);
  }

  /// 画面を閉じた後も再生を継続し、ミニプレイヤーへ戻す。
  ///
  /// 画面の dispose 後に遅れて呼ばれる可能性があるため、所有者が指定
  /// されている場合は現在の再生所有者と一致する場合だけ状態を変更する。
  void minimizeToMiniPlayer({Object? owner}) {
    if (owner != null && !identical(owner, _playbackOwner)) return;
    if (state.currentItem == null) return;

    state = state.copyWith(isExpanded: false, showMiniPlayer: true);
  }

  void toggleExpansion() {
    state = state.copyWith(isExpanded: !state.isExpanded);
  }

  void _videoPlayerListener() {
    final vpc = state.videoPlayerController;
    if (vpc == null || state.isInitializing) return;

    VideoPlayerValue val;
    try {
      val = vpc.value;
    } catch (_) {
      return;
    }

    if (state.isPlaying != val.isPlaying) {
      state = state.copyWith(isPlaying: val.isPlaying);
    }
    final duration = val.duration;
    final position = val.position;
    if (_isAutoAdvancingVideo ||
        val.isPlaying ||
        duration <= Duration.zero ||
        position < duration ||
        state.currentItem == null ||
        !state.currentItem!.isVideo) {
      return;
    }
    _isAutoAdvancingVideo = true;
    unawaited(_autoPlayNextVideo());
  }

  /// 一時停止
  Future<void> pause() async {
    if (!ref.mounted) return;
    final intentId = ++_transportIntentId;
    final sessionId = _playSessionId;
    final vpc = state.videoPlayerController;
    final ap = state.audioPlayer;
    final pendingTarget = _currentPendingVideoPosition(includeRecovery: true);
    // Only active playback time belongs in a later forward-progress allowance.
    pendingTarget?.recoveryTiming?.clock.stop();
    _pausedVideoPosition = null;
    if (vpc != null) {
      final value = vpc.value;
      final position = pendingTarget?.position ?? value.position;
      if (value.isInitialized &&
          !value.hasError &&
          (pendingTarget != null || !value.isCompleted) &&
          value.duration > Duration.zero &&
          position >= Duration.zero &&
          position < value.duration) {
        _pausedVideoPosition = _PausedVideoPosition(
          vpc,
          sessionId,
          _videoPositionIntentId,
          position,
          recoveryTiming: pendingTarget?.recoveryTiming,
        );
      }
      await vpc.pause();
      if (!_isCurrentTransport(intentId, sessionId, vpc, ap)) return;
    }
    if (ap != null) {
      await ap.pause();
      if (!_isCurrentTransport(intentId, sessionId, vpc, ap)) return;
    }
    if (!_isCurrentTransport(intentId, sessionId, vpc, ap)) return;
    state = state.copyWith(isPlaying: false);
  }

  Future<void> _startAudioPlayback(
    ja.AudioPlayer player,
    int sessionId, {
    int? transportIntentId,
  }) async {
    try {
      await player.play();
    } catch (e) {
      AppLogger.e(LogTag.app, '再生開始に失敗しました', e);
      if (ref.mounted &&
          sessionId == _playSessionId &&
          identical(state.audioPlayer, player) &&
          (transportIntentId == null ||
              transportIntentId == _transportIntentId)) {
        state = state.copyWith(error: '再生開始に失敗しました: $e', isPlaying: false);
      }
    }
  }

  /// 再開
  Future<void> resume() async {
    if (!ref.mounted) return;
    final intentId = ++_transportIntentId;
    final sessionId = _playSessionId;
    final vpc = state.videoPlayerController;
    final ap = state.audioPlayer;
    if (vpc != null) {
      final value = vpc.value;
      final wasCompleted =
          value.isCompleted ||
          (value.duration > Duration.zero && value.position >= value.duration);
      final bookmark = _pausedVideoPosition;
      final recovery = _beginVideoResumeRecovery(
        vpc,
        value,
        bookmark,
        wasCompleted,
      );
      final speedIntentId =
          recovery?.timing.speedIntentId ?? _videoSpeedIntentId;
      final resumeClock = recovery?.timing.clock ?? (Stopwatch()..start());
      try {
        await vpc.play();
        if (!_isCurrentTransport(intentId, sessionId, vpc, ap)) return;
        final hasPendingTarget = _currentPendingVideoPosition() != null;
        if (!wasCompleted &&
            !hasPendingTarget &&
            bookmark != null &&
            bookmark.sessionId == sessionId &&
            bookmark.positionIntentId == _videoPositionIntentId &&
            identical(bookmark.controller, vpc)) {
          Duration? nativePosition;
          try {
            nativePosition = await vpc.position.timeout(
              const Duration(seconds: 1),
            );
          } catch (_) {
            // An unavailable native position cannot justify a corrective seek.
          }
          final sampleElapsedUs = resumeClock.elapsedMicroseconds;
          if (!_isCurrentTransport(intentId, sessionId, vpc, ap)) return;
          final current = vpc.value;
          const toleranceUs = 500000;
          final positionDeltaUs = nativePosition == null
              ? 0
              : nativePosition.inMicroseconds -
                    bookmark.position.inMicroseconds;
          var jumpedForward = false;
          final beforeSpeed =
              recovery?.timing.maximumSpeed ?? value.playbackSpeed;
          final afterSpeed = current.playbackSpeed;
          if (speedIntentId == _videoSpeedIntentId &&
              beforeSpeed.isFinite &&
              afterSpeed.isFinite &&
              beforeSpeed > 0 &&
              afterSpeed > 0) {
            final maximumSpeed = beforeSpeed > afterSpeed
                ? beforeSpeed
                : afterSpeed;
            final forwardAllowanceUs =
                sampleElapsedUs * maximumSpeed + toleranceUs;
            // Unknown/overflowed rates cannot justify rewinding normal progress.
            jumpedForward =
                forwardAllowanceUs.isFinite &&
                positionDeltaUs > forwardAllowanceUs;
          }
          if (nativePosition != null &&
              nativePosition >= Duration.zero &&
              nativePosition <= current.duration &&
              current.isInitialized &&
              !current.hasError &&
              current.duration > Duration.zero &&
              bookmark.position < current.duration &&
              (positionDeltaUs < -toleranceUs || jumpedForward)) {
            await _seekVideoInOrder(
              vpc,
              bookmark.position,
              sessionId,
              bookmark.positionIntentId,
              transportIntentId: intentId,
              recovery: recovery,
            );
            if (!_isCurrentTransport(intentId, sessionId, vpc, ap)) return;
          }
        }
        _pausedVideoPosition = null;
      } finally {
        // Owners are unique even when successive resumes retain the same target.
        recovery?.isValid = false;
        if (recovery != null && identical(_videoResumeRecovery, recovery)) {
          _videoResumeRecovery = null;
        }
      }
    }
    if (ap != null) {
      if (ap.processingState == ja.ProcessingState.completed) {
        await ap.seek(Duration.zero);
        if (!_isCurrentTransport(intentId, sessionId, vpc, ap)) return;
      }
      unawaited(
        _startAudioPlayback(ap, sessionId, transportIntentId: intentId),
      );
    }
    if (!_isCurrentTransport(intentId, sessionId, vpc, ap)) return;
    state = state.copyWith(isPlaying: true);
  }

  void _invalidateVideoTransport() {
    _transportIntentId++;
    _videoPositionIntentId++;
    _videoResumeRecovery?.timing.clock.stop();
    _pausedVideoPosition?.recoveryTiming?.clock.stop();
    _pendingVideoCorrection?.recoveryTiming?.clock.stop();
    _pausedVideoPosition = null;
    _pendingVideoPosition = null;
    _pendingVideoCorrection = null;
    _videoResumeRecovery?.isValid = false;
    _videoResumeRecovery = null;
  }

  bool _isCurrentTransport(
    int intentId,
    int sessionId,
    VideoPlayerController? vpc,
    ja.AudioPlayer? ap,
  ) {
    return ref.mounted &&
        intentId == _transportIntentId &&
        sessionId == _playSessionId &&
        identical(state.videoPlayerController, vpc) &&
        identical(state.audioPlayer, ap);
  }

  bool _isCurrentVideoPosition(
    VideoPlayerController vpc,
    int sessionId,
    int positionIntentId,
  ) {
    return ref.mounted &&
        sessionId == _playSessionId &&
        positionIntentId == _videoPositionIntentId &&
        identical(state.videoPlayerController, vpc);
  }

  _VideoResumeRecovery? _beginVideoResumeRecovery(
    VideoPlayerController vpc,
    VideoPlayerValue value,
    _PausedVideoPosition? bookmark,
    bool wasCompleted,
  ) {
    if (wasCompleted ||
        bookmark == null ||
        !identical(bookmark.controller, vpc) ||
        !_isCurrentVideoPosition(
          vpc,
          bookmark.sessionId,
          bookmark.positionIntentId,
        ) ||
        bookmark.position < Duration.zero ||
        bookmark.position >= value.duration) {
      _videoResumeRecovery = null;
      return null;
    }
    final previous = _videoResumeRecovery;
    final inheritsWindow =
        previous != null &&
        previous.isValid &&
        identical(previous.target.controller, vpc) &&
        previous.target.sessionId == bookmark.sessionId &&
        previous.target.positionIntentId == bookmark.positionIntentId &&
        previous.target.position == bookmark.position;
    final beforeSpeed = value.playbackSpeed;
    final timing =
        (inheritsWindow ? previous.timing : bookmark.recoveryTiming) ??
        _VideoResumeTiming(beforeSpeed, _videoSpeedIntentId);
    final previousSpeed = timing.maximumSpeed;
    timing.maximumSpeed =
        beforeSpeed.isFinite &&
            previousSpeed.isFinite &&
            beforeSpeed > 0 &&
            previousSpeed > 0
        ? (beforeSpeed > previousSpeed ? beforeSpeed : previousSpeed)
        : double.nan;
    final target = _PausedVideoPosition(
      vpc,
      bookmark.sessionId,
      bookmark.positionIntentId,
      bookmark.position,
      recoveryTiming: timing,
    );
    // Continue a handed-off active-time budget without counting paused time.
    timing.clock.start();
    final recovery = _VideoResumeRecovery(target, timing);
    _videoResumeRecovery = recovery;
    return recovery;
  }

  _PausedVideoPosition? _currentPendingVideoPosition({
    bool includeRecovery = false,
  }) {
    // A new explicit user target takes precedence over an issued correction.
    final recovery = _videoResumeRecovery;
    for (final target in [
      _pendingVideoPosition,
      _pendingVideoCorrection,
      if (includeRecovery && recovery != null && recovery.isValid)
        recovery.target,
      if (includeRecovery) _pausedVideoPosition,
    ]) {
      if (target != null &&
          _isCurrentVideoPosition(
            target.controller,
            target.sessionId,
            target.positionIntentId,
          )) {
        return target;
      }
    }
    return null;
  }

  Future<void> _seekVideoInOrder(
    VideoPlayerController vpc,
    Duration position,
    int sessionId,
    int positionIntentId, {
    int? transportIntentId,
    _VideoResumeRecovery? recovery,
  }) async {
    final previous = _videoSeekTails[vpc];
    final finished = Completer<void>();
    _videoSeekTails[vpc] = finished.future;
    _PausedVideoPosition? correction;
    try {
      // An issued native seek cannot be cancelled. Keep a later user seek after
      // its completion, while unrelated controllers retain their own queue.
      if (previous != null) await previous;
      if (!_isCurrentVideoPosition(vpc, sessionId, positionIntentId) ||
          (transportIntentId != null &&
              transportIntentId != _transportIntentId)) {
        return;
      }
      if (transportIntentId != null) {
        correction = _PausedVideoPosition(
          vpc,
          sessionId,
          positionIntentId,
          position,
          recoveryTiming: recovery?.timing,
        );
        _pendingVideoCorrection = correction;
      }
      await vpc.seekTo(position);
    } catch (_) {
      recovery?.isValid = false;
      final paused = _pausedVideoPosition;
      if (correction != null &&
          identical(_pendingVideoCorrection, correction) &&
          _isCurrentVideoPosition(vpc, sessionId, positionIntentId) &&
          paused != null &&
          identical(paused.controller, vpc) &&
          paused.sessionId == sessionId &&
          paused.positionIntentId == positionIntentId &&
          paused.position == position) {
        // A pause may have retained this in-flight correction's target. It
        // cannot be treated as a successfully restored position after failure.
        _pausedVideoPosition = null;
      }
      rethrow;
    } finally {
      if (correction != null &&
          identical(_pendingVideoCorrection, correction)) {
        _pendingVideoCorrection = null;
      }
      finished.complete();
      if (identical(_videoSeekTails[vpc], finished.future)) {
        _videoSeekTails[vpc] = null;
      }
    }
  }

  /// 停止とリソース解放
  Future<void> stop({Object? owner}) async {
    // A route may finish disposing after another viewer has started playback.
    if (owner != null && !identical(owner, _playbackOwner)) return;
    _invalidateVideoTransport();
    _playbackOwner = null;
    final soundOwner = _soundPlaybackOwner;
    _soundPlaybackOwner = null;
    _isAutoAdvancingAudio = false;
    _isAutoAdvancingVideo = false;
    _playSessionId += 1;
    final vpc = state.videoPlayerController;
    final cc = state.chewieController;
    final ap = state.audioPlayer;

    final playerSub = _audioPlayerStateSubscription;
    _audioPlayerStateSubscription = null;
    vpc?.removeListener(_videoPlayerListener);

    final noisySub = _becomingNoisySubscription;
    final interruptSub = _interruptionSubscription;
    _becomingNoisySubscription = null;
    _interruptionSubscription = null;
    _isAudioSessionConfigured = false;
    state = PlayerState();
    await playerSub?.cancel();
    await noisySub?.cancel();
    await interruptSub?.cancel();
    await _disposePlayback(vpc, cc, ap);
    if (soundOwner != null) {
      _soundService?.resumeAfterMediaPlayback(soundOwner);
    }
  }

  /// シーク
  Future<void> seek(Duration duration) async {
    final vpc = state.videoPlayerController;
    final ap = state.audioPlayer;
    if (vpc != null) {
      final newPosition = vpc.value.position + duration;
      await seekVideoTo(newPosition, expectedController: vpc);
    }
    if (ap != null) {
      final newPosition = (ap.position) + duration;
      await ap.seek(_boundedPosition(newPosition, ap.duration));
    }
  }

  /// 動画の絶対位置シーク。古いビューアーの操作は現在の再生に影響させない。
  Future<void> seekVideoTo(
    Duration position, {
    VideoPlayerController? expectedController,
  }) async {
    if (!ref.mounted) return;
    final vpc = state.videoPlayerController;
    if (vpc == null ||
        (expectedController != null && !identical(expectedController, vpc))) {
      return;
    }
    _invalidateVideoTransport();
    final target = _PausedVideoPosition(
      vpc,
      _playSessionId,
      _videoPositionIntentId,
      _boundedPosition(position, vpc.value.duration),
    );
    _pendingVideoPosition = target;
    try {
      await _seekVideoInOrder(
        vpc,
        target.position,
        target.sessionId,
        target.positionIntentId,
      );
    } catch (_) {
      if (_isCurrentVideoPosition(
        vpc,
        target.sessionId,
        target.positionIntentId,
      )) {
        _pausedVideoPosition = null;
      }
      rethrow;
    } finally {
      if (identical(_pendingVideoPosition, target)) {
        _pendingVideoPosition = null;
      }
    }
  }

  /// 秒単位で指定
  Future<void> skip(Duration duration) async {
    await seek(duration);
  }

  /// 最初に戻る
  Future<void> seekToStart() async {
    final vpc = state.videoPlayerController;
    final ap = state.audioPlayer;
    if (vpc != null) {
      await seekVideoTo(Duration.zero, expectedController: vpc);
    }
    if (ap != null) {
      await ap.seek(Duration.zero);
    }
  }

  Future<void> playPreviousItem() async {
    final vpc = state.videoPlayerController;
    final ap = state.audioPlayer;

    const threshold = Duration(seconds: 3);
    var shouldSeekToStart = false;

    if (vpc != null && vpc.value.position > threshold) {
      shouldSeekToStart = true;
    } else if (ap != null && ap.position > threshold) {
      shouldSeekToStart = true;
    }

    if (shouldSeekToStart) {
      await seekToStart();
    } else {
      await _playAdjacentItem(forward: false);
    }
  }

  Future<void> playNextItem() async {
    await _playAdjacentItem(forward: true);
  }

  /// 最後へ
  Future<void> seekToEnd() async {
    final vpc = state.videoPlayerController;
    final ap = state.audioPlayer;
    if (vpc != null) {
      await seekVideoTo(vpc.value.duration, expectedController: vpc);
    }
    if (ap != null) {
      if (ap.duration != null) {
        await ap.seek(ap.duration!);
      }
    }
  }

  /// 再生速度の変更
  Future<void> setPlaybackSpeed(double speed) async {
    final vpc = state.videoPlayerController;
    final ap = state.audioPlayer;
    if (vpc != null) {
      // A transient faster rate may not appear in the resume endpoint samples.
      _videoSpeedIntentId++;
      await vpc.setPlaybackSpeed(speed);
    }
    if (ap != null) {
      await ap.setSpeed(speed);
    }
  }

  /// ミュート切り替え
  Future<void> toggleMute() async {
    final vpc = state.videoPlayerController;
    final ap = state.audioPlayer;
    final newMuted = !state.isMuted;

    if (vpc != null) {
      await vpc.setVolume(newMuted ? 0 : state.volume);
    }
    if (ap != null) {
      await ap.setVolume(newMuted ? 0 : state.volume);
    }

    state = state.copyWith(isMuted: newMuted);
  }

  /// 音量設定 (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    final vpc = state.videoPlayerController;
    final ap = state.audioPlayer;
    if (vpc != null) {
      await vpc.setVolume(state.isMuted ? 0 : volume);
    }
    if (ap != null) {
      await ap.setVolume(state.isMuted ? 0 : volume);
    }
    state = state.copyWith(volume: volume);
  }

  Future<void> setVolumeFromSlider(double volume) async {
    final normalized = volume.clamp(0.0, 1.0);
    final shouldUnmute = state.isMuted && normalized > 0;
    final nextMuted = shouldUnmute ? false : state.isMuted;
    final vpc = state.videoPlayerController;
    final ap = state.audioPlayer;
    final appliedVolume = nextMuted ? 0.0 : normalized;

    if (vpc != null) {
      await vpc.setVolume(appliedVolume);
    }
    if (ap != null) {
      await ap.setVolume(appliedVolume);
    }
    state = state.copyWith(volume: normalized, isMuted: nextMuted);
  }

  /// 指定したメディアアイテムが再生中かどうか
  bool isPlayingItem(MediaItem item) {
    return state.currentItem?.id == item.id && state.isPlaying;
  }

  /// 動画のサムネイルプレビューを生成する
  /// 保存は行わず、生成された一時ファイルの相対パスを返す
  Future<Result<String, AppError>> generateVideoThumbnailPreview(
    int positionMs,
  ) async {
    final item = state.currentItem;
    if (item == null || item.isImportPreview) {
      return Result.failure(AppError.unknown('Item not found'));
    }
    if (!item.isVideo) {
      return Result.failure(
        AppError.unknown('Thumbnail preview is only supported for video items'),
      );
    }

    String? copiedTempPath;
    try {
      final docsDir = await getPrivateStorageDirectory();
      File sourceFile;
      if (item.requiresSourceAccess) {
        final storageService = await ref.read(
          externalStorageServiceProvider.future,
        );
        var uri = Uri.parse(item.path);
        if (!uri.hasScheme) {
          uri = Uri.file(item.path);
        }
        copiedTempPath = await storageService.copyToTemp(
          uri,
          p.basename(item.path),
        );
        if (copiedTempPath == null) {
          return Result.failure(AppError.file('外部動画の一時コピーに失敗しました'));
        }
        sourceFile = File(copiedTempPath);
      } else {
        sourceFile = File(p.join(docsDir.path, item.path));
      }

      if (!sourceFile.existsSync()) {
        return Result.failure(AppError.file('動画ファイルが見つかりません: ${item.path}'));
      }

      final fileService = ref.read(fileServiceProvider);
      return await fileService.generateThumbnail(
        sourceFile,
        timeMs: positionMs,
      );
    } catch (e, st) {
      return Result.failure(
        AppError.unknown(
          e.toString(),
          original: e,
          stackTrace: st,
          context: 'PlayerNotifier.generateVideoThumbnailPreview',
        ),
      );
    } finally {
      if (copiedTempPath != null) {
        try {
          final tempDir = await getTemporaryDirectory();
          if (p.isWithin(tempDir.path, copiedTempPath)) {
            final tempFile = File(copiedTempPath);
            if (tempFile.existsSync()) {
              await tempFile.delete();
            }
          }
        } catch (e, st) {
          // 一時ファイルの削除失敗は再生動作自体に影響しないため警告ログのみ記録し処理を継続
          AppLogger.w(LogTag.app, '一時ファイルの削除に失敗しました: $copiedTempPath', e, st);
        }
      }
    }
  }

  /// サムネイルの更新（指定されたパスをサムネイルとして保存）
  Future<Result<void, AppError>> updateThumbnailWithPath(
    String newThumbnailPath,
  ) async {
    final item = state.currentItem;
    if (item == null || item.isImportPreview) {
      return Result.failure(AppError.unknown('Item not found'));
    }

    try {
      final repository = await ref.read(mediaRepositoryProvider.future);
      final docsDir = await getPrivateStorageDirectory();
      final oldThumbnailPath = item.thumbnailPath;

      item
        ..thumbnailPath = newThumbnailPath
        ..updatedAt = DateTime.now();

      final saveResult = await repository.save(item);
      if (saveResult.isFailure) {
        return saveResult;
      }

      // 関連するコレクションのカバー画像を更新
      // 1. アイテム自体がカタログ（単一ファイルカタログ）の場合
      final selfCollectionResult = await repository.getCollectionByPath(
        item.path,
      );
      final selfCollection = selfCollectionResult.dataOrNull;
      if (selfCollection != null) {
        selfCollection.coverImagePath = newThumbnailPath;
        await repository.saveCollection(selfCollection);
        ref.invalidate(collectionNotifierProvider(item.path));
      }

      // 2. 親フォルダがカタログで、かつ現在のアイテムがカバー画像として設定されている場合
      if (item.parentPath != null && item.parentPath!.isNotEmpty) {
        final parentCollectionResult = await repository.getCollectionByPath(
          item.parentPath!,
        );
        final parentCollection = parentCollectionResult.dataOrNull;
        if (parentCollection != null &&
            parentCollection.coverImagePath == oldThumbnailPath) {
          parentCollection.coverImagePath = newThumbnailPath;
          await repository.saveCollection(parentCollection);
          ref.invalidate(collectionNotifierProvider(item.parentPath!));
        }
      }

      // 古いサムネイルの削除
      if (oldThumbnailPath != null && oldThumbnailPath != newThumbnailPath) {
        final oldThumbnailFile = File(p.join(docsDir.path, oldThumbnailPath));
        if (oldThumbnailFile.existsSync()) {
          try {
            await oldThumbnailFile.delete();
          } catch (e) {
            AppLogger.w(LogTag.ui, 'Failed to delete old thumbnail: $e');
          }
        }
      }

      // 状態の更新とプロバイダーの無効化
      state = state.copyWith(currentItem: item);

      // 関連するプロバイダーを無効化してUIを更新
      ref.invalidate(mediaItemProvider(item.id));
      ref.invalidate(libraryViewModelProvider);
      ref.invalidate(collectionNotifierProvider(item.path));
      // 外部参照の場合はフォルダアイテムも更新
      if (item.requiresSourceAccess) {
        final parentPath = item.parentPath;
        if (parentPath != null) {
          ref.invalidate(externalFolderItemsProvider(parentPath));
        }
      }

      return Result.success(null);
    } catch (e, st) {
      return Result.failure(
        AppError.unknown(
          e.toString(),
          original: e,
          stackTrace: st,
          context: 'PlayerNotifier.updateThumbnailWithPath',
        ),
      );
    }
  }

  /// サムネイルの更新（レガシー互換用: 直接位置を指定して更新）
  Future<Result<void, AppError>> updateThumbnail(int positionMs) async {
    final previewResult = await generateVideoThumbnailPreview(positionMs);
    return await previewResult.when(
      success: (path) => updateThumbnailWithPath(path),
      failure: (error) => Result.failure(error),
    );
  }

  /// サムネイル情報の同期（内部用）
  void syncThumbnail(MediaItem item) {
    if (state.currentItem?.id == item.id) {
      state = state.copyWith(currentItem: item);
    }
  }

  Duration _boundedPosition(Duration target, Duration? total) {
    if (target < Duration.zero) return Duration.zero;
    if (total != null && total > Duration.zero && target > total) return total;
    return target;
  }

  Future<void> _playAdjacentItem({required bool forward}) async {
    final sessionId = _playSessionId;
    final currentItem = state.currentItem;
    if (currentItem == null) return;
    final adjacent = await _findAdjacentItem(
      currentItem: currentItem,
      forward: forward,
    );
    if (sessionId != _playSessionId || adjacent == null) return;
    await play(
      adjacent,
      isExpanded: state.isExpanded,
      owner: _playbackOwner,
      showMiniPlayer: state.showMiniPlayer,
    );
  }

  Future<void> _autoPlayNextAudio() async {
    try {
      final sessionId = _playSessionId;
      final currentItem = state.currentItem;
      if (currentItem == null || !currentItem.isAudio) return;
      final nextAudio = await _findAdjacentItem(
        currentItem: currentItem,
        forward: true,
      );
      if (sessionId != _playSessionId ||
          nextAudio == null ||
          !nextAudio.isAudio) {
        return;
      }
      await play(
        nextAudio,
        isExpanded: state.isExpanded,
        owner: _playbackOwner,
        showMiniPlayer: state.showMiniPlayer,
      );
    } finally {
      _isAutoAdvancingAudio = false;
    }
  }

  Future<void> _autoPlayNextVideo() async {
    try {
      final sessionId = _playSessionId;
      final currentItem = state.currentItem;
      if (currentItem == null || !currentItem.isVideo) return;
      final nextVideo = await _findAdjacentItem(
        currentItem: currentItem,
        forward: true,
      );
      if (sessionId != _playSessionId ||
          nextVideo == null ||
          !nextVideo.isVideo) {
        return;
      }
      await play(
        nextVideo,
        isExpanded: state.isExpanded,
        owner: _playbackOwner,
        showMiniPlayer: state.showMiniPlayer,
      );
    } finally {
      _isAutoAdvancingVideo = false;
    }
  }

  Future<MediaItem?> _findAdjacentItem({
    required MediaItem currentItem,
    required bool forward,
  }) async {
    // 保持されている再生キュー（プレイリスト）がある場合はそれを優先利用
    final playlist = _currentPlaylist;
    if (playlist != null && playlist.isNotEmpty) {
      final playableItems = playlist
          .where((item) => _isSamePlaybackType(item, currentItem))
          .toList(growable: false);
      final currentIndex = playableItems.indexWhere(
        (item) => item.id == currentItem.id,
      );
      if (currentIndex >= 0) {
        final targetIndex = forward ? currentIndex + 1 : currentIndex - 1;
        if (targetIndex >= 0 && targetIndex < playableItems.length) {
          return playableItems[targetIndex];
        }
      }
    }

    final mode = _modeFromSourceType(currentItem.sourceType);
    final currentFilter = ref.read(mediaFilterNotifierProvider(mode));
    final isRoot = _isRootLevel(currentItem.parentPath);
    final repository = await ref.read(mediaRepositoryProvider.future);
    final result = await repository.getAll(
      filter: MediaFilter(
        parentPath: isRoot ? null : currentItem.parentPath,
        rootOnly: isRoot,
        sourceType: currentItem.sourceType,
        mediaTypes: const [MediaType.file],
        isArchived: false,
        isHidden: currentFilter.isHidden,
        sortOrder: currentFilter.sortOrder,
      ),
    );

    MediaItem? adjacentItem;
    result.when(
      success: (items) {
        final playableItems = items
            .where((item) => _isSamePlaybackType(item, currentItem))
            .toList(growable: false);
        final currentIndex = playableItems.indexWhere(
          (item) => item.id == currentItem.id,
        );
        if (currentIndex < 0) return;
        final targetIndex = forward ? currentIndex + 1 : currentIndex - 1;
        if (targetIndex < 0 || targetIndex >= playableItems.length) return;
        adjacentItem = playableItems[targetIndex];
      },
      failure: (_) {},
    );
    return adjacentItem;
  }

  bool _isRootLevel(String? parentPath) {
    return parentPath == null || parentPath.isEmpty;
  }

  AppMode _modeFromSourceType(MediaSourceType sourceType) {
    return sourceType == MediaSourceType.externalReference
        ? AppMode.external
        : AppMode.internal;
  }

  bool _isSamePlaybackType(MediaItem target, MediaItem current) {
    if (current.isAudio) return target.isAudio;
    if (current.isVideo) return target.isVideo;
    return target.isAudio || target.isVideo;
  }

  Future<void> _initializeVideoController(
    VideoPlayerController controller,
  ) async {
    try {
      await controller.initialize();
      return;
    } catch (e, st) {
      // 1回目の初期化失敗時は警告ログを記録し、わずかな遅延後に再試行する
      AppLogger.w(
        LogTag.app,
        'VideoPlayerController 1回目の初期化に失敗。再試行します。',
        e,
        st,
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await controller.initialize();
  }

  Future<void> _disposePlayback(
    VideoPlayerController? vpc,
    ChewieController? cc,
    ja.AudioPlayer? ap,
  ) async {
    if (vpc != null) {
      try {
        await vpc.pause();
      } catch (e, st) {
        // 解体処理中のエラーは後続の破棄処理を阻害しないよう警告ログのみ記録
        AppLogger.w(LogTag.app, 'vpc.pause 失敗', e, st);
      }
    }
    if (ap != null) {
      try {
        await ap.stop();
      } catch (e, st) {
        // 解体処理中のエラーは後続の破棄処理を阻害しないよう警告ログのみ記録
        AppLogger.w(LogTag.app, 'ap.stop 失敗', e, st);
      }
    }
    if (cc != null) {
      try {
        cc.dispose();
      } catch (e, st) {
        // 解体処理中のエラーは後続の破棄処理を阻害しないよう警告ログのみ記録
        AppLogger.w(LogTag.app, 'cc.dispose 失敗', e, st);
      }
    }
    if (vpc != null) {
      try {
        await vpc.dispose();
      } catch (e, st) {
        // 解体処理中のエラーは後続の破棄処理を阻害しないよう警告ログのみ記録
        AppLogger.w(LogTag.app, 'vpc.dispose 失敗', e, st);
      }
    }
    if (ap != null) {
      try {
        await ap.dispose();
      } catch (e, st) {
        // 解体処理中のエラーは後続の破棄処理を阻害しないよう警告ログのみ記録
        AppLogger.w(LogTag.app, 'ap.dispose 失敗', e, st);
      }
    }
  }
}
