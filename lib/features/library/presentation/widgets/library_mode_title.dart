import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ライブラリ画面の AppBar タイトル部分。
/// 現在のモードを表示し、タップすることでモードを切り替える。
class LibraryModeTitle extends ConsumerWidget {
  const LibraryModeTitle({
    super.key,
    this.title,
    this.showTitle = true,
    this.titleGradient,
  });

  final String? title;
  final bool showTitle;
  final Gradient? titleGradient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!showTitle || title == null) return const SizedBox.shrink();
    return _buildTitle(
      context,
      title!,
      Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
    );
  }

  Widget _buildTitle(BuildContext context, String value, TextStyle? style) {
    final textStyle = (style ?? const TextStyle()).copyWith(
      inherit: false,
      shadows: const [],
    );
    final text = Text(value, style: textStyle, overflow: TextOverflow.ellipsis);
    final gradient = titleGradient;
    if (gradient == null) return text;

    // ShaderMask は子を一度オフスクリーンへ描画して合成するため、
    // BackdropFilter を含む SliverAppBar では文字の輪郭にフリンジが出ることが
    // ある。文字の Paint に直接 shader を設定し、余分な合成レイヤーを作らない。
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter =
            TextPainter(
              text: TextSpan(text: value, style: textStyle),
              maxLines: 1,
              ellipsis: '…',
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout(
              maxWidth: constraints.hasBoundedWidth
                  ? constraints.maxWidth
                  : double.infinity,
            );
        final shaderBounds = textPainter.size.isEmpty
            ? const Rect.fromLTWH(0, 0, 1, 1)
            : Offset.zero & textPainter.size;

        return Text(
          value,
          style: textStyle.copyWith(
            foreground: Paint()..shader = gradient.createShader(shaderBounds),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
