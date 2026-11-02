import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/theme/app_theme.dart';
import 'package:private_shelf/features/samples/data/sample_preview_service.dart';
import 'package:private_shelf/features/samples/domain/sample_catalog.dart';
import 'package:private_shelf/features/samples/presentation/sample_preview_screen.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

const _fontPath = String.fromEnvironment('UX_QA_FONT');
const _iconPath = String.fromEnvironment('UX_QA_ICON_FONT');
const _boundary = ValueKey('sample-preview-boundary');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (_fontPath.isNotEmpty) {
      final loader = FontLoader('UxPreview');
      loader.addFont(File(_fontPath).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
    if (_iconPath.isNotEmpty) {
      final loader = FontLoader('MaterialIcons');
      loader.addFont(File(_iconPath).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });

  Future<void> capture(WidgetTester tester, String name) async {
    expect(tester.takeException(), isNull);
    if (_fontPath.isEmpty) return;
    // Asset decoding can outlive pumpAndSettle without scheduling a frame.
    // Wait for the exact providers used by mounted images before capturing.
    final imageElements = find.byType(Image).evaluate().toList();
    await tester.runAsync(() async {
      for (final element in imageElements) {
        final widget = element.widget as Image;
        await precacheImage(widget.image, element);
      }
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_boundary),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory('build/ux_review');
        await directory.create(recursive: true);
        await File(
          '${directory.path}/$name.png',
        ).writeAsBytes(png!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  for (final language in ['ja', 'en']) {
    testWidgets('sample $language real assets, 320dp and 200% text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = SamplePreviewService(rootBundle);
      final catalogs = SampleCatalog.forLocale(language);
      // Real bundle loading is explicitly awaited outside the fake test clock.
      // No replacement image or text fixtures can mask a missing bundled asset.
      await tester.runAsync(() async {
        for (final catalog in catalogs) {
          for (final asset in catalog.assets) {
            expect(await service.load(asset), isNotEmpty, reason: asset);
          }
        }
      });
      var adds = 0;
      var theme = AppTheme.light.copyWith(platform: TargetPlatform.android);
      if (_fontPath.isNotEmpty) {
        theme = theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'UxPreview'),
          appBarTheme: theme.appBarTheme.copyWith(
            titleTextStyle:
                (theme.appBarTheme.titleTextStyle ??
                        theme.textTheme.titleLarge ??
                        const TextStyle())
                    .copyWith(fontFamily: 'UxPreview'),
          ),
          primaryTextTheme: theme.primaryTextTheme.apply(
            fontFamily: 'UxPreview',
          ),
          chipTheme: theme.chipTheme.copyWith(
            labelStyle: (theme.chipTheme.labelStyle ?? const TextStyle())
                .copyWith(fontFamily: 'UxPreview'),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: (theme.filledButtonTheme.style ?? const ButtonStyle())
                .copyWith(
                  textStyle: WidgetStatePropertyAll(
                    (theme.textTheme.labelLarge ?? const TextStyle()).copyWith(
                      fontFamily: 'UxPreview',
                    ),
                  ),
                ),
          ),
        );
      }
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            samplePreviewServiceProvider.overrideWith((ref) => service),
          ],
          child: MaterialApp(
            locale: Locale(language),
            theme: theme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: RepaintBoundary(key: _boundary, child: child!),
            ),
            home: SamplePreviewScreen(onAddFiles: () => adds++),
          ),
        ),
      );
      final context = tester.element(find.byType(SamplePreviewScreen));
      await tester.runAsync(() async {
        for (final catalog in catalogs.where(
          (sample) => sample.kind != SampleKind.text,
        )) {
          for (final asset in catalog.assets) {
            await precacheImage(
              MemoryImage(await service.load(asset)),
              context,
            );
          }
        }
      });
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(context)!;
      final names = {
        SampleKind.photos: l10n.samplePhotoTitle,
        SampleKind.art: l10n.sampleArtTitle,
        SampleKind.music: l10n.sampleMusicTitle,
        SampleKind.text: l10n.sampleTextTitle,
      };
      for (final catalog in catalogs) {
        final scrollable = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        scrollable.position.jumpTo(0);
        await tester.pumpAndSettle();
        if (catalog.kind == SampleKind.photos) {
          await capture(tester, 'sample_${language}_shelf');
        }
        final shelf = find.byKey(
          ValueKey('sample-shelf-${catalog.kind.name}'),
          skipOffstage: false,
        );
        // Longer translated copy can place the final lazy list item beyond
        // the cache extent. Reach it through the same scrolling users need.
        await tester.scrollUntilVisible(
          shelf,
          160,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(shelf.hitTestable(), findsOneWidget);
        await tester.tap(shelf);
        await tester.pumpAndSettle();
        expect(find.text(names[catalog.kind]!), findsWidgets);
        final content = find.byKey(
          ValueKey(catalog.assets.first),
          skipOffstage: false,
        );
        // Large translated content can be outside the lazy list cache.
        await tester.scrollUntilVisible(
          content,
          160,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.samplePreviewLoadError), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        if (catalog.kind == SampleKind.text) {
          expect(
            find.textContaining(language == 'ja' ? '読書メモ' : 'Reading Notes'),
            findsOneWidget,
          );
        } else {
          expect(
            tester
                .widget<RawImage>(
                  find.descendant(of: content, matching: find.byType(RawImage)),
                )
                .image,
            isNotNull,
          );
        }
        await capture(tester, 'sample_${language}_${catalog.kind.name}');
        if (catalog.kind == SampleKind.music) {
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('sample-music-explanation')),
            -160,
            scrollable: find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await capture(tester, 'sample_${language}_music_explanation');
        }
        // Cover every image, including noninitial photos/art pages.
        for (var page = 1; page < catalog.assets.length; page++) {
          final next = find.byTooltip(
            MaterialLocalizations.of(context).nextPageTooltip,
            skipOffstage: false,
          );
          // Large translated content can be outside the lazy list cache.
          await tester.scrollUntilVisible(
            next,
            160,
            scrollable: find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.tap(next);
          await tester.pumpAndSettle();
          final pageContent = find.byKey(
            ValueKey(catalog.assets[page]),
            skipOffstage: false,
          );
          // Large translated content can be outside the lazy list cache.
          await tester.scrollUntilVisible(
            pageContent,
            160,
            scrollable: find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<RawImage>(
                  find.descendant(
                    of: pageContent,
                    matching: find.byType(RawImage),
                  ),
                )
                .image,
            isNotNull,
          );
        }
        final add = find.widgetWithText(
          FilledButton,
          l10n.samplePreviewAddFiles,
        );
        await tester.scrollUntilVisible(
          add,
          200,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
          maxScrolls: 60,
        );
        await tester.pumpAndSettle();
        expect(add.hitTestable(), findsOneWidget);
        await tester.tap(add);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(adds, catalogs.length);
    });
  }
}
