import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/shared/widgets/text/file_name_text.dart';

void main() {
  testWidgets(
    'short names remain intact and long common prefixes stay distinct',
    (tester) async {
      const names = [
        'short.mp3',
        '共通のとても長い名前で始まる旅行の記録_朝の音声.mp3',
        '共通のとても長い名前で始まる旅行の記録_夜の音声.mp3',
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              child: Column(
                children: [for (final name in names) FileNameText(name)],
              ),
            ),
          ),
        ),
      );
      final text = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(FileNameText),
              matching: find.byType(Text),
            ),
          )
          .toList();
      expect(text.first.data, names.first);
      expect(text[1].data, endsWith('朝の音声.mp3'));
      expect(text[2].data, endsWith('夜の音声.mp3'));
      expect(text[1].data, isNot(text[2].data));
      expect(text.map((widget) => widget.semanticsLabel), names);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the extension does not consume the distinguishing name suffix', (
    tester,
  ) async {
    const names = [
      '共通のとても長い名前で始まる旅行の記録_朝の音声.mp3',
      '共通のとても長い名前で始まる旅行の記録_朝の音声.flac',
      '共通のとても長い名前で始まる旅行の記録_夜の音声',
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            child: Column(
              children: [for (final name in names) FileNameText(name)],
            ),
          ),
        ),
      ),
    );
    final text = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(FileNameText),
            matching: find.byType(Text),
          ),
        )
        .toList();
    expect(text[0].data, endsWith('朝の音声.mp3'));
    expect(text[1].data, endsWith('朝の音声.flac'));
    expect(text[2].data, endsWith('夜の音声'));
    expect(text.map((widget) => widget.data).toSet(), hasLength(3));
    expect(text.map((widget) => widget.semanticsLabel), names);
    expect(tester.takeException(), isNull);
  });
}
