import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/feedback_providers.dart';
import '../../../core/providers/tutorial_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../dialogs/modern_dialog.dart';
import '../widgets.dart';

/// 画面全体の簡易チュートリアル（オーバーレイ）
///
/// - 初回のみ表示（SharedPreferencesで表示済みを保存）
/// - スキップ可能
class TutorialOverlay extends ConsumerStatefulWidget {
  const TutorialOverlay({
    super.key,
    required this.tutorialId,
    required this.steps,
    required this.child,
    this.enabled = true,
    this.preview = false,
    this.onPreviewDismissed,
  });

  final String tutorialId;
  final List<TutorialStep> steps;
  final Widget child;
  final bool enabled;

  /// 既読でもう一度見せる。閉じても既読状態は変えない。
  final bool preview;
  final VoidCallback? onPreviewDismissed;

  @override
  ConsumerState<TutorialOverlay> createState() => _TutorialOverlayState();

  /// 任意のタイミングでチュートリアルをダイアログ形式で表示する
  ///
  /// [preview] が true の場合は既読状態に関係なく表示し、表示後も状態を変更しない。
  static Future<void> show(
    BuildContext context, {
    required WidgetRef ref,
    required String tutorialId,
    required List<TutorialStep> steps,
    bool preview = false,
  }) async {
    if (!preview) {
      // 既に完了している場合は表示しない
      final tutorialState = ref.read(tutorialStateProvider);
      final completed = tutorialState.value?[tutorialId] ?? false;
      if (completed) return;
    }

    if (!context.mounted) return;

    await showModernDialog<void>(
      context,
      barrierDismissible: false,
      child: _TutorialDialog(
        tutorialId: tutorialId,
        steps: steps,
        recordCompletion: !preview,
      ),
    );
  }
}

class _TutorialOverlayState extends ConsumerState<TutorialOverlay> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled && !widget.preview) return widget.child;
    if (widget.steps.isEmpty) return widget.child;
    if (_dismissed && !widget.preview) return widget.child;

    if (widget.preview) {
      return Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.55)),
          ),
          _TutorialCard(
            tutorialId: widget.tutorialId,
            steps: widget.steps,
            recordCompletion: false,
            onDismiss: () => widget.onPreviewDismissed?.call(),
          ),
        ],
      );
    }

    final tutorialState = ref.watch(tutorialStateProvider);

    return tutorialState.when(
      data: (states) {
        final completed = states[widget.tutorialId] ?? false;
        if (completed) return widget.child;

        return Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.55)),
            ),
            _TutorialCard(
              tutorialId: widget.tutorialId,
              steps: widget.steps,
              onDismiss: () => setState(() => _dismissed = true),
            ),
          ],
        );
      },
      loading: () => widget.child,
      error: (_, _) => widget.child,
    );
  }
}

class _TutorialDialog extends ConsumerWidget {
  final String tutorialId;
  final List<TutorialStep> steps;
  final bool recordCompletion;

  const _TutorialDialog({
    required this.tutorialId,
    required this.steps,
    required this.recordCompletion,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _TutorialCard(
      tutorialId: tutorialId,
      steps: steps,
      recordCompletion: recordCompletion,
      bottomAligned: false,
      onDismiss: () => Navigator.of(context).pop(),
    );
  }
}

class _TutorialCard extends ConsumerStatefulWidget {
  final String tutorialId;
  final List<TutorialStep> steps;
  final bool recordCompletion;
  final bool bottomAligned;
  final VoidCallback onDismiss;

  const _TutorialCard({
    required this.tutorialId,
    required this.steps,
    this.recordCompletion = true,
    this.bottomAligned = true,
    required this.onDismiss,
  });

  @override
  ConsumerState<_TutorialCard> createState() => _TutorialCardState();
}

class _TutorialCardState extends ConsumerState<_TutorialCard> {
  int _index = 0;

  Future<void> _skip() async {
    ref.read(feedbackServiceProvider).lightImpact();
    if (widget.recordCompletion) {
      await ref
          .read(tutorialStateProvider.notifier)
          .complete(widget.tutorialId);
    }
    widget.onDismiss();
  }

  Future<void> _next() async {
    ref.read(feedbackServiceProvider).lightImpact();
    final next = _index + 1;
    if (next >= widget.steps.length) {
      if (widget.recordCompletion) {
        await ref
            .read(tutorialStateProvider.notifier)
            .complete(widget.tutorialId);
      }
      widget.onDismiss();
      return;
    }
    setState(() => _index = next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final step = widget.steps[_index.clamp(0, widget.steps.length - 1)];
    final isLast = _index >= widget.steps.length - 1;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentColor = switch (step.tone) {
      TutorialTone.normal => colorScheme.primary,
      TutorialTone.important => theme.appColors.warning,
      TutorialTone.danger => colorScheme.error,
    };
    final containerColor = switch (step.tone) {
      TutorialTone.normal => colorScheme.surface,
      TutorialTone.important => theme.appColors.warningContainer,
      TutorialTone.danger => colorScheme.errorContainer,
    };
    final label = switch (step.tone) {
      TutorialTone.normal => null,
      TutorialTone.important => l10n.tutorialImportantLabel,
      TutorialTone.danger => l10n.tutorialDangerLabel,
    };

    final card = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Material(
        key: ValueKey('tutorial-card-${step.tone.name}'),
        color: containerColor,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.radiusLg,
          side: BorderSide(color: accentColor, width: 3),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (label != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: AppRadius.radiusFull,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          step.tone == TutorialTone.danger
                              ? Icons.warning_amber_rounded
                              : Icons.priority_high_rounded,
                          size: 18,
                          color: step.tone == TutorialTone.danger
                              ? colorScheme.onError
                              : theme.appColors.onWarning,
                        ),
                        const SizedBox(width: 5),
                        AppText(
                          label,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: step.tone == TutorialTone.danger
                                ? colorScheme.onError
                                : theme.appColors.onWarning,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              AppText(
                step.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              AppText(
                step.message,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    constraints: const BoxConstraints(minHeight: 40),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.72),
                      borderRadius: AppRadius.radiusFull,
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: AppText(
                      '${_index + 1} / ${widget.steps.length}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: _skip,
                    child: AppText(l10n.tutorialSkip),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(72, 48),
                    ),
                    onPressed: _next,
                    child: AppText(
                      isLast ? l10n.tutorialComplete : l10n.tutorialNext,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (!widget.bottomAligned) return card;

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(minimum: const EdgeInsets.all(16), child: card),
    );
  }
}

class TutorialStep {
  const TutorialStep({
    required this.title,
    required this.message,
    this.tone = TutorialTone.normal,
  });

  final String title;
  final String message;
  final TutorialTone tone;
}

enum TutorialTone { normal, important, danger }
