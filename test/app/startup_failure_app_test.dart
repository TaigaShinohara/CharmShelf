import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/app/startup_failure_app.dart';

void main() {
  testWidgets('必須の安全初期化失敗時に空白画面ではなく再試行UIを表示する', (tester) async {
    final completer = Completer<bool>();
    var retryCount = 0;

    await tester.pumpWidget(
      StartupFailureApp(
        onRetry: () {
          retryCount++;
          return completer.future;
        },
      ),
    );

    expect(
      find.text('安全に起動できませんでした').evaluate().isNotEmpty ||
          find.text('Unable to start safely').evaluate().isNotEmpty,
      isTrue,
    );
    expect(find.byType(FilledButton), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(retryCount, 1);
    expect(find.byType(StartupFailureApp), findsOneWidget);

    completer.complete(false);
    await tester.pump();
    expect(
      find.textContaining('サポートに連絡').evaluate().isNotEmpty ||
          find.textContaining('contact support').evaluate().isNotEmpty,
      isTrue,
    );
    expect(find.byType(FilledButton), findsOneWidget);
  });
}
