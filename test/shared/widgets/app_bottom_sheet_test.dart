import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/sheets/app_bottom_sheet.dart';

void main() {
  testWidgets('最小位置まで下げて閉じても背後の画面をpopしない', (tester) async {
    var blockedPopCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ja'), Locale('en')],
        home: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) blockedPopCount++;
          },
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showAppBottomSheet<void>(
                    context,
                    child: const SizedBox(
                      key: Key('sheet-content'),
                      height: 200,
                    ),
                  ),
                  child: const Text('開く'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sheet-content')), findsOneWidget);
    expect(
      tester
          .widget<DraggableScrollableSheet>(
            find.byType(DraggableScrollableSheet),
          )
          .minChildSize,
      0,
    );

    final sheetContext = tester.element(find.byKey(const Key('sheet-content')));
    DraggableScrollableNotification(
      extent: 0,
      minExtent: 0,
      maxExtent: 0.95,
      initialExtent: 0.95,
      context: sheetContext,
    ).dispatch(sheetContext);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sheet-content')), findsNothing);
    expect(blockedPopCount, 0);
  });
}
