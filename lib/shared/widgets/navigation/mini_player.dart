import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/player_notifier.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

import 'package:private_shelf/shared/widgets/navigation/bottom_navigation_style.dart';

/// フローティングカプセル型ミニプレイヤー
///
/// ボトムナビゲーションバー上部に浮遊表示される再生バー。
/// タップまたはスワイプでフルプレイヤーに展開。
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  static const double height = 64.0;
  static const double cardHeight = 56.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentItem = ref.watch(
      playerNotifierProvider.select((s) => s.currentItem),
    );

    if (currentItem == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final navStyle = ref.watch(bottomNavigationStyleNotifierProvider);

    // 再生中の対象を識別できるよう、親カタログ名ではなくファイル名を表示する。
    final rawTitle = p.basenameWithoutExtension(currentItem.path);
    final displayTitle = rawTitle.replaceAll('_', ' ');

    final isLiquidGlass = navStyle == BottomNavigationStyle.liquidGlass;
    final outerPadding = isLiquidGlass
        ? const EdgeInsets.fromLTRB(16, 0, 16, 8)
        : const EdgeInsets.fromLTRB(8, 2, 8, 6);
    final borderRadius = BorderRadius.circular(isLiquidGlass ? 16 : 12);

    final playerError = ref.watch(
      playerNotifierProvider.select((s) => s.error),
    );

    return Semantics(
      container: true,
      label: l10n.miniPlayerSemanticsLabel(displayTitle),
      button: true,
      child: GestureDetector(
        onTap: () => _navigateToPlayer(context, ref, currentItem),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: height,
          padding: outerPadding,
          child: Material(
            elevation: 4,
            shadowColor: Theme.of(
              context,
            ).colorScheme.shadow.withValues(alpha: isDark ? 0.28 : 0.14),
            color: colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: borderRadius,
              side: BorderSide(
                color: playerError != null
                    ? colorScheme.error.withValues(alpha: 0.5)
                    : colorScheme.outlineVariant.withValues(
                        alpha: isDark ? 0.16 : 0.32,
                      ),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // メインコンテンツ
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      const SizedBox(width: 2),
                      // サムネイル（角丸8px）
                      _MiniThumbnail(item: currentItem),
                      const SizedBox(width: 12),
                      // タイトル & サブタイトル
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayTitle,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (playerError != null)
                              Text(
                                l10n.miniPlayerError(playerError),
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.error,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      // アクションボタン領域（親のタップイベントと明確に分離）
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {}, // 親の展開タップが誤爆しないように吸収
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 再生/一時停止ボタン
                            Consumer(
                              builder: (context, ref, child) {
                                final isPlaying = ref.watch(
                                  playerNotifierProvider.select(
                                    (s) => s.isPlaying,
                                  ),
                                );
                                return IconButton(
                                  tooltip: isPlaying
                                      ? l10n.tooltipPause
                                      : l10n.tooltipPlay,
                                  iconSize: 28,
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  icon: Icon(
                                    isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: colorScheme.onSurface,
                                  ),
                                  onPressed: () {
                                    if (isPlaying) {
                                      ref
                                          .read(playerNotifierProvider.notifier)
                                          .pause();
                                    } else {
                                      ref
                                          .read(playerNotifierProvider.notifier)
                                          .resume();
                                    }
                                  },
                                );
                              },
                            ),
                            // 閉じるボタン
                            IconButton(
                              tooltip: l10n.tooltipClose,
                              iconSize: 22,
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              padding: const EdgeInsets.all(8),
                              icon: Icon(
                                Icons.close_rounded,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () {
                                ref
                                    .read(playerNotifierProvider.notifier)
                                    .stop();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // 上部に配置されるプログレスバー
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _MiniProgressBar(isError: playerError != null),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToPlayer(BuildContext context, WidgetRef ref, MediaItem item) {
    ref.read(playerNotifierProvider.notifier).expand();
  }
}

class _MiniProgressBar extends ConsumerWidget {
  const _MiniProgressBar({this.isError = false});

  final bool isError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vpc = ref.watch(
      playerNotifierProvider.select((s) => s.videoPlayerController),
    );
    final ap = ref.watch(playerNotifierProvider.select((s) => s.audioPlayer));
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = isError ? colorScheme.error : colorScheme.primary;

    if (vpc != null && vpc.value.isInitialized) {
      return ValueListenableBuilder(
        valueListenable: vpc,
        builder: (context, VideoPlayerValue value, child) {
          final progress = value.duration.inMilliseconds > 0
              ? value.position.inMilliseconds / value.duration.inMilliseconds
              : 0.0;

          return RepaintBoundary(
            child: CustomPaint(
              size: const Size(double.infinity, 2.5),
              painter: _ProgressBarPainter(
                progress: progress.clamp(0.0, 1.0),
                progressColor: activeColor,
                trackColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
              ),
            ),
          );
        },
      );
    } else if (ap != null) {
      return StreamBuilder<Duration?>(
        stream: ap.positionStream,
        builder: (context, snapshot) {
          final position = snapshot.data ?? Duration.zero;
          final duration = ap.duration ?? Duration.zero;
          final progress = duration.inMilliseconds > 0
              ? position.inMilliseconds / duration.inMilliseconds
              : 0.0;

          return RepaintBoundary(
            child: CustomPaint(
              size: const Size(double.infinity, 2.5),
              painter: _ProgressBarPainter(
                progress: progress.clamp(0.0, 1.0),
                progressColor: activeColor,
                trackColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
              ),
            ),
          );
        },
      );
    }

    return const SizedBox.shrink();
  }
}

class _ProgressBarPainter extends CustomPainter {
  const _ProgressBarPainter({
    required this.progress,
    required this.progressColor,
    required this.trackColor,
  });

  final double progress;
  final Color progressColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, trackPaint);

    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width * progress, size.height),
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressBarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}

/// ミニプレイヤーのサムネイル
class _MiniThumbnail extends ConsumerWidget {
  const _MiniThumbnail({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // シークレットサムネモードの確認
    final useSecretMode = ref.watch(
      privacySettingsNotifierProvider.select(
        (s) => s.value?.useSecretThumbnailMode ?? false,
      ),
    );

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildThumbnailContent(context, ref, useSecretMode),
    );
  }

  Widget _buildThumbnailContent(
    BuildContext context,
    WidgetRef ref,
    bool? useSecretMode,
  ) {
    if (useSecretMode == true) {
      return Icon(
        item.isVideo ? Icons.videocam_rounded : Icons.music_note_rounded,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 22,
      );
    }

    final thumbPath = item.thumbnailPath ?? (item.isImage ? item.path : null);
    if (thumbPath != null) {
      final docsPath = ref.watch(appDocumentsPathSyncProvider);
      final file = File(p.join(docsPath, thumbPath));
      final ext = p.extension(file.path).toLowerCase();
      final isImageExt = {
        '.jpg',
        '.jpeg',
        '.png',
        '.gif',
        '.bmp',
        '.webp',
        '.heic',
        '.heif',
        '.tif',
        '.tiff',
      }.contains(ext);
      if (!isImageExt) {
        AppLogger.w(
          LogTag.ui,
          '[ImageDecodeTrace] mini_player skip non-image thumbnail itemId=${item.id} thumbPath=$thumbPath file=${file.path} ext=$ext',
        );
        return Icon(
          item.isVideo ? Icons.videocam_rounded : Icons.music_note_rounded,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 22,
        );
      }
      return Image.file(
        file,
        fit: BoxFit.cover,
        cacheWidth: 256,
        errorBuilder: (context, error, stackTrace) {
          AppLogger.w(
            LogTag.ui,
            '[ImageDecodeTrace] mini_player Image.file decode failed itemId=${item.id} thumbPath=$thumbPath file=${file.path} cacheWidth=256 ext=$ext',
            error,
            stackTrace,
          );
          return Icon(
            item.isVideo ? Icons.videocam_rounded : Icons.music_note_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 22,
          );
        },
      );
    }
    return Icon(
      item.isVideo ? Icons.videocam_rounded : Icons.music_note_rounded,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      size: 22,
    );
  }
}
