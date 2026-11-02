import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/samples/data/sample_preview_service.dart';
import 'package:private_shelf/features/samples/presentation/sample_preview_screen.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

class _Bundle extends CachingAssetBundle {
  int attempts = 0;
  bool fail = true;
  @override
  Future<ByteData> load(String key) async {
    attempts++;
    if (fail) throw StateError('missing sample');
    return ByteData.sublistView(
      key.endsWith('.md')
          ? Uint8List.fromList(utf8.encode('Reading sample'))
          : base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
            ),
    );
  }
}

Future<void> _pumpSamples(
  WidgetTester tester, {
  required String language,
  double scale = 1,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final bundle = _Bundle()..fail = false;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        samplePreviewServiceProvider.overrideWith(
          (ref) => SamplePreviewService(bundle),
        ),
      ],
      child: MaterialApp(
        locale: Locale(language),
        theme: ThemeData(brightness: brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: SamplePreviewScreen(onAddFiles: () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final language in ['ja', 'en']) {
    testWidgets(
      '$language: all four choices and selected content fit the first viewport',
      (tester) async {
        await _pumpSamples(tester, language: language);
        final choices = [
          for (final kind in ['photos', 'art', 'music', 'text'])
            find.byKey(ValueKey('sample-shelf-$kind')),
        ];
        for (final choice in choices) {
          expect(choice.hitTestable(), findsOneWidget);
        }
        expect(
          tester.getTopLeft(choices[0]).dy,
          tester.getTopLeft(choices[1]).dy,
        );
        expect(
          tester.getTopLeft(choices[2]).dy,
          tester.getTopLeft(choices[3]).dy,
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(SamplePreviewScreen)),
        )!;
        expect(find.text(l10n.samplePhotoTitle).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$language: music explains cover-only preview before the image',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await _pumpSamples(tester, language: language);
          final music = find.byKey(const ValueKey('sample-shelf-music'));
          await tester.tap(music);
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(
            tester.element(find.byType(SamplePreviewScreen)),
          )!;
          final explanation = find.text(l10n.sampleMusicDescription);
          final image = find.byKey(
            const ValueKey(
              'assets/images/samples/music_album/night_focus_cover.png',
            ),
          );
          expect(explanation.hitTestable(), findsOneWidget);
          expect(
            tester.getBottomLeft(explanation).dy,
            lessThan(tester.getTopLeft(image).dy),
          );
          expect(
            tester
                .getSemantics(music)
                .getSemanticsData()
                .flagsCollection
                .isSelected,
            ui.Tristate.isTrue,
          );
          expect(find.byIcon(Icons.play_arrow), findsNothing);
          await tester.ensureVisible(find.text(l10n.samplePreviewNotSaved));
          expect(
            find.text(l10n.samplePreviewNotSaved).hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );

    for (final brightness in Brightness.values) {
      testWidgets(
        '$language: 200% ${brightness.name} keeps every category and add action reachable',
        (tester) async {
          await _pumpSamples(
            tester,
            language: language,
            scale: 2,
            brightness: brightness,
          );
          final l10n = AppLocalizations.of(
            tester.element(find.byType(SamplePreviewScreen)),
          )!;
          for (final kind in ['photos', 'art', 'music', 'text']) {
            final choice = find.byKey(ValueKey('sample-shelf-$kind'));
            await tester.ensureVisible(choice);
            expect(choice.hitTestable(), findsOneWidget);
            await tester.tap(choice);
            await tester.pumpAndSettle();
            expect(
              MediaQuery.textScalerOf(tester.element(choice)).scale(16),
              32,
            );
            expect(tester.takeException(), isNull);
          }
          final add = find.text(l10n.samplePreviewAddFiles);
          await tester.scrollUntilVisible(
            add,
            200,
            // SelectableText has an internal scrollable; scroll the screen.
            scrollable: find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(add.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'failure stays within preview, text retries and add action remains available',
    (tester) async {
      final bundle = _Bundle();
      var adds = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            samplePreviewServiceProvider.overrideWith(
              (ref) => SamplePreviewService(bundle),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SamplePreviewScreen(onAddFiles: () => adds++),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sample-shelf-text')));
      await tester.pumpAndSettle();
      expect(
        find.text("Couldn't open this example. You can try again."),
        findsOneWidget,
      );
      bundle.fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Reading sample'), findsOneWidget);
      await tester.ensureVisible(find.text('Add your files'));
      await tester.tap(find.text('Add your files'));
      expect(adds, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
