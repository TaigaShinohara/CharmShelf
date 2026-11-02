import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/sheets/action_bottom_sheet.dart';

void main() {
  testWidgets('独自アイコンの項目も確認表示後に選択できる', (tester) async {
    String? selected;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  selected = await showActionBottomSheet<String>(
                    context,
                    items: const [
                      ActionSheetItem(
                        label: 'フォルダを追加',
                        value: 'folder',
                        iconWidget: SizedBox(
                          key: ValueKey('custom-icon'),
                          width: 48,
                          height: 28,
                        ),
                      ),
                    ],
                  );
                },
                child: const Text('開く'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('custom-icon')), findsOneWidget);

    await tester.tap(
      find.ancestor(
        of: find.byKey(const ValueKey('custom-icon')),
        matching: find.byType(ListTile),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(selected, isNull);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(selected, 'folder');
  });

  testWidgets('選択した項目を約1秒チェック表示してからシートを閉じる', (tester) async {
    String? selected;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  selected = await showActionBottomSheet<String>(
                    context,
                    items: const [
                      ActionSheetItem(
                        label: '名前順',
                        value: 'name',
                        icon: Icons.sort_by_alpha,
                      ),
                    ],
                  );
                },
                child: const Text('開く'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.sort_by_alpha));
    await tester.pump();

    expect(selected, isNull);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(selected, 'name');
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });
}
