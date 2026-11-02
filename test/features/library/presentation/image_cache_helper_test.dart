import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/presentation/utils/image_cache_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('表示サイズとDPRからデコード上限を算出し安全範囲に制限する', (tester) async {
    late BuildContext context;

    Future<void> showWith(MediaQueryData data) async {
      await tester.pumpWidget(
        MediaQuery(
          data: data,
          child: Builder(
            builder: (builderContext) {
              context = builderContext;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    }

    await showWith(
      const MediaQueryData(size: Size(320, 240), devicePixelRatio: 1),
    );
    expect(calculateTargetImageLimit(context), 800);

    await showWith(
      const MediaQueryData(size: Size(1000, 600), devicePixelRatio: 1),
    );
    expect(calculateTargetImageLimit(context), 1500);

    await showWith(
      const MediaQueryData(size: Size(1200, 800), devicePixelRatio: 3),
    );
    expect(calculateTargetImageLimit(context), 2000);
  });

  testWidgets('破損画像の投機的プリキャッシュをグローバル例外へ漏らさない', (tester) async {
    final directory = Directory.systemTemp.createTempSync(
      'private-shelf-precache-error-',
    );
    final file = File('${directory.path}/broken.png')
      ..writeAsBytesSync(const [0, 1, 2, 3]);
    addTearDown(() => directory.deleteSync(recursive: true));

    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (builderContext) {
            context = builderContext;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final reportedErrors = <FlutterErrorDetails>[];
    final originalOnError = FlutterError.onError;
    FlutterError.onError = reportedErrors.add;
    addTearDown(() => FlutterError.onError = originalOnError);

    await tester.runAsync(
      () => precacheImageFile(context: context, file: file, targetLimit: 800),
    );
    await tester.pump();

    expect(reportedErrors, isEmpty);
  });
}
