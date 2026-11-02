import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/shared/widgets/accessibility/semantic_wrapper.dart';

void main() {
  testWidgets('SemanticWrapper は label と hint をセマンティクスへ公開する', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SemanticWrapper(
            label: '設定を開く',
            hint: 'ダブルタップで開きます',
            isButton: true,
            child: Icon(Icons.settings),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('設定を開く'), findsOneWidget);
    expect(find.byTooltip('ダブルタップで開きます'), findsNothing);

    semantics.dispose();
  });

  testWidgets('ExcludeFromSemantics は読み上げ対象を外す', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ExcludeFromSemantics(child: Text('装飾テキスト'))),
      ),
    );

    expect(find.bySemanticsLabel('装飾テキスト'), findsNothing);

    semantics.dispose();
  });
}
