import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/theme/app_theme.dart';
import 'package:private_shelf/features/library/presentation/providers/player_notifier.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

String formatPlayerDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (duration.inHours > 0) {
    return '${duration.inHours}:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}

class PlayerVolumeIconButton extends ConsumerWidget {
  final VoidCallback onVolumeTap;

  const PlayerVolumeIconButton({super.key, required this.onVolumeTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMuted = ref.watch(playerNotifierProvider.select((s) => s.isMuted));
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return IconButton(
      tooltip: isMuted ? l10n.tooltipUnmute : l10n.tooltipMute,
      icon: Icon(
        isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
        color: colorScheme.onSurface.withValues(alpha: 0.7),
        size: 24,
      ),
      onPressed: () {
        ref.read(playerNotifierProvider.notifier).toggleMute();
        onVolumeTap();
      },
      onLongPress: onVolumeTap,
    );
  }
}

class PlayerVolumeSliderOverlay extends ConsumerWidget {
  final VoidCallback onVolumeChange;
  final ColorScheme colorScheme;

  const PlayerVolumeSliderOverlay({
    super.key,
    required this.onVolumeChange,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(playerNotifierProvider.select((s) => s.volume));
    final isMuted = ref.watch(playerNotifierProvider.select((s) => s.isMuted));

    return Container(
      height: 180,
      width: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).appColors.overlay.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: RotatedBox(
        quarterTurns: 3,
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: colorScheme.primary,
            inactiveTrackColor: colorScheme.primary.withValues(alpha: 0.2),
            thumbColor: colorScheme.primary,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            trackHeight: 3,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            min: 0,
            max: 1,
            value: isMuted ? 0 : volume,
            onChanged: (value) {
              ref
                  .read(playerNotifierProvider.notifier)
                  .setVolumeFromSlider(value);
              onVolumeChange();
            },
          ),
        ),
      ),
    );
  }
}

class PlayerInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const PlayerInfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PlayerSeekBarContent extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<double> onChanged;
  final ColorScheme colorScheme;

  const PlayerSeekBarContent({
    super.key,
    required this.position,
    required this.duration,
    required this.onChanged,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final max = duration.inMilliseconds.toDouble();
    final current = position.inMilliseconds.toDouble().clamp(0.0, max);

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: colorScheme.primary,
            inactiveTrackColor: colorScheme.primary.withValues(alpha: 0.2),
            thumbColor: colorScheme.primary,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            trackHeight: 3,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            min: 0,
            max: max > 0 ? max : 1,
            value: max > 0 ? current : 0,
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatPlayerDuration(position),
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              Text(
                formatPlayerDuration(duration),
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 再生パネル全体の高さに合わせ、下端タップで操作が隠れないようにする余白。
const double kPlayerBottomTapGuard = 248;

/// 縦型音量スライダーを題名行の近くに置くための、下端からのオフセット。
const double kPlayerVolumeOverlayBottomOffset = 220;

class PlayerFullscreenControlPanel extends StatelessWidget {
  final String title;
  final Widget seekBar;
  final Widget? secondaryActions;
  final VoidCallback onVolumeTap;
  final ColorScheme colorScheme;

  const PlayerFullscreenControlPanel({
    super.key,
    required this.title,
    required this.seekBar,
    required this.onVolumeTap,
    required this.colorScheme,
    this.secondaryActions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainer.withValues(alpha: 0.92),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        12,
        MediaQuery.paddingOf(context).bottom + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  key: const ValueKey('player-title'),
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PlayerVolumeIconButton(onVolumeTap: onVolumeTap),
            ],
          ),
          const SizedBox(height: 8),
          seekBar,
          const SizedBox(height: 8),
          const PlayerMainControls(),
          if (secondaryActions != null) ...[
            const SizedBox(height: 4),
            SizedBox(width: double.infinity, child: secondaryActions!),
          ],
        ],
      ),
    );
  }
}

class PlayerMainControls extends ConsumerWidget {
  const PlayerMainControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(
      playerNotifierProvider.select((s) => s.isPlaying),
    );
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          iconSize: 32,
          tooltip: l10n.tooltipPreviousTrack,
          icon: Icon(Icons.skip_previous_rounded, color: colorScheme.onSurface),
          onPressed: () {
            ref.read(playerNotifierProvider.notifier).playPreviousItem();
          },
        ),
        IconButton(
          iconSize: 36,
          tooltip: l10n.tooltipRewind10,
          icon: Icon(Icons.replay_10_rounded, color: colorScheme.onSurface),
          onPressed: () {
            ref
                .read(playerNotifierProvider.notifier)
                .skip(const Duration(seconds: -10));
          },
        ),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            iconSize: 40,
            tooltip: isPlaying ? l10n.tooltipPause : l10n.tooltipPlay,
            icon: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: colorScheme.onPrimary,
            ),
            onPressed: () {
              if (isPlaying) {
                ref.read(playerNotifierProvider.notifier).pause();
              } else {
                ref.read(playerNotifierProvider.notifier).resume();
              }
            },
          ),
        ),
        IconButton(
          iconSize: 36,
          tooltip: l10n.tooltipForward10,
          icon: Icon(Icons.forward_10_rounded, color: colorScheme.onSurface),
          onPressed: () {
            ref
                .read(playerNotifierProvider.notifier)
                .skip(const Duration(seconds: 10));
          },
        ),
        IconButton(
          iconSize: 32,
          tooltip: l10n.tooltipNextTrack,
          icon: Icon(Icons.skip_next_rounded, color: colorScheme.onSurface),
          onPressed: () {
            ref.read(playerNotifierProvider.notifier).playNextItem();
          },
        ),
      ],
    );
  }
}
