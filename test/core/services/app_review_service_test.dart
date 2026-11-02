import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/services/app_review_service.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _launchCountKey = 'app_review.launch_count';
const _firstLaunchAtKey = 'app_review.first_launch_at';
const _neverAskAgainKey = 'app_review.never_ask_again';
const _lastPromptAtKey = 'app_review.last_prompt_at';

void main() {
  late AppReviewService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = AppReviewService();
  });

  group('shouldPrompt', () {
    test('never_ask_againがtrueなら表示しない', () async {
      final now = DateTime.now();
      final prefs = await _preferences({
        _neverAskAgainKey: true,
        _launchCountKey: AppReviewService.defaultMinLaunchCount,
        _firstLaunchAtKey: now
            .subtract(const Duration(days: 60))
            .toIso8601String(),
      });

      final result = service.shouldPrompt(prefs);

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isFalse);
    });

    test('起動回数が閾値未満なら表示しない', () async {
      final prefs = await _preferences({
        _launchCountKey: AppReviewService.defaultMinLaunchCount - 1,
        _firstLaunchAtKey: DateTime.now()
            .subtract(const Duration(days: 60))
            .toIso8601String(),
      });

      final result = service.shouldPrompt(prefs);

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isFalse);
    });

    test('初回起動からの日数が不足なら表示しない', () async {
      final prefs = await _preferences({
        _launchCountKey: AppReviewService.defaultMinLaunchCount,
        _firstLaunchAtKey: DateTime.now()
            .subtract(const Duration(hours: 1))
            .toIso8601String(),
      });

      final result = service.shouldPrompt(prefs);

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isFalse);
    });

    test('前回表示からクールダウン中なら表示しない', () async {
      final now = DateTime.now();
      final prefs = await _preferences({
        _launchCountKey: AppReviewService.defaultMinLaunchCount,
        _firstLaunchAtKey: now
            .subtract(const Duration(days: 60))
            .toIso8601String(),
        _lastPromptAtKey: now
            .subtract(const Duration(days: 1))
            .toIso8601String(),
      });

      final result = service.shouldPrompt(prefs);

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isFalse);
    });

    test('全条件を満たせば表示する', () async {
      final now = DateTime.now();
      final prefs = await _preferences({
        _launchCountKey: AppReviewService.defaultMinLaunchCount,
        _firstLaunchAtKey: now
            .subtract(const Duration(days: 60))
            .toIso8601String(),
        _lastPromptAtKey: now
            .subtract(const Duration(days: 60))
            .toIso8601String(),
      });

      final result = service.shouldPrompt(prefs);

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isTrue);
    });
  });

  test('recordAppLaunchが起動回数を増加させ、初回日時を再設定しない', () async {
    final firstLaunchAt = DateTime.utc(2020, 1, 2, 3, 4, 5).toIso8601String();
    final prefs = await _preferences({
      _launchCountKey: 2,
      _firstLaunchAtKey: firstLaunchAt,
    });

    await service.recordAppLaunch(prefs);

    expect(prefs.getInt(_launchCountKey), 3);
    expect(prefs.getString(_firstLaunchAtKey), firstLaunchAt);
  });

  test('setNeverAskAgainとmarkPromptedNowが設定を保存する', () async {
    final prefs = await _preferences({});
    final before = DateTime.now();

    await service.setNeverAskAgain(prefs, true);
    await service.markPromptedNow(prefs);

    final savedPromptAt = DateTime.parse(prefs.getString(_lastPromptAtKey)!);
    final after = DateTime.now();
    expect(service.getNeverAskAgain(prefs), isTrue);
    expect(prefs.getBool(_neverAskAgainKey), isTrue);
    expect(savedPromptAt.isBefore(before), isFalse);
    expect(savedPromptAt.isAfter(after), isFalse);
  });

  testWidgets('評価ダイアログは後でを左、評価を右、非表示を最下部に表示する', (tester) async {
    final now = DateTime.now();
    final prefs = await _preferences({
      _launchCountKey: AppReviewService.defaultMinLaunchCount,
      _firstLaunchAtKey: now
          .subtract(const Duration(days: 60))
          .toIso8601String(),
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => service.maybePromptReview(context, prefs),
                child: const Text('表示'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('表示'));
    await tester.pumpAndSettle();

    final dialog = find.byKey(const ValueKey('app-review-dialog'));
    final later = find.byKey(const ValueKey('app-review-later-button'));
    final rate = find.byKey(const ValueKey('app-review-rate-button'));
    final never = find.byKey(const ValueKey('app-review-never-button'));

    expect(dialog, findsOneWidget);
    expect(find.byIcon(Icons.rate_review_rounded), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    expect(tester.getCenter(later).dx, lessThan(tester.getCenter(rate).dx));
    expect(tester.getSize(later).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(rate).height, greaterThanOrEqualTo(48));
    expect(tester.getCenter(never).dy, greaterThan(tester.getCenter(rate).dy));

    await tester.tap(later);
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
  });
}

Future<SharedPreferences> _preferences(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}
