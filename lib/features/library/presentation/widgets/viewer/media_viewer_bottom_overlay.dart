import 'dart:async';
import 'package:flutter/material.dart';
import 'package:private_shelf/core/feedback/haptics_service.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/core/theme/app_theme.dart';
import 'package:private_shelf/features/library/domain/models/viewer_page.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_settings_provider.dart';

class MediaViewerBottomOverlay extends StatefulWidget {
  final int totalPages;
  final int currentIndex;
  final int totalFiles;
  final int currentFileIndex;
  final SplitSide? splitSide;
  final ValueChanged<int> onPageChanged;
  final ViewerPageDirection pageDirection;
  final VoidCallback? onPageDirectionChanged;

  const MediaViewerBottomOverlay({
    super.key,
    required this.totalPages,
    required this.currentIndex,
    required this.totalFiles,
    required this.currentFileIndex,
    required this.splitSide,
    required this.onPageChanged,
    this.pageDirection = ViewerPageDirection.leftToRight,
    this.onPageDirectionChanged,
  });

  @override
  State<MediaViewerBottomOverlay> createState() =>
      _MediaViewerBottomOverlayState();
}

class _MediaViewerBottomOverlayState extends State<MediaViewerBottomOverlay> {
  double? _dragValue;
  int? _lastHapticIndex;

  @override
  Widget build(BuildContext context) {
    final totalPages = widget.totalPages;
    final currentIndex = widget.currentIndex;
    final totalFiles = widget.totalFiles;
    final currentFileIndex = widget.currentFileIndex;
    final splitSide = widget.splitSide;
    if (totalPages <= 1) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final displayedPageIndex = (_dragValue ?? currentIndex.toDouble())
        .round()
        .clamp(0, totalPages - 1);
    final positionLabel = _dragValue == null
        ? l10n.viewerFilePosition(
            currentFileIndex < 0 ? 1 : currentFileIndex + 1,
            totalFiles,
          )
        : l10n.viewerPagePosition(displayedPageIndex + 1, totalPages);
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 16;
    final sliderWidth = MediaQuery.sizeOf(context).width * 0.7;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 背景とページ表示は視覚要素だけにし、その領域から始まる
          // 横スワイプを背後の PageView へ通す。
          IgnorePointer(
            child: Container(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainer.withValues(alpha: 0.92),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: bottomPadding,
                top: 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).appColors.overlay.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).appColors.border,
                          width: 0.5,
                        ),
                      ),
                      child: Semantics(
                        liveRegion: true,
                        label: positionLabel,
                        child: Text(
                          _dragValue != null
                              ? positionLabel
                              : splitSide == null
                              ? positionLabel
                              : '$positionLabel · ${splitSide == SplitSide.left ? l10n.viewerLeftPage : l10n.viewerRightPage}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: bottomPadding,
            child: SizedBox(
              width: sliderWidth,
              height: 48,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Theme.of(context).colorScheme.primary,
                  inactiveTrackColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.24),
                  thumbColor: Theme.of(context).colorScheme.primary,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  tickMarkShape: SliderTickMarkShape.noTickMark,
                  trackHeight: 2,
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                ),
                child: Directionality(
                  textDirection:
                      widget.pageDirection == ViewerPageDirection.rightToLeft
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  child: Slider(
                    key: const Key('media_viewer_page_slider'),
                    min: 0,
                    max: (totalPages - 1).toDouble(),
                    value: (_dragValue ?? currentIndex.toDouble()).clamp(
                      0.0,
                      (totalPages - 1).toDouble(),
                    ),
                    divisions: totalPages - 1,
                    semanticFormatterCallback: (value) {
                      return l10n.viewerPagePosition(
                        value.round() + 1,
                        totalPages,
                      );
                    },
                    onChangeStart: (value) {
                      setState(() {
                        _dragValue = value;
                        _lastHapticIndex = value.round();
                      });
                    },
                    onChanged: (value) {
                      final hapticIndex = value.round();
                      if (_lastHapticIndex != hapticIndex) {
                        unawaited(HapticsService.selection());
                        _lastHapticIndex = hapticIndex;
                      }
                      setState(() => _dragValue = value);
                    },
                    onChangeEnd: (value) {
                      final newIndex = value.round();
                      setState(() {
                        _dragValue = null;
                        _lastHapticIndex = null;
                      });
                      if (newIndex != currentIndex) {
                        widget.onPageChanged(newIndex);
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
          if (widget.onPageDirectionChanged != null)
            Positioned(
              right: 8,
              bottom: bottomPadding,
              child: IconButton(
                key: const ValueKey('viewer-toggle-page-direction'),
                icon: Icon(
                  widget.pageDirection == ViewerPageDirection.rightToLeft
                      ? Icons.arrow_back
                      : Icons.arrow_forward,
                ),
                tooltip: l10n.settingsViewerPageDirection,
                onPressed: widget.onPageDirectionChanged,
              ),
            ),
        ],
      ),
    );
  }
}
