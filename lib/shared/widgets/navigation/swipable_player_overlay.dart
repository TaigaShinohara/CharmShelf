import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/features/library/domain/models/viewer_source_context.dart';
import 'package:private_shelf/features/library/presentation/providers/player_notifier.dart';
import 'package:private_shelf/features/library/presentation/screens/media_viewer_screen.dart';
import 'package:private_shelf/shared/widgets/navigation/mini_player.dart';

/// YouTube風のスワイプ追従プレイヤーオーバーレイ
class SwipablePlayerOverlay extends ConsumerStatefulWidget {
  const SwipablePlayerOverlay({super.key});

  @override
  ConsumerState<SwipablePlayerOverlay> createState() =>
      _SwipablePlayerOverlayState();
}

class _SwipablePlayerOverlayState extends ConsumerState<SwipablePlayerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // currentItem のみを選択的に監視（不要なリビルドを削減）
    final currentItem = ref.watch(
      playerNotifierProvider.select((s) => s.currentItem),
    );
    final isExpanded = ref.watch(
      playerNotifierProvider.select((s) => s.isExpanded),
    );
    final showMiniPlayer = ref.watch(
      playerNotifierProvider.select((s) => s.showMiniPlayer),
    );

    if (currentItem == null) {
      return const SizedBox.shrink();
    }
    if (!isExpanded && !showMiniPlayer) {
      return const SizedBox.shrink();
    }

    // 展開状態の監視（Notifier側からの変更を反映）
    ref.listen(playerNotifierProvider.select((s) => s.isExpanded), (
      prev,
      next,
    ) {
      if (!_isDragging) {
        if (next) {
          _animateTo(1.0);
        } else {
          _animateTo(0.0);
        }
      }
    });

    // 初回表示時の状態反映
    if (isExpanded && !_controller.isAnimating && _controller.value == 0) {
      _controller.value = 1.0;
    } else if (!isExpanded &&
        !_controller.isAnimating &&
        _controller.value == 1) {
      _controller.value = 0.0;
    }

    final screenHeight = MediaQuery.of(context).size.height;
    const miniPlayerHeight = MiniPlayer.height;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final expandFactor = _controller.value;
        final currentHeight = lerpDouble(
          miniPlayerHeight,
          screenHeight,
          expandFactor,
        )!;
        final viewerOpacity = Curves.easeOut.transform(expandFactor);
        final miniOpacity = (1 - Curves.easeIn.transform(expandFactor)).clamp(
          0.0,
          1.0,
        );
        final shouldShowMini = showMiniPlayer && miniOpacity > 0.01;
        final shouldShowViewer = expandFactor > 0 || _isDragging;
        final dragTravel = (screenHeight - miniPlayerHeight).clamp(
          1.0,
          double.infinity,
        );

        // 完全展開時（expandFactor == 1.0）は、内部ビューアのジェスチャー（ピンチズーム・シーク等）と
        // 競合しないよう全体ドラッグを無効化し、上部ドラッグハンドル領域でのみ縮小ドラッグを受け付ける
        final isFullyExpanded = expandFactor >= 0.999 && !_isDragging;

        return Positioned(
          left: 0,
          right: 0,
          // 常に入力されたコンテナ（Scaffold.body）の底に配置
          bottom: 0,
          height: currentHeight,
          child: ClipRect(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // 完全展開時は、ビューア側のジェスチャーを優先するため
              // ここでのドラッグハンドルは無効化するが、背後へのタップ
              // 透過を防ぐために behavior: opaque は維持する。
              onVerticalDragStart: isFullyExpanded
                  ? null
                  : (_) {
                      _controller.stop();
                      if (!_isDragging) {
                        setState(() {
                          _isDragging = true;
                        });
                      }
                    },
              onVerticalDragUpdate: isFullyExpanded
                  ? null
                  : (details) {
                      final nextValue =
                          (_controller.value -
                                  (details.primaryDelta ?? 0) / dragTravel)
                              .clamp(0.0, 1.0);
                      _controller.value = nextValue;
                    },
              onVerticalDragEnd: isFullyExpanded
                  ? null
                  : (details) {
                      final velocity = details.primaryVelocity ?? 0;
                      final shouldExpand = velocity.abs() > 260
                          ? velocity < 0
                          : _controller.value > 0.5;
                      setState(() {
                        _isDragging = false;
                      });
                      if (shouldExpand) {
                        ref.read(playerNotifierProvider.notifier).expand();
                        _animateTo(1.0);
                      } else {
                        ref.read(playerNotifierProvider.notifier).collapse();
                        _animateTo(0.0);
                      }
                    },
              child: Material(
                elevation: _isDragging || expandFactor > 0 ? 16 : 0,
                color: Colors.transparent,
                child: RepaintBoundary(
                  child: Stack(
                    children: [
                      Offstage(
                        offstage: !shouldShowViewer,
                        child: Opacity(
                          opacity: viewerOpacity,
                          child: IgnorePointer(
                            ignoring: expandFactor < 0.5,
                            child: !shouldShowViewer
                                ? const SizedBox.shrink()
                                : OverflowBox(
                                    alignment: Alignment.topCenter,
                                    minHeight: screenHeight,
                                    maxHeight: screenHeight,
                                    child: MediaViewerScreen(
                                      key: ValueKey('viewer_${currentItem.id}'),
                                      initialItem: currentItem,
                                      embeddedInOverlay: true,
                                      sourceContext:
                                          _sourceContextForCurrentPlayer(ref),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      // 完全展開時の上部縮小用ドラッグエリア（アプリバー上部のスワイプダウンを検知）
                      if (isFullyExpanded)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 56 + MediaQuery.of(context).padding.top,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onVerticalDragStart: (_) {
                              _controller.stop();
                              setState(() {
                                _isDragging = true;
                              });
                            },
                            onVerticalDragUpdate: (details) {
                              final nextValue =
                                  (_controller.value -
                                          (details.primaryDelta ?? 0) /
                                              dragTravel)
                                      .clamp(0.0, 1.0);
                              _controller.value = nextValue;
                            },
                            onVerticalDragEnd: (details) {
                              final velocity = details.primaryVelocity ?? 0;
                              final shouldExpand = velocity.abs() > 260
                                  ? velocity < 0
                                  : _controller.value > 0.5;
                              setState(() {
                                _isDragging = false;
                              });
                              if (shouldExpand) {
                                ref
                                    .read(playerNotifierProvider.notifier)
                                    .expand();
                                _animateTo(1.0);
                              } else {
                                ref
                                    .read(playerNotifierProvider.notifier)
                                    .collapse();
                                _animateTo(0.0);
                              }
                            },
                          ),
                        ),
                      if (shouldShowMini)
                        Opacity(
                          opacity: miniOpacity,
                          child: IgnorePointer(
                            ignoring: expandFactor > 0.5,
                            child: const MiniPlayer(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _animateTo(double target) {
    final distance = (target - _controller.value).abs();
    if (distance < 0.001) return;
    final durationMs = (120 + distance * 220).round().clamp(120, 320);
    _controller.animateTo(
      target,
      duration: Duration(milliseconds: durationMs),
      curve: Curves.easeOutCubic,
    );
  }

  ViewerSourceContext? _sourceContextForCurrentPlayer(WidgetRef ref) {
    final playlist = ref.read(playerNotifierProvider.notifier).currentPlaylist;
    if (playlist == null || playlist.isEmpty) return null;
    return ViewerSourceContext.customList(playlist);
  }
}
