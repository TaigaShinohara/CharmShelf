import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/shared/widgets/dialogs/dialog_actions.dart';

void main() {
  testWidgets('action row stays horizontal on a narrow screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: AlertDialog(
            actions: [
              DialogActionRow(
                leading: TextButton(onPressed: () {}, child: const Text('戻る')),
                trailing: FilledButton(
                  onPressed: () {},
                  child: const Text('この内容で実行する'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final leadingCenter = tester.getCenter(find.text('戻る'));
    final trailingCenter = tester.getCenter(find.text('この内容で実行する'));
    expect(leadingCenter.dy, closeTo(trailingCenter.dy, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('close action exposes a semantic label and invokes callback', (
    tester,
  ) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DialogCloseButton(
            semanticLabel: 'キャンセル',
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.bySemanticsLabel('キャンセル'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    expect(pressed, isTrue);
  });
}
