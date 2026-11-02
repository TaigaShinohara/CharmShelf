import 'package:flutter/widgets.dart';

import 'slide_up_animation.dart';
import '../../core/config/app_config.dart';

class StaggeredListAnimation extends StatelessWidget {
  const StaggeredListAnimation({
    super.key,
    required this.children,
    this.itemDelay,
  });

  final List<Widget> children;
  final Duration? itemDelay;

  @override
  Widget build(BuildContext context) {
    final delay = itemDelay ?? AppConfig.animation.staggerDelay;
    return Column(
      children: [
        for (var i = 0; i < children.length; i++)
          SlideUpAnimation(delay: delay * i, child: children[i]),
      ],
    );
  }
}
