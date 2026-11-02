import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/providers/animation_provider.dart';

class ScaleAnimation extends ConsumerStatefulWidget {
  const ScaleAnimation({super.key, required this.child, this.duration});

  final Widget child;
  final Duration? duration;

  @override
  ConsumerState<ScaleAnimation> createState() => _ScaleAnimationState();
}

class _ScaleAnimationState extends ConsumerState<ScaleAnimation>
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
    final animation = CurvedAnimation(
      parent: _controller,
      curve: AppConfig.animation.emphasizedCurve,
    );
    return ScaleTransition(scale: animation, child: widget.child);
  }
}
