import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/providers/animation_provider.dart';

/// 注目させたい要素を、ゆっくり脈動させる
class PulseAnimation extends ConsumerStatefulWidget {
  const PulseAnimation({
    super.key,
    required this.child,
    this.duration,
    this.minScale = 0.98,
    this.maxScale = 1.02,
  });

  final Widget child;
  final Duration? duration;
  final double minScale;
  final double maxScale;

  @override
  ConsumerState<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends ConsumerState<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration ?? AppConfig.animation.slow,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!animationsAllowed(context, ref)) {
      return widget.child;
    }

    final curve = CurvedAnimation(
      parent: _controller,
      curve: AppConfig.animation.defaultCurve,
    );
    final scale = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(curve);
    return ScaleTransition(scale: scale, child: widget.child);
  }
}
