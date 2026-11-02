import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/theme/app_theme.dart';

const reviewBoundaryKey = ValueKey('iphone-ux-review-boundary');
const _fontPath = String.fromEnvironment('UX_QA_FONT');
const _iconPath = String.fromEnvironment('UX_QA_ICON_FONT');
const _outputPath = String.fromEnvironment(
  'UX_QA_OUTPUT',
  defaultValue: 'build/iphone-ux-review-20261006/after-library',
);
bool get reviewFontsEnabled => _fontPath.isNotEmpty;

Future<void> loadReviewFonts() async {
  for (final (family, path) in [
    ('UxReview', _fontPath),
    ('MaterialIcons', _iconPath),
  ]) {
    if (path.isEmpty) continue;
    final loader = FontLoader(family);
    loader.addFont(File(path).readAsBytes().then(ByteData.sublistView));
    await loader.load();
  }
}

ThemeData reviewTheme({Brightness brightness = Brightness.light}) {
  final theme = brightness == Brightness.light ? AppTheme.light : AppTheme.dark;
  if (!reviewFontsEnabled) return theme;
  const family = 'UxReview';
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: family),
    primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: family),
    dialogTheme: theme.dialogTheme.copyWith(
      titleTextStyle:
          (theme.dialogTheme.titleTextStyle ?? theme.textTheme.headlineSmall)
              ?.copyWith(fontFamily: family),
      contentTextStyle:
          (theme.dialogTheme.contentTextStyle ?? theme.textTheme.bodyMedium)
              ?.copyWith(fontFamily: family),
    ),
    appBarTheme: theme.appBarTheme.copyWith(
      titleTextStyle:
          (theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge)
              ?.copyWith(fontFamily: family),
    ),
    textButtonTheme: TextButtonThemeData(
      style: (theme.textButtonTheme.style ?? const ButtonStyle()).copyWith(
        textStyle: WidgetStatePropertyAll(
          theme.textTheme.labelLarge?.copyWith(fontFamily: family),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: (theme.filledButtonTheme.style ?? const ButtonStyle()).copyWith(
        textStyle: WidgetStatePropertyAll(
          theme.textTheme.labelLarge?.copyWith(fontFamily: family),
        ),
      ),
    ),
  );
}

Future<void> captureReview(WidgetTester tester, String name) async {
  if (!reviewFontsEnabled) return;
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(reviewBoundaryKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(_outputPath).create(recursive: true);
      await File(
        '$_outputPath/$name.png',
      ).writeAsBytes(png!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
