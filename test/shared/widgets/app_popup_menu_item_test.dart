import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/shared/widgets/app_popup_menu_item.dart';

void main() {
  testWidgets('設定名、説明、オンオフ状態を同時に表示できる', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PopupMenuButton<String>(
            itemBuilder: (context) => [
              AppPopupMenuItem.text(
                value: 'compact',
                height: 68,
                iconData: Icons.view_compact_outlined,
                text: 'コンパクト表示',
                description: '最低限の情報のみ表示中',
                trailing: const AppMenuToggleIndicator(
                  isOn: true,
                  onLabel: 'オン',
                  offLabel: 'オフ',
                ),
              ),
              AppPopupMenuItem.text(
                value: 'catalog',
                height: 68,
                iconData: Icons.auto_stories_outlined,
                text: 'カタログのみ表示',
                description: 'すべての項目を表示中',
                trailing: const AppMenuToggleIndicator(
                  isOn: false,
                  onLabel: 'オン',
                  offLabel: 'オフ',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('コンパクト表示'), findsOneWidget);
    expect(find.text('最低限の情報のみ表示中'), findsOneWidget);
    expect(find.text('カタログのみ表示'), findsOneWidget);
    expect(find.text('すべての項目を表示中'), findsOneWidget);
    expect(find.text('オン'), findsNothing);
    expect(find.text('オフ'), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('選択した項目を約1秒チェック表示してからメニューを閉じる', (tester) async {
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PopupMenuButton<String>(
            onSelected: (value) => selected = value,
            itemBuilder: (context) => [
              AppPopupMenuItem.text(
                value: 'copy',
                iconData: Icons.copy_outlined,
                text: 'コピー',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('コピー'));
    await tester.pump();

    expect(selected, isNull);
    expect(find.text('コピー'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 999));
    expect(selected, isNull);

    await tester.pump(const Duration(milliseconds: 1));
    expect(selected, 'copy');
    await tester.pumpAndSettle();
    expect(find.text('コピー'), findsNothing);
  });

  testWidgets('フィードバック無効時はチェック表示を挟まず即時選択する', (tester) async {
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PopupMenuButton<String>(
            onSelected: (value) => selected = value,
            itemBuilder: (context) => [
              AppPopupMenuItem.text(
                value: 'filter',
                iconData: Icons.tune,
                text: 'フィルター',
                showSelectionFeedback: false,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('フィルター'));
    await tester.pumpAndSettle();

    expect(selected, 'filter');
    expect(find.text('フィルター'), findsNothing);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });
}
