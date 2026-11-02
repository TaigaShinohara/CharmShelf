import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/core/theme/app_theme.dart';
import 'package:private_shelf/features/onboarding/presentation/onboarding_screen.dart';
import 'package:private_shelf/features/library/presentation/widgets/catalog_registration_icon.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/icon/catalogize_icon.dart';
import 'package:private_shelf/shared/widgets/icon/charm_icon.dart';

// Ordinary golden runs retain Flutter's deterministic test font. Supplying
// the same optional font defines as existing visual QA tests instead writes
// readable review evidence, without making checked-in baselines host-dependent.
const _fontPath = String.fromEnvironment('UX_QA_FONT');
const _iconPath = String.fromEnvironment('UX_QA_ICON_FONT');
const _outputPath = String.fromEnvironment(
  'UX_QA_OUTPUT',
  defaultValue: 'build/ux_review/onboarding-entry-and-guide',
);
const _boundaryKey = ValueKey('onboarding-review-boundary');
const _nextKey = ValueKey('onboarding-next');

ThemeData _theme(Brightness brightness) {
  var theme = (brightness == Brightness.dark ? AppTheme.dark : AppTheme.light)
      .copyWith(platform: TargetPlatform.android);
  if (_fontPath.isNotEmpty) {
    const family = 'UxPreview';
    theme = theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: family),
      primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: family),
      appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle:
            (theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge)
                ?.copyWith(fontFamily: family),
      ),
      chipTheme: theme.chipTheme.copyWith(
        labelStyle: (theme.chipTheme.labelStyle ?? const TextStyle()).copyWith(
          fontFamily: family,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: (theme.filledButtonTheme.style ?? const ButtonStyle()).copyWith(
          textStyle: WidgetStatePropertyAll(
            (theme.textTheme.labelLarge ?? const TextStyle()).copyWith(
              fontFamily: family,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: (theme.textButtonTheme.style ?? const ButtonStyle()).copyWith(
          textStyle: WidgetStatePropertyAll(
            (theme.textTheme.labelLarge ?? const TextStyle()).copyWith(
              fontFamily: family,
            ),
          ),
        ),
      ),
    );
  }
  return theme;
}

Future<void> _pumpJourney(
  WidgetTester tester, {
  String locale = 'ja',
  Size size = const Size(390, 844),
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  // Start each visual condition with a fresh entry and guide state.
  await tester.pumpWidget(const SizedBox.shrink());
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [hapticsEnabledProvider.overrideWith((ref) => false)],
      child: MaterialApp(
        locale: Locale(locale),
        theme: _theme(brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: RepaintBoundary(key: _boundaryKey, child: child!),
        ),
        home: OnboardingScreen(onComplete: () {}, onTrySample: () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Key key) async {
  final button = find.byKey(key);
  await Scrollable.ensureVisible(tester.element(button), alignment: .5);
  expect(button.hitTestable(), findsOneWidget);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  // Finish decoding real bundled examples before either a baseline or review
  // capture. They can otherwise finish outside the fake animation clock.
  final imageElements = find.byType(Image).evaluate().toList();
  await tester.runAsync(() async {
    for (final element in imageElements) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  if (_fontPath.isEmpty) {
    await expectLater(
      find.byKey(_boundaryKey),
      matchesGoldenFile('goldens/goldens/onboarding-journey/$name.png'),
    );
    return;
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundaryKey),
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

void main() {
  if (Platform.isLinux) {
    // macOSで生成されたゴールデンとLinux環境のフォント/レンダリング差異が大きいため、
    // Linux上ではゴールデンテストをスキップする。
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final (family, path) in [
      ('UxPreview', _fontPath),
      ('MaterialIcons', _iconPath),
    ]) {
      if (path.isEmpty) continue;
      final loader = FontLoader(family);
      loader.addFont(File(path).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });
  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name} catalog and charm symbols at product sizes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final theme = _theme(brightness);
      final colors = theme.colorScheme;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: RepaintBoundary(
            key: _boundaryKey,
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('カタログ・チャーム・外部参照'),
                    for (final size in [7.0, 10.0, 18.0, 24.0, 32.0])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 48,
                              child: Text('${size.toInt()}dp'),
                            ),
                            SizedBox(
                              width: 48,
                              child: Center(
                                child: CatalogizeIcon(
                                  size: size,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 48,
                              child: Center(
                                child: CharmIcon(
                                  size: size,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 48,
                              child: Center(
                                child: Icon(
                                  Icons.link,
                                  size: size,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(1.5),
                              decoration: BoxDecoration(
                                color: colors.scrim.withValues(alpha: .4),
                                shape: BoxShape.circle,
                              ),
                              child: CatalogizeIcon(
                                size: size,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        CatalogizeIcon.release(size: 32, color: colors.primary),
                        const CatalogRegistrationIcon.folder(),
                        const CatalogRegistrationIcon.file(),
                        CharmIcon.add(size: 32, color: colors.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _capture(tester, '${brightness.name}-chain-charm-symbols');
    }, tags: 'golden');
  }
  for (final locale in ['ja', 'en']) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '$locale ${brightness.name} entry and optional guide at $scale×',
          (tester) async {
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await _pumpJourney(
              tester,
              locale: locale,
              brightness: brightness,
              size: scale == 1 ? const Size(390, 844) : const Size(320, 568),
              textScale: scale,
            );
            final prefix =
                '$locale-${brightness.name}-${(scale * 100).toInt()}pct';
            await _capture(tester, '$prefix-entry-top');
            if (scale == 2) {
              await tester.drag(
                find.byKey(const PageStorageKey('onboarding-page-0')),
                const Offset(0, -1800),
              );
              await _capture(tester, '$prefix-entry-bottom');
            }
            await _tap(tester, const ValueKey('onboarding-guide'));
            for (var page = 0; page < 3; page++) {
              final scene = ['chain', 'charms', 'data'][page];
              await _capture(tester, '$prefix-guide-$scene-top');
              if (scale == 2) {
                await tester.drag(
                  find.byKey(PageStorageKey('onboarding-page-$page')),
                  const Offset(0, -1800),
                );
                await _capture(tester, '$prefix-guide-$scene-bottom');
              }
              if (page < 2) await _tap(tester, _nextKey);
            }
            await _tap(tester, const ValueKey('onboarding-guide-close'));
            expect(
              find.byKey(const ValueKey('onboarding-sample')),
              findsOneWidget,
            );
          },
          tags: 'golden',
        );
      }
    }
    testWidgets('$locale: catalog selection stays above the example', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpJourney(tester, locale: locale);
      await _tap(tester, const ValueKey('onboarding-guide'));
      await _tap(tester, const ValueKey('onboarding-catalog-music'));
      await _capture(tester, '$locale-guide-catalog-music');
    }, tags: 'golden');
    testWidgets('$locale: first actions remain available at 320×400 and 200%', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpJourney(
        tester,
        locale: locale,
        size: const Size(320, 400),
        textScale: 2,
      );
      await _capture(tester, '$locale-200pct-short-entry');
      for (final key in [_nextKey, const ValueKey('onboarding-sample')]) {
        final action = find.byKey(key);
        await tester.ensureVisible(action);
        expect(action.hitTestable(), findsOneWidget);
        expect(MediaQuery.textScalerOf(tester.element(action)).scale(16), 32);
      }
      await _tap(tester, const ValueKey('onboarding-guide'));
      for (var page = 0; page < 3; page++) {
        await _capture(tester, '$locale-200pct-short-guide-$page-top');
        await tester.drag(
          find.byKey(PageStorageKey('onboarding-page-$page')),
          const Offset(0, -1800),
        );
        await _capture(tester, '$locale-200pct-short-guide-$page-bottom');
        if (page < 2) await _tap(tester, _nextKey);
      }
    }, tags: 'golden');
  }
}
