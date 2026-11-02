import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/providers/animation_provider.dart';

/// 軽量なシマー（スケルトン）表示
///
/// 外部ライブラリを使わず、単純なグラデーション移動で実装します。
class ShimmerAnimation extends ConsumerStatefulWidget {
  const ShimmerAnimation({
    super.key,
    required this.child,
    this.duration,
    this.baseColor,
    this.highlightColor,
  });

  final Widget child;
  final Duration? duration;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  ConsumerState<ShimmerAnimation> createState() => _ShimmerAnimationState();
}

class _ShimmerAnimationState extends ConsumerState<ShimmerAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration ?? AppConfig.animation.slow,
    )..repeat();
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

    final theme = Theme.of(context);
    final base = widget.baseColor ?? theme.colorScheme.surfaceContainerHighest;
    final highlight = widget.highlightColor ?? theme.colorScheme.surface;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value; // 0..1
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment(-1.0 + 2.0 * t, -0.2),
              end: Alignment(-0.2 + 2.0 * t, 0.2),
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(rect);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
