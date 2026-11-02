import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/providers/animation_provider.dart';

/// 押下時に軽く縮む（ボタンの押し心地を統一）
class PressAnimation extends ConsumerStatefulWidget {
  const PressAnimation({
    super.key,
    required this.child,
    this.pressedScale = 0.97,
    this.duration,
  });

  final Widget child;
  final double pressedScale;
  final Duration? duration;

  @override
  ConsumerState<PressAnimation> createState() => _PressAnimationState();
}

class _PressAnimationState extends ConsumerState<PressAnimation> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (!animationsAllowed(context, ref)) {
      return widget.child;
    }

    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: widget.duration ?? AppConfig.animation.instant,
        curve: AppConfig.animation.defaultCurve,
        child: widget.child,
      ),
    );
  }
}
