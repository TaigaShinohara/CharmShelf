import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:private_shelf/core/feedback/sound_service.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  FakePathProviderPlatform(this.tempPath);
  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

class MockJustAudioPlatform extends JustAudioPlatform
    with MockPlatformInterfaceMixin {
  final Set<String> activePlayers = {};
  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    if (activePlayers.isNotEmpty) throw StateError('single player only');
    activePlayers.add(request.id);
    return MockAudioPlayerPlatform(request.id);
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async {
    activePlayers.remove(request.id);
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
    DisposeAllPlayersRequest request,
  ) async {
    return DisposeAllPlayersResponse();
  }
}

class MockAudioPlayerPlatform extends AudioPlayerPlatform {
  MockAudioPlayerPlatform(super.id);

  final _eventController = StreamController<PlaybackEventMessage>.broadcast();

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream =>
      _eventController.stream;

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    _eventController.add(
      PlaybackEventMessage(
        processingState: ProcessingStateMessage.ready,
        updatePosition: Duration.zero,
        updateTime: DateTime.now(),
        bufferedPosition: Duration.zero,
        duration: const Duration(milliseconds: 100),
        icyMetadata: null,
        currentIndex: 0,
        androidAudioSessionId: null,
      ),
    );
    return LoadResponse(duration: const Duration(milliseconds: 100));
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    _eventController.add(
      PlaybackEventMessage(
        processingState: ProcessingStateMessage.completed,
        updatePosition: const Duration(milliseconds: 100),
        updateTime: DateTime.now(),
        bufferedPosition: const Duration(milliseconds: 100),
        duration: const Duration(milliseconds: 100),
        icyMetadata: null,
        currentIndex: 0,
        androidAudioSessionId: null,
      ),
    );
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    return PauseResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async {
    return SetVolumeResponse();
  }

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async {
    return SetSpeedResponse();
  }

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async {
    return SetPitchResponse();
  }

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async {
    return SetLoopModeResponse();
  }

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async {
    return SetShuffleModeResponse();
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    return SeekResponse();
  }

  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(
    SetAndroidAudioAttributesRequest request,
  ) async {
    return SetAndroidAudioAttributesResponse();
  }

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    await _eventController.close();
    return DisposeResponse();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SoundService', () {
    late SoundService service;
    late MockJustAudioPlatform platform;
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('sound_service_test_');
      PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
      JustAudioPlatform.instance = platform = MockJustAudioPlatform();
      service = SoundService();
    });

    tearDown(() async {
      await service.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('アセットが存在しない環境でもplayが例外なく完了する', () async {
      await expectLater(service.play(SoundType.tap), completes);
      await expectLater(service.play(SoundType.success), completes);
      await expectLater(service.play(SoundType.error), completes);
    });

    test('メディア開始前に効果音を解放し古い再生の終了では抑制を解除しない', () async {
      await service.play(SoundType.success);
      expect(platform.activePlayers, hasLength(1));
      final firstOwner = Object();
      final nextOwner = Object();
      await service.suspendForMediaPlayback(firstOwner);
      expect(platform.activePlayers, isEmpty);
      await service.play(SoundType.error);
      expect(platform.activePlayers, isEmpty);
      await service.suspendForMediaPlayback(nextOwner);
      service.resumeAfterMediaPlayback(firstOwner);
      await service.play(SoundType.tap);
      expect(platform.activePlayers, isEmpty);
      service.resumeAfterMediaPlayback(nextOwner);
      await service.play(SoundType.success);
      expect(platform.activePlayers, hasLength(1));
    });

    test('setVolumeで音量を安全に設定できる', () {
      expect(() => service.setVolume(0.8), returnsNormally);
      expect(() => service.setVolume(-0.5), returnsNormally);
      expect(() => service.setVolume(1.5), returnsNormally);
    });

    test('dispose後にplayを呼んでも安全に処理される', () async {
      await service.dispose();
      await expectLater(service.play(SoundType.success), completes);
    });
  });
}
