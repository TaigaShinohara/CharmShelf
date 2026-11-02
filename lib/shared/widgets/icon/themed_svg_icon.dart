import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Decorative SVG with the same size, color and opacity inheritance as Icon.
class ThemedSvgIcon extends StatelessWidget {
  const ThemedSvgIcon(this.asset, {super.key, this.size, this.color});

  final String asset;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final effectiveSize = size ?? theme.size ?? 24;
    final baseColor = color ?? theme.color ?? const Color(0xFF191919);
    final effectiveColor = baseColor.withValues(
      alpha: baseColor.a * (theme.opacity ?? 1),
    );
    return SizedBox.square(
      dimension: effectiveSize,
      child: Center(
        child: SvgPicture.asset(
          asset,
          width: effectiveSize,
          height: effectiveSize,
          fit: BoxFit.contain,
          colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
