import '../../finders.dart' as shared_find;
import 'package:private_shelf/core/feedback/snackbar_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/shared/widgets/feedback/app_snackbar.dart';

void main() {
  testWidgets('同じOverlay Hostのchild更新を表示へ反映する', (tester) async {
    final content = ValueNotifier<String>('更新前の内容');
    addTearDown(content.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => ValueListenableBuilder<String>(
          valueListenable: content,
          builder: (context, value, child) =>
              AppSnackBarOverlayHost(child: Text(value)),
        ),
        home: const SizedBox.shrink(),
      ),
    );
    final host = tester.state(find.byType(AppSnackBarOverlayHost));
    expect(find.text('更新前の内容'), findsOneWidget);

    content.value = '更新後の内容';
    await tester.pump();

    expect(tester.state(find.byType(AppSnackBarOverlayHost)), same(host));
    expect(find.text('更新前の内容'), findsNothing);
    expect(find.text('更新後の内容'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Host交換で旧通知を破棄し新しいglobal通知を表示できる', (tester) async {
    await tester.pumpWidget(
      KeyedSubtree(
        key: const ValueKey('old-host'),
        child: _noticeHost(top: false),
      ),
    );
    await tester.tap(find.text('最初を表示'));
    await tester.pumpAndSettle();
    expect(find.text('最初の通知'), findsOneWidget);
    final previousOverlay = appSnackBarOverlayKey.currentState;

    await tester.pumpWidget(
      KeyedSubtree(
        key: const ValueKey('new-host'),
        child: _noticeHost(top: false),
      ),
    );
    expect(appSnackBarOverlayKey.currentState, isNotNull);
    expect(appSnackBarOverlayKey.currentState, isNot(same(previousOverlay)));
    expect(find.text('最初の通知'), findsNothing);

    AppSnackBarMessenger.showGlobal(
      const SnackBar(
        content: Text('交換後のglobal通知'),
        duration: Duration(seconds: 1),
        persist: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('交換後のglobal通知'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('交換後のglobal通知'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final top in [false, true]) {
    testWidgets('通知を表示中に画面を破棄してもタイマーが残らない top=$top', (tester) async {
      await tester.pumpWidget(_noticeHost(top: top));
      await tester.tap(find.text('最初を表示'));
      await tester.pumpAndSettle();
      expect(
        (top ? shared_find.findAppText('最初の通知') : find.text('最初の通知')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      if (top) {
        TopSnackBarOverlay.hide();
      } else {
        AppSnackBarMessenger.clearGlobal();
      }
      expect(tester.takeException(), isNull);
      // Do not advance time: the binding must find no leftover timer.
    });

    testWidgets('通知を置き換えても古い期限で新しい通知を閉じない top=$top', (tester) async {
      await tester.pumpWidget(_noticeHost(top: top));
      await tester.tap(find.text('最初を表示'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('次を表示'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(
        (top ? shared_find.findAppText('最初の通知') : find.text('最初の通知')),
        findsNothing,
      );
      expect(
        (top ? shared_find.findAppText('次の通知') : find.text('次の通知')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(
        (top ? shared_find.findAppText('次の通知') : find.text('次の通知')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('通知操作は一度だけ実行し終了アニメーション中にも破棄できる top=$top', (tester) async {
      var calls = 0;
      await tester.pumpWidget(_noticeHost(top: top, onAction: () => calls++));
      await tester.tap(find.text('最初を表示'));
      await tester.pumpAndSettle();
      await tester.tap(top ? shared_find.findAppText('確認') : find.text('確認'));
      await tester.tap(top ? shared_find.findAppText('確認') : find.text('確認'));
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      if (top) {
        TopSnackBarOverlay.hide();
      } else {
        AppSnackBarMessenger.clearGlobal();
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('モーダルメニューより手前にSnackBarを表示して操作できる', (tester) async {
    var actionPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => AppSnackBarOverlayHost(child: child!),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  useRootNavigator: true,
                  builder: (context) => SizedBox(
                    key: const ValueKey('modal-menu'),
                    height: 400,
                    child: Center(
                      child: FilledButton(
                        onPressed: () {
                          AppSnackBarMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('処理が完了しました'),
                              action: SnackBarAction(
                                label: '確認',
                                onPressed: () => actionPressed = true,
                              ),
                            ),
                          );
                        },
                        child: const Text('結果を表示'),
                      ),
                    ),
                  ),
                ),
                child: const Text('メニューを開く'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('メニューを開く'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('結果を表示'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('modal-menu')), findsOneWidget);
    expect(find.text('処理が完了しました'), findsOneWidget);

    await tester.tap(find.text('確認'));
    await tester.pump();
    expect(actionPressed, isTrue);
  });
}

Widget _noticeHost({required bool top, VoidCallback? onAction}) => MaterialApp(
  builder: (context, child) => AppSnackBarOverlayHost(child: child!),
  home: Scaffold(
    body: Builder(
      builder: (context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final first in [true, false])
            FilledButton(
              onPressed: () {
                final message = first ? '最初の通知' : '次の通知';
                final action = onAction == null
                    ? null
                    : SnackBarAction(label: '確認', onPressed: onAction);
                if (top) {
                  TopSnackBarOverlay.show(
                    context: context,
                    message: message,
                    config: SnackBarConfig.defaultConfig(),
                    action: action,
                  );
                } else {
                  AppSnackBarMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      duration: const Duration(seconds: 3),
                      persist: false,
                      action: action,
                    ),
                  );
                }
              },
              child: Text(first ? '最初を表示' : '次を表示'),
            ),
        ],
      ),
    ),
  ),
);
