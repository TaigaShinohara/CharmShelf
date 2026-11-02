import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Loading placeholders follow the selected app theme, including manual mode.
class AppSkeletonizerConfig extends StatelessWidget {
  const AppSkeletonizerConfig({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => SkeletonizerConfig(
    data: SkeletonizerConfigData(brightness: Theme.of(context).brightness),
    child: child,
  );
}
