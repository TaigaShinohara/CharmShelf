import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:video_player/video_player.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/viewer_source_context.dart';
import 'package:private_shelf/features/library/presentation/providers/player_notifier.dart';
import 'package:private_shelf/features/library/presentation/widgets/player_common_widgets.dart';
import 'package:private_shelf/features/library/presentation/widgets/viewer/media_viewer_item_action_buttons.dart';

/// 動画・音楽の全画面で、題名・再生操作・副次ボタンを下にまとめる。
class MediaViewerPlayerOverlay extends ConsumerStatefulWidget {
  final MediaItem item;
  final String title;
  final ViewerSourceContext? sourceContext;
  final VoidCallback onBackToCatalogContents;

  const MediaViewerPlayerOverlay({
    super.key,
    required this.item,
    required this.title,
    required this.sourceContext,
    required this.onBackToCatalogContents,
  });

  @override
  ConsumerState<MediaViewerPlayerOverlay> createState() =>
      _MediaViewerPlayerOverlayState();
}

class _MediaViewerPlayerOverlayState
    extends ConsumerState<MediaViewerPlayerOverlay> {
  Timer? _volumeTimer;
  bool _showVolumeSlider = false;

  @override
  void dispose() {
    _volumeTimer?.cancel();
    super.dispose();
  }

  void _showVolumeControlWithTimer() {
    setState(() {
      _showVolumeSlider = true;
    });
    _volumeTimer?.cancel();
    _volumeTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _showVolumeSlider = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerNotifierProvider);
    final isCurrent = playerState.currentItem?.id == widget.item.id;
    final colorScheme = Theme.of(context).colorScheme;
    final audioPlayer = isCurrent ? playerState.audioPlayer : null;
    final vpc = isCurrent ? playerState.videoPlayerController : null;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        if (_showVolumeSlider)
          Positioned(
            right: 24,
            bottom: kPlayerVolumeOverlayBottomOffset,
            child: PlayerVolumeSliderOverlay(
              onVolumeChange: _showVolumeControlWithTimer,
              colorScheme: colorScheme,
            ),
          ),
        PlayerFullscreenControlPanel(
          title: widget.title,
          seekBar: _PlayerOverlaySeekBar(
            audioPlayer: audioPlayer,
            vpc: vpc,
            colorScheme: colorScheme,
          ),
          onVolumeTap: _showVolumeControlWithTimer,
          colorScheme: colorScheme,
          secondaryActions: MediaViewerItemActionButtons(
            item: widget.item,
            sourceContext: widget.sourceContext,
            onBackToCatalogContents: widget.onBackToCatalogContents,
            expanded: true,
          ),
        ),
      ],
    );
  }
}

class _PlayerOverlaySeekBar extends ConsumerWidget {
  final ja.AudioPlayer? audioPlayer;
  final VideoPlayerController? vpc;
  final ColorScheme colorScheme;

  const _PlayerOverlaySeekBar({
    this.audioPlayer,
    this.vpc,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (audioPlayer != null) {
      return StreamBuilder<Duration>(
        stream: audioPlayer!.positionStream,
        builder: (context, snapshot) {
          final position = snapshot.data ?? Duration.zero;
          final duration = audioPlayer!.duration ?? Duration.zero;
          return PlayerSeekBarContent(
            position: position,
            duration: duration,
            onChanged: (val) {
              audioPlayer!.seek(Duration(milliseconds: val.toInt()));
            },
            colorScheme: colorScheme,
          );
        },
      );
    }
    if (vpc != null) {
      return ValueListenableBuilder(
        valueListenable: vpc!,
        builder: (context, VideoPlayerValue value, child) {
          return PlayerSeekBarContent(
            position: value.position,
            duration: value.duration,
            onChanged: (val) {
              if (!context.mounted) return;
              unawaited(
                ref
                    .read(playerNotifierProvider.notifier)
                    .seekVideoTo(
                      Duration(milliseconds: val.toInt()),
                      expectedController: vpc,
                    ),
              );
            },
            colorScheme: colorScheme,
          );
        },
      );
    }
    return PlayerSeekBarContent(
      position: Duration.zero,
      duration: Duration.zero,
      onChanged: (_) {},
      colorScheme: colorScheme,
    );
  }
}
