import 'package:flutter/widgets.dart';

class TextScaleWrapper extends StatelessWidget {
  final Widget child;
  final double minScale;
  final double maxScale;

  const TextScaleWrapper({
    super.key,
    required this.child,
    this.minScale = 1.0,
    this.maxScale = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final currentScale = mediaQuery.textScaler.scale(1.0);
    final clampedScale = currentScale.clamp(minScale, maxScale);

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: TextScaler.linear(clampedScale)),
      child: child,
    );
  }
}
