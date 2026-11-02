import 'package:flutter/material.dart';
import 'app_text.dart';

/// アプリ全体のテキストに太字やテーマカラーの強調を適用するウィジェット
///
/// サポートする記法:
/// - `**太字**`: [FontWeight.bold]
/// - `[primary]テキスト[/primary]`: [ColorScheme.primary] + [FontWeight.bold]
/// - `[error]テキスト[/error]`: [ColorScheme.error] + [FontWeight.bold]
/// - `[secondary]テキスト[/secondary]`: [ColorScheme.secondary] + [FontWeight.bold]
///
/// 内部で [AppText.rich] を使用するため、BudouX によるセマンティック改行も有効です。
class AppFormattedText extends StatelessWidget {
  const AppFormattedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.wrapWords = true,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool wrapWords;

  static final RegExp _tagRegex = RegExp(
    r'(\*\*.*?\*\*|\[primary\].*?\[/primary\]|\[error\].*?\[/error\]|\[secondary\].*?\[/secondary\])',
    dotAll: true,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = style ?? theme.textTheme.bodyMedium ?? const TextStyle();
    final spans = _parseFormattedText(text, baseStyle, theme.colorScheme);

    return AppText.rich(
      TextSpan(children: spans, style: baseStyle),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      wrapWords: wrapWords,
    );
  }

  List<InlineSpan> _parseFormattedText(
    String input,
    TextStyle baseStyle,
    ColorScheme colorScheme,
  ) {
    final spans = <InlineSpan>[];
    var lastIndex = 0;

    for (final match in _tagRegex.allMatches(input)) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: input.substring(lastIndex, match.start),
            style: baseStyle,
          ),
        );
      }

      final matchedText = match.group(0)!;
      if (matchedText.startsWith('**') && matchedText.endsWith('**')) {
        final content = matchedText.substring(2, matchedText.length - 2);
        spans.add(
          TextSpan(
            text: content,
            style: baseStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      } else if (matchedText.startsWith('[primary]') &&
          matchedText.endsWith('[/primary]')) {
        final content = matchedText.substring(9, matchedText.length - 10);
        spans.add(
          TextSpan(
            text: content,
            style: baseStyle.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      } else if (matchedText.startsWith('[error]') &&
          matchedText.endsWith('[/error]')) {
        final content = matchedText.substring(7, matchedText.length - 8);
        spans.add(
          TextSpan(
            text: content,
            style: baseStyle.copyWith(
              color: colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      } else if (matchedText.startsWith('[secondary]') &&
          matchedText.endsWith('[/secondary]')) {
        final content = matchedText.substring(11, matchedText.length - 12);
        spans.add(
          TextSpan(
            text: content,
            style: baseStyle.copyWith(
              color: colorScheme.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }

      lastIndex = match.end;
    }

    if (lastIndex < input.length) {
      spans.add(TextSpan(text: input.substring(lastIndex), style: baseStyle));
    }

    return spans;
  }
}
