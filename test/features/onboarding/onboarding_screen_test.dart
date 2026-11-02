import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/features/onboarding/presentation/onboarding_screen.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

const _next = ValueKey('onboarding-next');
const _previous = ValueKey('onboarding-previous');
const _sample = ValueKey('onboarding-sample');
const _guide = ValueKey('onboarding-guide');
const _closeGuide = ValueKey('onboarding-guide-close');
const _progress = ValueKey('onboarding-page-progress');

Widget subject({
  required VoidCallback onComplete,
  VoidCallback? onTrySample,
  bool preview = false,
  bool afterWelcome = false,
  bool disableAnimations = true,
  bool accessibleNavigation = false,
  double textScale = 1,
  Locale locale = const Locale('ja'),
}) => ProviderScope(
  overrides: [hapticsEnabledProvider.overrideWith((ref) => false)],
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: disableAnimations,
        accessibleNavigation: accessibleNavigation,
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: OnboardingScreen(
      onComplete: onComplete,
      onTrySample: onTrySample,
      preview: preview,
      afterWelcome: afterWelcome,
    ),
  ),
);

AppLocalizations _l10n(WidgetTester tester) => AppLocalizations.of(
  tester.element(find.byType(OnboardingScreen, skipOffstage: false)),
)!;

Finder _page(int index) => find.byKey(PageStorageKey('onboarding-page-$index'));

List<String> _guideTitles(AppLocalizations l10n) => [
  l10n.onboardingCatalogTitle,
  l10n.onboardingTaggingTitle,
  l10n.onboardingDataTitle,
];

void _expectGuidePage(WidgetTester tester, int index) {
  expect(tester.widget<Text>(find.byKey(_progress)).data, '${index + 1} / 3');
  expect(
    find.descendant(
      of: _page(index),
      matching: find.text(_guideTitles(_l10n(tester))[index]),
    ),
    findsOneWidget,
  );
  expect(tester.takeException(), isNull);
}

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder get _motions => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith('onboarding-motion-');
});

