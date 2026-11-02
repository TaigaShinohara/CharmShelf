import 'dart:async';

import 'package:flutter/material.dart';
import '../widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/feedback_providers.dart';
import '../../../core/theme/app_colors.dart';

/// 画面全体を覆うカットシーン（オーバーレイ）。
///
/// 目的:
/// - ローディング、エラー、演出など「一時的に全画面を専有する表示」を汎用化する
/// - カスタムWidgetで内容を差し替え可能にする
class FullscreenCutscene {
  FullscreenCutscene._();

  static OverlayEntry? _entry;

  static bool get isVisible => _entry != null;

  static void hide() {
    _entry?.remove();
    _entry = null;
  }

  static void show(
    BuildContext context, {
    required Widget child,
    Color? barrierColor,
    bool dismissible = false,

    /// デフォルトは2秒で自動終了（“終わらない”事故を防ぐ）
    ///
    /// - `null` を渡すと自動終了しません（例外的に長時間表示したい場合のみ）
    Duration? autoHideDuration = const Duration(seconds: 2),

    /// 自動終了までの残り秒数を表示する
    bool showCountdown = true,
  }) {
    hide();

    final overlay = Overlay.of(context, rootOverlay: true);
    final barrier = barrierColor ?? AppColors.overlay.withValues(alpha: 0.70);

    _entry = OverlayEntry(
      builder: (context) => _FullscreenCutsceneWidget(
        barrierColor: barrier,
        dismissible: dismissible,
        onDismiss: hide,
        autoHideDuration: autoHideDuration,
        showCountdown: showCountdown,
        child: child,
      ),
    );

    overlay.insert(_entry!);
  }

  static void showLoading(
    BuildContext context, {
    String? message,
    bool dismissible = false,
    Duration? autoHideDuration = const Duration(seconds: 2),
  }) {
    show(
      context,
      dismissible: dismissible,
      autoHideDuration: autoHideDuration,
      child: _LoadingCutscene(message: message),
    );
  }

  static void showError(
    BuildContext context, {
    required String message,
    String? buttonLabel,
    VoidCallback? onPressed,
  }) {
    show(
      context,
      dismissible: false,
      // エラーは自動終了しない（ユーザーに確実に見せる）
      autoHideDuration: null,
      showCountdown: false,
      child: _ErrorCutscene(
        message: message,
        buttonLabel: buttonLabel,
        // 何も渡されない場合でも必ず閉じられるようにする（“終わらない”事故を防ぐ）
        onPressed: onPressed ?? hide,
      ),
    );
  }
}

class _FullscreenCutsceneWidget extends StatefulWidget {
  const _FullscreenCutsceneWidget({
    required this.child,
    required this.barrierColor,
    required this.onDismiss,
    required this.dismissible,
    required this.autoHideDuration,
    required this.showCountdown,
  });

  final Widget child;
  final Color barrierColor;
  final VoidCallback onDismiss;
  final bool dismissible;
  final Duration? autoHideDuration;
  final bool showCountdown;

  @override
  State<_FullscreenCutsceneWidget> createState() =>
      _FullscreenCutsceneWidgetState();
}

class _FullscreenCutsceneWidgetState extends State<_FullscreenCutsceneWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  int? _remainingSeconds;
  bool _dismissing = false;
  Timer? _tick;
  Timer? _autoHide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();

    final d = widget.autoHideDuration;
    if (d != null) {
      _remainingSeconds = (d.inMilliseconds / 1000).ceil().clamp(0, 999);
      // 残り秒数表示（1秒ごと）
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          final cur = _remainingSeconds ?? 0;
          _remainingSeconds = (cur - 1).clamp(0, 999);
        });
      });
      // 自動終了（安全装置）
      _autoHide = Timer(d, () {
        if (!mounted) return;
        _dismiss();
      });
    }
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    _tick?.cancel();
    _autoHide?.cancel();
    try {
      await _controller.reverse();
    } finally {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _autoHide?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: _fade,
      child: Material(
        color: widget.barrierColor,
        child: Stack(
          children: [
            Positioned.fill(
              child: widget.dismissible
                  ? GestureDetector(onTap: _dismiss)
                  : const SizedBox.shrink(),
            ),
            Center(child: widget.child),
            if (widget.autoHideDuration != null &&
                widget.showCountdown &&
                _remainingSeconds != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.overlay.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: AppText(
                      '終了まで ${_remainingSeconds!}秒',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onInverseSurface,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCutscene extends StatelessWidget {
  const _LoadingCutscene({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: scheme.primary),
        if (message != null && message!.isNotEmpty) ...[
          const SizedBox(height: 16),
          AppText(
            message!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _ErrorCutscene extends ConsumerWidget {
  const _ErrorCutscene({
    required this.message,
    this.buttonLabel,
    this.onPressed,
  });

  final String message;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: scheme.error, size: 32),
            const SizedBox(height: 10),
            AppText(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onPressed != null) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  ref.read(feedbackServiceProvider).lightImpact();
                  onPressed?.call();
                },
                child: AppText(buttonLabel ?? 'OK'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
