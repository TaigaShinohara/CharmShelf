import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/theme/app_theme.dart';
import 'package:private_shelf/core/theme/app_tokens.dart';
import 'package:private_shelf/features/library/presentation/widgets/catalog_registration_icon.dart';
import 'package:private_shelf/features/library/presentation/widgets/library_import_button.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

// 指定時だけ実文字の描画を目視確認用PNGとして保存する。
const _fontPath = String.fromEnvironment('IMPORT_BUTTON_PREVIEW_FONT');
const _outputPath = String.fromEnvironment(
  'IMPORT_BUTTON_PREVIEW_OUTPUT',
  defaultValue: 'build/ux_review',
);
const _previewKey = ValueKey('import-button-preview');
const _folderKey = ValueKey('import-folder-button');
const _fileKey = ValueKey('import-file-button');

ThemeData _theme({bool dark = false}) {
  final theme = dark ? AppTheme.dark : AppTheme.light;
  if (_fontPath.isEmpty) return theme;
  final style = theme.filledButtonTheme.style;
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: 'ImportButtonPreview'),
    filledButtonTheme: FilledButtonThemeData(
      style: (style ?? const ButtonStyle()).copyWith(
        textStyle: WidgetStateProperty.resolveWith(
          (states) => (style?.textStyle?.resolve(states) ?? const TextStyle())
              .copyWith(fontFamily: 'ImportButtonPreview'),
        ),
      ),
    ),
  );
}

Widget _subject({
  Locale locale = const Locale('ja'),
  double textScale = 1,
  bool dark = false,
  VoidCallback? onFolder,
  VoidCallback? onFile,
}) => MaterialApp(
  theme: _theme(dark: dark),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: RepaintBoundary(
    key: _previewKey,
    child: Scaffold(
      body: Padding(
        // ホームのカード内と同じ余白を含む狭い領域でも収める。
        padding: AppSpacing.edgeInsetsXl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LibraryImportButton.folder(key: _folderKey, onPressed: onFolder),
            const SizedBox(height: 8),
            LibraryImportButton.file(key: _fileKey, onPressed: onFile),
          ],
        ),
      ),
    ),
  ),
);

Future<void> _capture(WidgetTester tester, String name) async {
  if (_fontPath.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_previewKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory(_outputPath);
      await directory.create(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  setUpAll(() async {
    if (_fontPath.isNotEmpty) {
      final loader = FontLoader('ImportButtonPreview');
      loader.addFont(File(_fontPath).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });

  testWidgets('取り込み対象の図形と文言で区別し、対応する操作を実行する', (tester) async {
    final actions = <String>[];
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        _subject(
          onFolder: () => actions.add('folder'),
          onFile: () => actions.add('file'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('フォルダを取り込む'), findsOneWidget);
      expect(find.text('ファイルを取り込む'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(_folderKey)).getSemanticsData().label,
        'フォルダを取り込む',
      );
      expect(
        tester.getSemantics(find.byKey(_fileKey)).getSemanticsData().label,
        'ファイルを取り込む',
      );
      final icons = tester.widgetList<CatalogRegistrationIcon>(
        find.byType(CatalogRegistrationIcon),
      );
      expect(icons.map((icon) => icon.isFolder), [true, false]);
      expect(
        tester.getTopLeft(find.byKey(_folderKey)).dy,
        lessThan(tester.getTopLeft(find.byKey(_fileKey)).dy),
      );

      await tester.tap(find.byKey(_folderKey));
      await tester.tap(find.byKey(_fileKey));
      expect(actions, ['folder', 'file']);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  const variants = [
    (locale: Locale('ja'), scale: 1.0),
    (locale: Locale('ja'), scale: 2.0),
    (locale: Locale('en'), scale: 2.0),
  ];
  for (final dark in [false, true]) {
    for (final variant in variants) {
      testWidgets(
        '320px・${variant.scale * 100}%で全文と両操作を表示: ${variant.locale.languageCode}, dark=$dark',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final actions = <String>[];
          await tester.pumpWidget(
            _subject(
              locale: variant.locale,
              textScale: variant.scale,
              dark: dark,
              onFolder: () => actions.add('folder'),
              onFile: () => actions.add('file'),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final scheme = _theme(dark: dark).colorScheme;
          for (final key in [_folderKey, _fileKey]) {
            final button = find.byKey(key);
            final text = find.descendant(
              of: button,
              matching: find.byType(Text),
            );
            final paragraph = tester.renderObject<RenderParagraph>(text);
            final buttonRect = tester.getRect(button);
            final labelRect = tester.getRect(text);
            expect(paragraph.didExceedMaxLines, isFalse);
            expect(tester.widget<Text>(text).maxLines, isNull);
            expect(buttonRect.height, greaterThanOrEqualTo(48));
            expect(buttonRect.contains(labelRect.topLeft), isTrue);
            expect(buttonRect.contains(labelRect.bottomRight), isTrue);
            expect(buttonRect.bottom, lessThanOrEqualTo(568));
            expect(
              tester
                  .widget<CatalogRegistrationIcon>(
                    find.descendant(
                      of: button,
                      matching: find.byType(CatalogRegistrationIcon),
                    ),
                  )
                  .color,
              scheme.onPrimary,
            );
            await tester.tap(button);
          }
          expect(actions, ['folder', 'file']);
          await tester.pumpAndSettle();
          await _capture(
            tester,
            'import_buttons_${variant.locale.languageCode}_${(variant.scale * 100).toInt()}pct_${dark ? 'dark' : 'light'}',
          );
        },
      );
    }
  }

  testWidgets('無効状態ではアイコンもボタンの無効色になる', (tester) async {
    await tester.pumpWidget(_subject());
    await tester.pumpAndSettle();
    for (final element in find.byType(CatalogRegistrationIcon).evaluate()) {
      final icon = element.widget as CatalogRegistrationIcon;
      expect(icon.color, DefaultTextStyle.of(element).style.color);
      expect(icon.color, isNot(_theme().colorScheme.onPrimary));
    }
    expect(tester.takeException(), isNull);
  });
}