void main() {
  for (final locale in ['ja', 'en']) {
    testWidgets(
      '$locale: collection story keeps the same photos in both steps',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          subject(
            onComplete: () {},
            onTrySample: () {},
            locale: Locale(locale),
          ),
        );
        final l10n = _l10n(tester);
        final collect = find.byKey(const ValueKey('onboarding-collect-step'));
        final personalize = find.byKey(
          const ValueKey('onboarding-personalize-step'),
        );
        expect(
          tester.getTopLeft(collect).dy,
          lessThan(tester.getTopLeft(personalize).dy),
        );
        Set<String> photoAssets(Finder step) => tester
            .widgetList<Image>(
              find.descendant(of: step, matching: find.byType(Image)),
            )
            .map((image) {
              final provider = image.image is ResizeImage
                  ? (image.image as ResizeImage).imageProvider
                  : image.image;
              return (provider as AssetImage).assetName;
            })
            .toSet();
        expect(photoAssets(collect), hasLength(3));
        expect(photoAssets(personalize), photoAssets(collect));
        for (final label in [
          l10n.onboardingCollectLabel,
          l10n.onboardingCollectMessage,
          l10n.onboardingPersonalizeLabel,
          l10n.onboardingPersonalizeMessage,
          l10n.onboardingCharmTravel,
          l10n.onboardingCharmLandscape,
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        expect(find.text(l10n.onboardingPreviewLabel), findsNothing);
        expect(find.byKey(_next).hitTestable(), findsOneWidget);
        expect(find.byKey(_sample).hitTestable(), findsOneWidget);
        expect(find.byKey(_guide).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$locale: story is read as two steps without decorative images',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            subject(onComplete: () {}, locale: Locale(locale)),
          );
          final l10n = _l10n(tester);
          for (final (key, label, message) in [
            (
              'onboarding-collect-step',
              l10n.onboardingCollectLabel,
              l10n.onboardingCollectMessage,
            ),
            (
              'onboarding-personalize-step',
              l10n.onboardingPersonalizeLabel,
              l10n.onboardingPersonalizeMessage,
            ),
          ]) {
            final node = tester.getSemantics(find.byKey(ValueKey(key)));
            expect(node.label, contains('$label\n$message'));
            expect(node.label, isNot(contains('assets/')));
          }
        } finally {
          semantics.dispose();
        }
      },
    );

    for (final action in [_next, _sample]) {
      testWidgets(
        '$locale: $action starts directly without answering or reading',
        (tester) async {
          var completed = 0;
          var samples = 0;
          await tester.pumpWidget(
            subject(
              onComplete: () => completed++,
              onTrySample: () => samples++,
              locale: Locale(locale),
            ),
          );
          final l10n = _l10n(tester);
          expect(find.text(l10n.onboardingWelcomeTitle), findsOneWidget);
          expect(find.text(l10n.onboardingWelcomeMessage), findsOneWidget);
          expect(find.text(l10n.onboardingNeedTitle), findsNothing);
          expect(find.text(l10n.onboardingSupportTitle), findsNothing);
          expect(find.text(l10n.onboardingReviewTitle), findsNothing);
          expect(find.byKey(_progress), findsNothing);
          expect(find.byKey(_previous), findsNothing);
          expect(find.byKey(_sample), findsOneWidget);
          expect(
            tester.widget<FilledButton>(find.byKey(_next)).onPressed,
            isNotNull,
          );
          await _tap(tester, action);
          await _tap(tester, action);
          await _tap(tester, action == _next ? _sample : _next);
          expect(completed, action == _next ? 1 : 0);
          expect(samples, action == _sample ? 1 : 0);
        },
      );
    }

    testWidgets(
      '$locale: optional guide keeps chain, charm, and data explanations',
      (tester) async {
        var completed = 0;
        await tester.pumpWidget(
          subject(onComplete: () => completed++, locale: Locale(locale)),
        );
        await _tap(tester, _guide);
        final l10n = _l10n(tester);
        for (var page = 0; page < 3; page++) {
          _expectGuidePage(tester, page);
          expect(find.byKey(_closeGuide).hitTestable(), findsOneWidget);
          if (page == 2) {
            for (final explanation in [
              l10n.onboardingDataCopy,
              l10n.onboardingDataReference,
              l10n.onboardingDataBackup,
              l10n.onboardingDataLimits,
            ]) {
              final text = find.text(explanation);
              await tester.ensureVisible(text);
              expect(text.hitTestable(), findsOneWidget);
            }
          }
          await _tap(tester, _next);
        }
        expect(find.byKey(_guide), findsOneWidget);
        expect(find.byKey(_progress), findsNothing);
        expect(completed, 0);
        await _tap(tester, _next);
        expect(completed, 1);
      },
    );

    for (final height in [568.0, 400.0]) {
      testWidgets(
        '$locale: entry and optional guide at 320×$height and 200% remain operable',
        (tester) async {
          tester.view.physicalSize = Size(320, height);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var samples = 0;
          await tester.pumpWidget(
            subject(
              onComplete: () {},
              onTrySample: () => samples++,
              textScale: 2,
              locale: Locale(locale),
            ),
          );
          expect(
            MediaQuery.textScalerOf(
              tester.element(find.byKey(_next)),
            ).scale(16),
            32,
          );
          for (final action in [_next, _sample, _guide]) {
            await tester.ensureVisible(find.byKey(action));
            expect(find.byKey(action).hitTestable(), findsOneWidget);
          }
          for (final message in [
            _l10n(tester).onboardingCollectMessage,
            _l10n(tester).onboardingPersonalizeMessage,
            _l10n(tester).onboardingCharmLandscape,
          ]) {
            await tester.ensureVisible(find.text(message));
            expect(find.text(message).hitTestable(), findsOneWidget);
          }
          await _tap(tester, _guide);
          for (var page = 0; page < 3; page++) {
            _expectGuidePage(tester, page);
            await tester.drag(_page(page), const Offset(0, -1200));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            if (page == 0) {
              await _tap(tester, const ValueKey('onboarding-catalog-music'));
            }
            if (page > 0) {
              await tester.ensureVisible(find.byKey(_previous));
              expect(find.byKey(_previous).hitTestable(), findsOneWidget);
            }
            await _tap(tester, _next);
          }
          await _tap(tester, _sample);
          expect(samples, 1);
        },
      );
    }
  }

  for (final page in [0, 1, 2]) {
    testWidgets(
      'optional guide can close on page $page without completing onboarding',
      (tester) async {
        var completed = 0;
        await tester.pumpWidget(subject(onComplete: () => completed++));
        await _tap(tester, _guide);
        for (var index = 0; index < page; index++) {
          await _tap(tester, _next);
        }
        await _tap(tester, _closeGuide);
        expect(find.byKey(_guide), findsOneWidget);
        expect(completed, 0);
      },
    );
  }

  testWidgets(
    'catalog selection appears before the preview and survives page navigation',
    (tester) async {
      await tester.pumpWidget(subject(onComplete: () {}));
      await _tap(tester, _guide);
      final music = find.byKey(const ValueKey('onboarding-catalog-music'));
      final example = find.text(_l10n(tester).onboardingCatalogMusicAlbum);
      await _tap(tester, const ValueKey('onboarding-catalog-music'));
      expect(tester.widget<ChoiceChip>(music).selected, isTrue);
      expect(
        tester.getBottomLeft(music).dy,
        lessThan(tester.getTopLeft(example).dy),
      );
      await _tap(tester, _next);
      await _tap(tester, _previous);
      expect(tester.widget<ChoiceChip>(music).selected, isTrue);
    },
  );

  testWidgets(
    'system back returns through the optional guide before closing it',
    (tester) async {
      var completed = 0;
      await tester.pumpWidget(subject(onComplete: () => completed++));
      await _tap(tester, _guide);
      await _tap(tester, _next);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      _expectGuidePage(tester, 0);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(_guide), findsOneWidget);
      expect(completed, 0);
    },
  );

  testWidgets(
    'settings preview closes once and retains access to the optional guide',
    (tester) async {
      var closed = 0;
      await tester.pumpWidget(
        subject(onComplete: () => closed++, preview: true, onTrySample: () {}),
      );
      expect(find.byKey(_sample), findsNothing);
      await _tap(tester, _guide);
      await _tap(tester, _closeGuide);
      expect(closed, 0);
      expect(find.text(_l10n(tester).onboardingClose), findsOneWidget);
      await _tap(tester, _next);
      await _tap(tester, _next);
      expect(closed, 1);
    },
  );

  testWidgets(
    'screen readers receive guide headings, progress, and selected choices',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(subject(onComplete: () {}));
        await _tap(tester, _guide);
        for (var page = 0; page < 3; page++) {
          final l10n = _l10n(tester);
          final heading = find.text(_guideTitles(l10n)[page]);
          await tester.ensureVisible(heading);
          expect(
            tester
                .getSemantics(heading)
                .getSemanticsData()
                .flagsCollection
                .isHeader,
            isTrue,
          );
          final progress = tester
              .getSemantics(find.byKey(_progress))
              .getSemanticsData();
          expect(progress.label, l10n.onboardingPagePosition(page + 1, 3));
          expect(progress.flagsCollection.isLiveRegion, isTrue);
          if (page == 0) {
            await _tap(tester, const ValueKey('onboarding-catalog-music'));
            expect(
              tester
                  .getSemantics(
                    find.byKey(const ValueKey('onboarding-catalog-music')),
                  )
                  .getSemanticsData()
                  .flagsCollection
                  .isSelected,
              ui.Tristate.isTrue,
            );
          }
          if (page < 2) await _tap(tester, _next);
        }
      } finally {
        semantics.dispose();
      }
    },
  );

  for (final setting in ['disableAnimations', 'accessibleNavigation']) {
    testWidgets('$setting displays static entry and guide', (tester) async {
      await tester.pumpWidget(
        subject(
          onComplete: () {},
          disableAnimations: setting == 'disableAnimations',
          accessibleNavigation: setting == 'accessibleNavigation',
        ),
      );
      expect(_motions, findsNothing);
      await _tap(tester, _guide);
      for (var page = 0; page < 3; page++) {
        _expectGuidePage(tester, page);
        expect(_motions, findsNothing);
        if (page < 2) await _tap(tester, _next);
      }
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  }

  testWidgets('arrival motion does not delay the first add action', (
    tester,
  ) async {
    var completed = 0;
    await tester.pumpWidget(
      subject(
        onComplete: () => completed++,
        disableAnimations: false,
        afterWelcome: true,
      ),
    );
    expect(
      find.byKey(const ValueKey('onboarding-motion-welcome')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(_next));
    await tester.pumpAndSettle();
    expect(completed, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
