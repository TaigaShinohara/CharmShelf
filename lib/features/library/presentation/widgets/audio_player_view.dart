import 'dart:async';
import 'package:just_audio/just_audio.dart' as ja;
import 'viewer/content_ready.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/core/theme/app_theme.dart';
import 'package:private_shelf/core/utils/date_time_utils.dart';
import 'package:private_shelf/shared/widgets/sheets/app_bottom_sheet.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/helpers/external_file_action_helper.dart';
import 'package:private_shelf/features/library/presentation/providers/player_notifier.dart';
import 'package:private_shelf/features/library/presentation/widgets/player_common_widgets.dart';
import 'package:private_shelf/features/library/presentation/widgets/viewer_state_panel.dart';

/// YouTube Music風の音声プレイヤーUI
///
/// `PlayerNotifier` から提供されるコントローラーを使用して表示を行います。
/// 内部モード・外部参照モード共通で使用されます。
/// 映像の代わりに音声用アイコン等のプレースホルダーを表示します。
class AudioPlayerView extends ConsumerStatefulWidget {
  final MediaItem item;
  final VoidCallback? onContentReady;
  final VoidCallback? onClosePressed;

  const AudioPlayerView({
    super.key,
    required this.item,
    this.onContentReady,
    this.onClosePressed,
  });

  @override
  ConsumerState<AudioPlayerView> createState() => _AudioPlayerViewState();
}

class _AudioPlayerViewState extends ConsumerState<AudioPlayerView> {
  bool _showForwardRewindOverlay = false;
  bool _isForward = true;
  Timer? _overlayTimer;
  Timer? _longPressTimer;
  DateTime? _lastScreenHapticsAt;

  // 早送り・速戻し表示用
  String? _speedOverlayText;

  void _triggerScreenHaptics() {
    final now = DateTime.now();
    final last = _lastScreenHapticsAt;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 80)) {
      return;
    }
    _lastScreenHapticsAt = now;
    unawaited(ref.read(feedbackServiceProvider).lightImpact());
  }

  void _triggerMediumHaptics() {
    unawaited(ref.read(feedbackServiceProvider).mediumImpact());
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _handleSkip({
    required bool forward,
    bool isContinuous = false,
    Duration? skipDuration,
  }) {
    final notifier = ref.read(playerNotifierProvider.notifier);
    final duration = skipDuration ?? const Duration(seconds: 10);
    notifier.skip(forward ? duration : -duration);

    if (!isContinuous) {
      setState(() {
        _showForwardRewindOverlay = true;
        _isForward = forward;
      });

      _overlayTimer?.cancel();
      _overlayTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() => _showForwardRewindOverlay = false);
        }
      });
    }
  }

  void _startLongPressSpeedUp() {
    _triggerMediumHaptics();
    setState(() {
      _speedOverlayText = '2.0x';
    });
    ref.read(playerNotifierProvider.notifier).setPlaybackSpeed(2.0);
  }

  void _stopLongPressSpeedUp() {
    setState(() {
      _speedOverlayText = null;
    });
    ref.read(playerNotifierProvider.notifier).setPlaybackSpeed(1.0);
  }

  void _startLongPressRewind() {
    _triggerMediumHaptics();
    setState(() {
      _speedOverlayText = '<<';
    });
    _longPressTimer?.cancel();
    _longPressTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      _handleSkip(
        forward: false,
        isContinuous: true,
        skipDuration: const Duration(seconds: 2),
      );
    });
  }

  void _stopLongPressRewind() {
    _longPressTimer?.cancel();
    setState(() {
      _speedOverlayText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 必要な状態のみを個別に選択して監視し、リビルドを抑制
    final playerState = ref.watch(playerNotifierProvider);
    final isCurrent = playerState.currentItem?.id == widget.item.id;
    final audioPlayer = isCurrent ? playerState.audioPlayer : null;
    final error = isCurrent ? playerState.error : null;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 現在のアイテムでない場合はプレースホルダーを表示
    if (!isCurrent || audioPlayer == null) {
      if (error != null) return _buildError(error);
      return Center(
        child: CircularProgressIndicator(color: colorScheme.primary),
      );
    }

    if (error == null &&
        !playerState.isInitializing &&
        (audioPlayer.processingState == ja.ProcessingState.ready ||
            audioPlayer.processingState == ja.ProcessingState.completed)) {
      reportViewerContentReady(context, widget.onContentReady);
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _triggerScreenHaptics(),
      child: Container(
        color: theme.appColors.overlay,
        child: Center(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity == null) return;
              // 下スワイプで閉じる。
              // コンテンツ操作（音量等）との誤判定を避けるため、
              // ある程度速いスワイプのみを受け付ける。
              if (details.primaryVelocity! > 800) {
                if (widget.onClosePressed != null) {
                  widget.onClosePressed!();
                } else {
                  ref.read(playerNotifierProvider.notifier).collapse();
                }
              }
              // 上スワイプで情報表示。閉じる操作（800）と同等の
              // 意識的なスワイプを求める。
              else if (details.primaryVelocity! < -800) {
                final item = playerState.currentItem;
                if (item != null) {
                  _showFileInfoSheet(context, ref, item);
                }
              }
            },
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.music_note_rounded,
                    size: 160,
                    color: colorScheme.onSurface.withValues(alpha: 0.2),
                  ),
                ),
                // ジェスチャーレイヤー
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onDoubleTap: () => _handleSkip(forward: false),
                              onLongPressStart: (_) => _startLongPressRewind(),
                              onLongPressEnd: (_) => _stopLongPressRewind(),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onDoubleTap: () => _handleSkip(forward: true),
                              onLongPressStart: (_) => _startLongPressSpeedUp(),
                              onLongPressEnd: (_) => _stopLongPressSpeedUp(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                // スキップフィードバック
                if (_showForwardRewindOverlay)
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).appColors.overlay.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _isForward ? Icons.forward_10 : Icons.replay_10,
                          color: colorScheme.onSurface,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                // 長押しフィードバック
                if (_speedOverlayText != null)
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).appColors.overlay.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          _speedOverlayText!,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  /// ファイル情報画面の表示（通常は FileActionSheet で表示されるものを流用）
  void _showFileInfoSheet(BuildContext context, WidgetRef ref, MediaItem item) {
    final l10n = AppLocalizations.of(context)!;

    showAppBottomSheet<void>(
      context,
      title: l10n.settingsFileFileInfo,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          PlayerInfoRow(
            label: l10n.settingsFileName,
            value: p.basename(item.path),
          ),
          PlayerInfoRow(label: l10n.settingsFilePath, value: item.path),
          if (item.size != null)
            PlayerInfoRow(
              label: l10n.settingsFileSize,
              value: _formatBytes(item.size!),
            ),
          PlayerInfoRow(
            label: l10n.settingsFileAddedAt,
            value: DateTimeUtils.formatDateTime(context, item.addedAt),
          ),
          PlayerInfoRow(
            label: l10n.settingsFileUpdatedAt,
            value: DateTimeUtils.formatDateTime(context, item.updatedAt),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    var size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }

  Widget _buildError(String _) {
    return ViewerStatePanel(
      kind: ViewerFailureKind.playbackFailed,
      message: AppLocalizations.of(context)!.viewerPlaybackFailed,
      onRetry: () {
        ref.read(playerNotifierProvider.notifier).play(widget.item);
      },
      onOpenExternal: () => ExternalFileActionHelper.openWithExternalApp(
        context: context,
        ref: ref,
        item: widget.item,
      ),
      onShare: () => ExternalFileActionHelper.shareFile(
        context: context,
        ref: ref,
        item: widget.item,
      ),
    );
  }
}
