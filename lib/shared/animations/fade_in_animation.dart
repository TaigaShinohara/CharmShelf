import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/animation_provider.dart';
import '../../core/config/app_config.dart';

class FadeInAnimation extends ConsumerStatefulWidget {
  const FadeInAnimation({super.key, required this.child, this.duration});

  final Widget child;
  final Duration? duration;

  @override
  ConsumerState<FadeInAnimation> createState() => _FadeInAnimationState();
}

class _FadeInAnimationState extends ConsumerState<FadeInAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration ?? AppConfig.animation.fast,
    )..forward();
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
    return FadeTransition(opacity: _controller, child: widget.child);
  }
}
