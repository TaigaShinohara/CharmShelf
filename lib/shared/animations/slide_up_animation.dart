import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/providers/animation_provider.dart';

class SlideUpAnimation extends ConsumerStatefulWidget {
  const SlideUpAnimation({
    super.key,
    required this.child,
    this.duration,
    this.delay = Duration.zero,
    this.beginOffsetY = 0.08,
  });

  final Widget child;
  final Duration? duration;
  final Duration delay;
  final double beginOffsetY;

  @override
  ConsumerState<SlideUpAnimation> createState() => _SlideUpAnimationState();
}

class _SlideUpAnimationState extends ConsumerState<SlideUpAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration ?? AppConfig.animation.normal,
    );
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
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
    final animation = CurvedAnimation(
      parent: _controller,
      curve: AppConfig.animation.defaultCurve,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(0, widget.beginOffsetY),
        end: Offset.zero,
      ).animate(animation),
      child: FadeTransition(opacity: animation, child: widget.child),
    );
  }
}
