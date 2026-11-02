import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/app/fresh_start_scope.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/router/deep_link_handler.dart';
import 'package:private_shelf/core/theme/theme_provider.dart';
import 'package:private_shelf/core/providers/shared_preferences_provider.dart';
import 'package:private_shelf/features/settings/data/repositories/privacy_repository.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/locale_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:private_shelf/features/security/domain/repositories/security_repository.dart';
import 'package:private_shelf/features/security/presentation/providers/security_repository_provider.dart';
import 'package:private_shelf/features/security/presentation/providers/security_guard_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SecurityRepository extends Mock implements SecurityRepository {}

class _RealSettingsProbe extends ConsumerWidget {
  const _RealSettingsProbe();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeModeAsyncProvider);
    ref.watch(appLocaleAsyncProvider);
    ref.watch(appModeAsyncProvider);
    ref.watch(privacySettingsNotifierProvider);
    ref.watch(securityGuardProvider);
    ref.watch(pendingDeepLinkLocationProvider);
    return const MaterialApp(home: SizedBox());
  }
}

final _cachedSettings = Provider<Map<String, String>>(
  (ref) => Map.of(_persisted),
);
Map<String, String> _persisted = {};

class _SettingsProbe extends ConsumerWidget {
  const _SettingsProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          Text(ref.watch(_cachedSettings).toString()),
          TextButton(
            onPressed: () {
              _persisted = {};
              ref.read(freshStartCompletedCallbackProvider)();
            },
            child: const Text('complete reset'),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets(
    'real settings, PIN guard and pending navigation return to defaults',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'theme_mode': ThemeMode.dark.index,
        'app_locale': 'en',
        'app_mode': AppMode.external.index,
        'privacy_settings': '{"isAppLockEnabled":true}',
        'import_flow_draft_session_v1': 'old draft',
      });
      final prefs = await SharedPreferences.getInstance();
      final security = _SecurityRepository();
      var passcodeExists = true;
      when(
        () => security.hasPasscode(),
      ).thenAnswer((_) async => Result.success(passcodeExists));
      await tester.pumpWidget(
        FreshStartScope(
          overrides: [
            sharedPreferencesProvider.overrideWith((ref) async => prefs),
            privacyRepositoryProvider.overrideWithValue(
              PrivacyRepository(prefs),
            ),
            securityRepositoryProvider.overrideWithValue(security),
          ],
          child: const _RealSettingsProbe(),
        ),
      );
      await tester.pumpAndSettle();
      var container = ProviderScope.containerOf(
        tester.element(find.byType(_RealSettingsProbe)),
      );
      expect(
        await container.read(themeModeAsyncProvider.future),
        ThemeMode.dark,
      );
      expect(
        await container.read(appLocaleAsyncProvider.future),
        const Locale('en'),
      );
      expect(
        await container.read(appModeAsyncProvider.future),
        AppMode.external,
      );
      expect(
        (await container.read(
          privacySettingsNotifierProvider.future,
        )).isAppLockEnabled,
        isTrue,
      );
      expect(await container.read(securityGuardProvider.future), isFalse);
      container.read(pendingDeepLinkLocationProvider.notifier).state = '/old';
      await prefs.clear();
      passcodeExists = false;
      container.read(freshStartCompletedCallbackProvider)();
      await tester.pumpAndSettle();
      container = ProviderScope.containerOf(
        tester.element(find.byType(_RealSettingsProbe)),
      );
      expect(
        await container.read(themeModeAsyncProvider.future),
        ThemeMode.system,
      );
      expect(await container.read(appLocaleAsyncProvider.future), isNull);
      expect(
        await container.read(appModeAsyncProvider.future),
        AppMode.internal,
      );
      expect(
        (await container.read(
          privacySettingsNotifierProvider.future,
        )).isAppLockEnabled,
        isFalse,
      );
      expect(await container.read(securityGuardProvider.future), isTrue);
      expect(container.read(pendingDeepLinkLocationProvider), isNull);
      expect(prefs.getString('import_flow_draft_session_v1'), isNull);
    },
  );

  testWidgets('reset recreates the container and discards cached settings', (
    tester,
  ) async {
    _persisted = {
      'privacy': 'locked',
      'theme': 'dark',
      'locale': 'en',
      'mode': 'external',
      'draft': 'old',
      'deep-link': '/old',
    };
    await tester.pumpWidget(
      const FreshStartScope(overrides: [], child: _SettingsProbe()),
    );
    expect(find.textContaining('locked'), findsOneWidget);
    final oldContainer = ProviderScope.containerOf(
      tester.element(find.byType(_SettingsProbe)),
    );
    await tester.tap(find.text('complete reset'));
    await tester.pumpAndSettle();
    expect(find.text('{}'), findsOneWidget);
    expect(
      ProviderScope.containerOf(tester.element(find.byType(_SettingsProbe))),
      isNot(same(oldContainer)),
    );
  });
}
