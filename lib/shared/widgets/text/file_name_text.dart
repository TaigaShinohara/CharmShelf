import 'package:flutter/material.dart';

/// A single-line file name that keeps its distinguishing suffix visible.
/// Assistive technologies still read the complete, unmodified name.
class FileNameText extends StatelessWidget {
  const FileNameText(this.name, {super.key, this.style});

  final String name;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          textDirection: direction,
          textScaler: textScaler,
          locale: locale,
          maxLines: 1,
        );
        bool fits(String value) {
          painter.text = TextSpan(text: value, style: effectiveStyle);
          painter.layout();
          return painter.width <= constraints.maxWidth;
        }

        var visibleName = name;
        if (constraints.hasBoundedWidth && !fits(name)) {
          final characters = name.characters.toList(growable: false);
          final extensionStart = characters.lastIndexOf('.');
          var stem = characters;
          var extension = '';
          if (extensionStart > 0 && extensionStart < characters.length - 1) {
            final candidateExtension = characters.skip(extensionStart).join();
            if (fits('…$candidateExtension')) {
              stem = characters.take(extensionStart).toList(growable: false);
              extension = candidateExtension;
            }
          }
          var low = 0;
          var high = stem.length - 1;
          visibleName = '…$extension';
          while (low <= high) {
            final count = (low + high) ~/ 2;
            // Reserve the extension separately, then give the distinguishing
            // end of the name twice as much space as its often-shared prefix.
            final headLength = count ~/ 3;
            final tailLength = count - headLength;
            final candidate =
                '${stem.take(headLength).join()}…'
                '${stem.skip(stem.length - tailLength).join()}$extension';
            if (fits(candidate)) {
              visibleName = candidate;
              low = count + 1;
            } else {
              high = count - 1;
            }
          }
        }
        painter.dispose();
        return Text(
          visibleName,
          style: effectiveStyle,
          maxLines: 1,
          overflow: TextOverflow.clip,
          semanticsLabel: name,
        );
      },
    );
  }
}
