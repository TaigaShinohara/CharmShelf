import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/security/domain/repositories/security_repository.dart';
import 'package:private_shelf/features/security/presentation/providers/security_repository_provider.dart';
import 'package:private_shelf/features/settings/data/repositories/privacy_repository.dart';
import 'package:private_shelf/features/settings/domain/models/privacy_settings.dart';
import 'package:private_shelf/features/settings/presentation/privacy_settings_page.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/finders.dart' as shared_find;

class _FakeSecurityRepository implements SecurityRepository {
  _FakeSecurityRepository({
    this.passcodeExists = false,
    this.biometricsAvailable = false,
    this.authenticationResult,
  });

  bool passcodeExists;
  final bool biometricsAvailable;
  final Result<bool, AppError>? authenticationResult;

  @override
  Future<Result<bool, AppError>> hasPasscode() async =>
      Result.success(passcodeExists);

  @override
  Future<Result<bool, AppError>> canCheckBiometrics() async =>
      Result.success(biometricsAvailable);

  @override
  Future<Result<bool, AppError>> authenticateWithBiometrics({
    required String localizedReason,
  }) async => authenticationResult ?? Result.success(false);

  @override
  Future<Result<void, AppError>> deletePasscode() async {
    passcodeExists = false;
    return Result.success(null);
  }

  @override
  Future<Result<void, AppError>> setPasscode(String passcode) async {
    passcodeExists = true;
    return Result.success(null);
  }

  @override
  Future<Result<bool, AppError>> verifyPasscode(String passcode) async =>
      Result.success(false);
}

void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  Widget buildSubject({_FakeSecurityRepository? securityRepository}) {
    return ProviderScope(
      overrides: [
        privacyRepositoryProvider.overrideWithValue(
          PrivacyRepository(preferences),
        ),
        securityRepositoryProvider.overrideWithValue(
          securityRepository ?? _FakeSecurityRepository(),
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
        home: PrivacySettingsPage(),
      ),
    );
  }

  testWidgets('プライバシー設定をアイコン中心の簡潔な一覧で表示する', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(shared_find.findAppText('アプリロック'), findsOneWidget);
    expect(shared_find.findAppText('起動時・復帰時をパスコードで保護'), findsNothing);
    expect(shared_find.findAppText('生体認証'), findsOneWidget);
    expect(shared_find.findAppText('画面プレビューを隠す'), findsOneWidget);
    expect(shared_find.findAppText('サムネイルを隠す'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });

  testWidgets('Infoボタンをタップすると詳細ダイアログが表示される', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Infoボタン（Icons.info_outline）を探してタップ
    final infoButtons = find.byIcon(Icons.info_outline);
    expect(infoButtons, findsWidgets);

    // アプリロックのInfoボタンをタップ
    await tester.tap(infoButtons.first);
    await tester.pumpAndSettle();

    expect(find.text('アプリロックとは？'), findsOneWidget);
    expect(find.text('ほかの人にアプリの中を見られたくないときに使います。'), findsOneWidget);
    expect(find.text('オンにすると'), findsOneWidget);
    expect(find.byIcon(Icons.password), findsOneWidget);
    expect(find.text('閉じる'), findsOneWidget);

    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();
    expect(find.text('アプリロックとは？'), findsNothing);
  });

  testWidgets('アプリロック有効化前に復旧不能であることを確認する', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(shared_find.findAppText('アプリロック'));
    await tester.pumpAndSettle();

    expect(shared_find.findAppText('パスコードを設定しますか？'), findsOneWidget);
    expect(shared_find.findAppTextContaining('パスコードを忘れた場合'), findsOneWidget);
    expect(shared_find.findAppText('理解して設定'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('キャンセル'));
    await tester.pumpAndSettle();
    expect(shared_find.findAppText('パスコードを設定しますか？'), findsNothing);
  });

  testWidgets('生体認証のキャンセルではエラー表示や設定変更をしない', (tester) async {
    await preferences.setString(
      'privacy_settings',
      jsonEncode(const PrivacySettings(isAppLockEnabled: true).toJson()),
    );
    await tester.pumpWidget(
      buildSubject(
        securityRepository: _FakeSecurityRepository(
          passcodeExists: true,
          biometricsAvailable: true,
          authenticationResult: Result.success(false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(shared_find.findAppText('生体認証'));
    await tester.pumpAndSettle();

    expect(find.text('認証に失敗しました'), findsNothing);
    final saved = jsonDecode(preferences.getString('privacy_settings')!);
    expect(saved['isBiometricEnabled'], isFalse);
  });

  testWidgets('生体認証の実エラーでは内部メッセージを表示しない', (tester) async {
    await preferences.setString(
      'privacy_settings',
      jsonEncode(const PrivacySettings(isAppLockEnabled: true).toJson()),
    );
    await tester.pumpWidget(
      buildSubject(
        securityRepository: _FakeSecurityRepository(
          passcodeExists: true,
          biometricsAvailable: true,
          authenticationResult: Result.failure(
            AppError.unknown('internal biometric platform error'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(shared_find.findAppText('生体認証'));
    await tester.pumpAndSettle();

    expect(shared_find.findAppText('認証に失敗しました'), findsOneWidget);
    expect(
      find.textContaining('internal biometric platform error'),
      findsNothing,
    );
  });

  testWidgets('小型画面と200%文字サイズでも主要文言が表示される', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: buildSubject(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(shared_find.findAppText('アプリロック'), findsOneWidget);
    expect(shared_find.findAppText('生体認証'), findsOneWidget);

    // スクロールして次のセクションの項目も確認できること
    await tester.scrollUntilVisible(shared_find.findAppText('画面プレビューを隠す'), 100);
    await tester.pumpAndSettle();
    expect(shared_find.findAppText('画面プレビューを隠す'), findsOneWidget);
  });
}
