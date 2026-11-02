import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/services/secure_storage_service.dart';
import 'package:private_shelf/features/security/domain/repositories/security_repository.dart';
import 'package:private_shelf/features/security/presentation/providers/security_repository_provider.dart';
import 'package:private_shelf/features/security/presentation/providers/passcode_provider.dart';
import 'package:private_shelf/features/security/presentation/screens/passcode_screen.dart';
import 'package:private_shelf/features/settings/data/repositories/privacy_repository.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSecureStorage extends Mock implements SecureStorageService {}

class _MockSecurityRepository extends Mock implements SecurityRepository {}

void main() {
  testWidgets('ロックアウト中は残り待機秒数を表示する', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = _MockSecureStorage();
    final securityRepository = _MockSecurityRepository();
    final lockoutUntil = DateTime.now().add(const Duration(seconds: 30));
    when(() => storage.read(key: SecureStorageKeys.pinLockoutState)).thenAnswer(
      (_) async => Result.success(
        jsonEncode({
          'version': 1,
          'failedAttempts': PasscodeNotifier.maxAttempts,
          'lockoutUntil': lockoutUntil.toUtc().toIso8601String(),
        }),
      ),
    );
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async => Result.success(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(storage),
          securityRepositoryProvider.overrideWithValue(securityRepository),
          privacyRepositoryProvider.overrideWithValue(
            PrivacyRepository(preferences),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('ja'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('ja'), Locale('en')],
          home: PasscodeScreen(mode: PasscodeMode.unlock),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AppText &&
            (widget.data?.contains('秒後に再試行してください') ?? false),
      ),
      findsOneWidget,
    );
  });
}
