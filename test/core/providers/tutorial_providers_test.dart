import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/preferences/app_preferences.dart';
import 'package:private_shelf/core/providers/shared_preferences_provider.dart';
import 'package:private_shelf/core/providers/tutorial_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final reset in [false, true]) {
    test(
      'unwatched tutorial ${reset ? 'reset' : 'complete'} finishes after loading',
      () async {
        SharedPreferences.setMockInitialValues({
          'tutorial.library.completed': true,
          'unrelated.preference': true,
        });
        final prefs = await SharedPreferences.getInstance();
        final loaded = Completer<SharedPreferences>();
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            sharedPreferencesProvider.overrideWith((ref) => loaded.future),
          ],
        );
        addTearDown(container.dispose);
        final notifier = container.read(tutorialStateProvider.notifier);
        final operation = reset
            ? notifier.resetAll()
            : notifier.complete('library');
        await container.pump();
        expect(container.exists(tutorialStateProvider), isTrue);

        loaded.complete(prefs);
        await operation;
        expect(
          prefs.getBool('tutorial.library.completed'),
          reset ? isNull : isTrue,
        );
        expect(prefs.getBool('unrelated.preference'), isTrue);
      },
    );
  }

  test('既読判定は保存状態の読み込みを待ち、読み込み中を未読扱いしない', () async {
    SharedPreferences.setMockInitialValues({
      'tutorial.first_hide.completed': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final loaded = Completer<SharedPreferences>();
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => loaded.future),
      ],
    );
    addTearDown(container.dispose);
    var finished = false;
    final result = container
        .read(tutorialStateProvider.notifier)
        .isCompleted('first_hide')
        .then((value) {
          finished = true;
          return value;
        });
    await Future<void>.delayed(Duration.zero);
    expect(finished, isFalse);
    loaded.complete(prefs);
    expect(await result, isTrue);
    expect(
      await container
          .read(tutorialStateProvider.notifier)
          .isCompleted('first_archive'),
      isFalse,
    );
  });

  test('既読状態の読み込み失敗を未読として隠さない', () async {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWith(
          (ref) async => throw StateError('prefs unavailable'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(tutorialStateProvider.notifier).isCompleted('first_hide'),
      throwsStateError,
    );
  });

  test('resetAllはすべての案内状態だけを未読へ戻す', () async {
    SharedPreferences.setMockInitialValues({
      'tutorial.library.completed': true,
      'tutorial.home.completed': true,
      AppPreferences.onboardingCompletedKey: true,
      AppPreferences.importPickerGuideDismissedKey: true,
      'feature_tooltip.example.shown': true,
      'feature_tooltip.example.never': true,
      'unrelated.preference': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [sharedPreferencesProvider.overrideWith((ref) async => prefs)],
    );
    addTearDown(container.dispose);

    await container.read(tutorialStateProvider.future);
    await container.read(tutorialStateProvider.notifier).resetAll();

    expect(prefs.getBool('tutorial.library.completed'), isNull);
    expect(prefs.getBool('tutorial.home.completed'), isNull);
    expect(prefs.getBool(AppPreferences.onboardingCompletedKey), isNull);
    expect(prefs.getBool(AppPreferences.importPickerGuideDismissedKey), isNull);
    expect(prefs.getBool('feature_tooltip.example.shown'), isNull);
    expect(prefs.getBool('feature_tooltip.example.never'), isNull);
    expect(prefs.getBool('unrelated.preference'), isTrue);
    expect(container.read(tutorialStateProvider).value, isEmpty);
  });
}
