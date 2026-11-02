import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/shared/widgets/widgets.dart';

String _cleanText(String? raw) {
  if (raw == null) return '';
  return raw.replaceAll('\u2060', '').replaceAll('\u200B', '');
}

Finder findAppText(String text) {
  return find.byWidgetPredicate((widget) {
    if (widget is AppText) {
      if (_cleanText(widget.data) == text) return true;
      if (widget.textSpan != null &&
          _cleanText(widget.textSpan!.toPlainText()) == text) {
        return true;
      }
    }
    return false;
  });
}

Finder findAppTextContaining(String pattern) {
  return find.byWidgetPredicate((widget) {
    if (widget is AppText) {
      if (_cleanText(widget.data).contains(pattern)) return true;
      if (widget.textSpan != null &&
          _cleanText(widget.textSpan!.toPlainText()).contains(pattern)) {
        return true;
      }
    }
    return false;
  });
}
