import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/core/providers/shared_preferences_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HapticsEnabledAsync', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      container.dispose();
    });

    test('デフォルト値はtrue', () async {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith(
            (ref) async => SharedPreferences.getInstance(),
          ),
        ],
      );

      await container.read(hapticsEnabledAsyncProvider.future);
      final enabled = container.read(hapticsEnabledProvider);

      expect(enabled, true);
    });

    test('保存された値を読み込める', () async {
      SharedPreferences.setMockInitialValues({'haptics_enabled': false});
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith(
            (ref) async => SharedPreferences.getInstance(),
          ),
        ],
      );

      await container.read(hapticsEnabledAsyncProvider.future);
      final enabled = container.read(hapticsEnabledProvider);

      expect(enabled, false);
    });

    test('setValueで値を保存できる', () async {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith(
            (ref) async => SharedPreferences.getInstance(),
          ),
        ],
      );

      await container.read(hapticsEnabledAsyncProvider.future);
      await container
          .read(hapticsEnabledAsyncProvider.notifier)
          .setValue(false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('haptics_enabled'), false);
    });
  });

  group('SoundEnabledAsync', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      container.dispose();
    });

    test('デフォルト値はtrue', () async {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith(
            (ref) async => SharedPreferences.getInstance(),
          ),
        ],
      );

      await container.read(soundEnabledAsyncProvider.future);
      final enabled = container.read(soundEnabledProvider);

      expect(enabled, true);
    });

    test('保存された値を読み込める', () async {
      SharedPreferences.setMockInitialValues({'sound_enabled': false});
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith(
            (ref) async => SharedPreferences.getInstance(),
          ),
        ],
      );

      await container.read(soundEnabledAsyncProvider.future);
      final enabled = container.read(soundEnabledProvider);

      expect(enabled, false);
    });

    test('setValueで値を保存できる', () async {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith(
            (ref) async => SharedPreferences.getInstance(),
          ),
        ],
      );

      await container.read(soundEnabledAsyncProvider.future);
      await container.read(soundEnabledAsyncProvider.notifier).setValue(false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('sound_enabled'), false);
    });
  });

  group('FeedbackService', () {
    test('hapticsEnabledがfalseの場合でもエラーなく完了する', () async {
      final container = ProviderContainer(
        overrides: [
          hapticsEnabledProvider.overrideWith((ref) => false),
          soundEnabledProvider.overrideWith((ref) => false),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(feedbackServiceProvider);

      await expectLater(service.lightImpact(), completes);
      await expectLater(service.lightTap(), completes);
      await expectLater(service.mediumImpact(), completes);
      await expectLater(service.mediumTap(), completes);
      await expectLater(service.heavyImpact(), completes);
      await expectLater(service.heavyTap(), completes);
      await expectLater(service.selection(), completes);
      await expectLater(service.tap(), completes);
      await expectLater(service.success(), completes);
      await expectLater(service.error(), completes);
    });

    test('hapticsEnabledがtrueの場合でもエラーなく完了する', () async {
      final container = ProviderContainer(
        overrides: [
          hapticsEnabledProvider.overrideWith((ref) => true),
          soundEnabledProvider.overrideWith((ref) => false),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(feedbackServiceProvider);

      await expectLater(service.lightImpact(), completes);
      await expectLater(service.selection(), completes);
      await expectLater(service.tap(), completes);
    });
  });
}
