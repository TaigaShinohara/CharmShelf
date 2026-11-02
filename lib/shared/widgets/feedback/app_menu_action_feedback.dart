import 'dart:async';

import 'package:flutter/material.dart';

typedef AppMenuActionFeedbackBuilder =
    Widget Function(
      BuildContext context,
      Widget animatedIcon,
      VoidCallback onPressed,
    );

/// メニュー操作の押下を、回転するチェックアイコンで約1秒間伝える汎用部品。
class AppMenuActionFeedback extends StatefulWidget {
  const AppMenuActionFeedback({
    super.key,
    this.icon,
    this.iconWidget,
    required this.onPressed,
    required this.builder,
    this.onFeedbackComplete,
    this.iconColor,
    this.iconSize = 20,
    this.feedbackDuration = const Duration(seconds: 1),
    this.rotationDuration = const Duration(milliseconds: 450),
  }) : assert(icon != null || iconWidget != null);

  final IconData? icon;
  final Widget? iconWidget;
  final Color? iconColor;
  final double iconSize;
  final VoidCallback onPressed;

  /// フィードバック表示後に実行する処理。
  ///
  /// メニューを閉じる処理など、アニメーションを見せてから実行したい場合に使う。
  /// 指定した場合、完了後のアイコン復帰は呼び出し側の破棄に委ねる。
  final VoidCallback? onFeedbackComplete;
  final AppMenuActionFeedbackBuilder builder;
  final Duration feedbackDuration;
  final Duration rotationDuration;

  @override
  State<AppMenuActionFeedback> createState() => _AppMenuActionFeedbackState();
}

class _AppMenuActionFeedbackState extends State<AppMenuActionFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;
  Timer? _resetTimer;
  bool _showConfirmation = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: widget.rotationDuration,
    );
  }

  void _handlePressed() {
    if (_showConfirmation) return;

    setState(() => _showConfirmation = true);
    if (!MediaQuery.disableAnimationsOf(context)) {
      _rotationController.forward(from: 0);
    }
    widget.onPressed();

    _resetTimer = Timer(widget.feedbackDuration, () {
      if (!mounted) return;
      if (widget.onFeedbackComplete != null) {
        widget.onFeedbackComplete!();
        return;
      }
      _rotationController.reset();
      setState(() => _showConfirmation = false);
    });
  }

  @override
  void didUpdateWidget(AppMenuActionFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rotationDuration != widget.rotationDuration) {
      _rotationController.duration = widget.rotationDuration;
    }
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final switchDuration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 140);
    final icon = AnimatedSwitcher(
      duration: switchDuration,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: _showConfirmation
          ? Icon(
              Icons.check_rounded,
              key: const ValueKey('confirmation'),
              size: widget.iconSize,
              color: widget.iconColor,
            )
          : KeyedSubtree(
              key: const ValueKey('action'),
              child:
                  widget.iconWidget ??
                  Icon(
                    widget.icon,
                    size: widget.iconSize,
                    color: widget.iconColor,
                  ),
            ),
    );

    return widget.builder(
      context,
      disableAnimations
          ? icon
          : RotationTransition(turns: _rotationController, child: icon),
      _handlePressed,
    );
  }
}
