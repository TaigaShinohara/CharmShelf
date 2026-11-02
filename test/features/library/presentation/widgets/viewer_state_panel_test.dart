import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/presentation/widgets/viewer_state_panel.dart';

import '../../../../helpers/test_helpers.dart';

void main() {
  testWidgets('失敗状態に復帰操作と支援技術向け説明を表示する', (tester) async {
    var retried = false;
    var opened = false;
    var backed = false;

    await tester.pumpWidget(
      createProviderApp(
        ViewerStatePanel(
          kind: ViewerFailureKind.decodeFailed,
          message: '破損した可能性があります',
          onRetry: () => retried = true,
          onOpenExternal: () => opened = true,
          onBack: () => backed = true,
        ),
      ),
    );

    expect(find.text('ファイルを表示できません'), findsOneWidget);
    expect(find.text('破損した可能性があります'), findsOneWidget);
    expect(find.bySemanticsLabel('ファイルを表示できません. 破損した可能性があります'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '再試行'));
    await tester.tap(find.widgetWithText(OutlinedButton, '外部アプリで開く'));
    await tester.tap(find.widgetWithText(TextButton, 'ライブラリへ戻る'));

    expect(retried, isTrue);
    expect(opened, isTrue);
    expect(backed, isTrue);
  });

  testWidgets('200%文字サイズと小型画面でも操作がオーバーフローしない', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: createProviderApp(
          ViewerStatePanel(
            kind: ViewerFailureKind.permissionDenied,
            onRetry: () {},
            onOpenExternal: () {},
            onShare: () {},
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('再試行'), findsOneWidget);
    expect(find.text('ライブラリへ戻る'), findsOneWidget);
  });
}
