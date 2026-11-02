import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';

enum SoundType { tap, success, error }

class SoundService {
  final Map<SoundType, AudioPlayer> _players = {};
  final Set<SoundType> _loadedTypes = {};
  Set<String>? _availableAssets;
  double _volume = 0.5;
  bool _isDisposed = false;
  bool _isPlayingSound = false;
  Object? _mediaPlaybackOwner;
  Future<void> _pendingCleanup = Future.value();

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    for (final player in _players.values) {
      player.setVolume(_volume).catchError((_) {});
    }
  }

  String _getAssetPath(SoundType type) {
    return switch (type) {
      SoundType.tap => 'assets/sounds/tap.mp3',
      SoundType.success => 'assets/sounds/success.mp3',
      SoundType.error => 'assets/sounds/error.mp3',
    };
  }

  /// アセットが存在するか判定（初回にキャッシュ）
  Future<bool> _isAssetAvailable(String asset) async {
    if (_availableAssets != null) {
      return _availableAssets!.contains(asset);
    }
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _availableAssets = manifest.listAssets().toSet();
      return _availableAssets!.contains(asset);
    } catch (e) {
      AppLogger.d(LogTag.feedback, 'AssetManifestの読み込みをスキップしました: $e');
      return false;
    }
  }

  Future<void> play(SoundType type) async {
    if (_isDisposed || _mediaPlaybackOwner != null || _isPlayingSound) return;
    _isPlayingSound = true;
    try {
      await _playSound(type);
    } finally {
      _isPlayingSound = false;
    }
  }

  Future<void> _playSound(SoundType type) async {
    if (_isDisposed || _mediaPlaybackOwner != null) return;

    final asset = _getAssetPath(type);
    final isAvailable = await _isAssetAvailable(asset);
    if (!isAvailable) {
      AppLogger.d(LogTag.feedback, '効果音アセットが存在しないため再生をスキップしました: $asset');
      return;
    }

    if (_isDisposed || _mediaPlaybackOwner != null) return;

    try {
      var player = _players[type];
      if (player == null) {
        await _releasePlayers();
        if (_isDisposed || _mediaPlaybackOwner != null) return;
        player = AudioPlayer();
        _players[type] = player;
      }

      await player.setVolume(_volume);

      if (!_loadedTypes.contains(type)) {
        await player.setAsset(
          asset,
          tag: MediaItem(id: asset, title: 'Sound ${type.name}'),
        );
        if (_isDisposed || _mediaPlaybackOwner != null) return;
        _loadedTypes.add(type);
      } else {
        await player.seek(Duration.zero);
      }

      if (_isDisposed || _mediaPlaybackOwner != null) return;
      await player.play();
    } catch (e, st) {
      if (e.toString().contains('Loading interrupted') ||
          e.toString().contains('abort')) {
        AppLogger.d(LogTag.feedback, '効果音の再生が中断されました: $asset ($e)');
      } else {
        AppLogger.w(LogTag.feedback, '効果音の再生に失敗しました: $asset', e, st);
      }
    }
  }

  /// Background audio supports one player. Short UI sounds must yield it before
  /// a media player is created, and remain silent until that playback releases it.
  Future<void> suspendForMediaPlayback(Object owner) {
    _mediaPlaybackOwner = owner;
    return _releasePlayers();
  }

  void resumeAfterMediaPlayback(Object owner) {
    if (identical(_mediaPlaybackOwner, owner)) _mediaPlaybackOwner = null;
  }

  Future<void> _releasePlayers() {
    final players = _players.values.toList();
    _players.clear();
    _loadedTypes.clear();
    return _pendingCleanup = _pendingCleanup.then((_) async {
      for (final player in players) {
        try {
          await player.dispose();
        } catch (e) {
          AppLogger.d(LogTag.feedback, 'AudioPlayer破棄時の例外: $e');
        }
      }
    });
  }

  Future<void> dispose() async {
    _isDisposed = true;
    await _releasePlayers();
  }
}
