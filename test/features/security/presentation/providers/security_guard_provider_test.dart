import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/security/domain/repositories/security_repository.dart';
import 'package:private_shelf/features/security/presentation/providers/security_repository_provider.dart';
import 'package:private_shelf/features/security/presentation/providers/security_guard_provider.dart';
import 'package:private_shelf/features/settings/data/repositories/privacy_repository.dart';
import 'package:private_shelf/features/settings/domain/models/privacy_settings.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSecurityRepository implements SecurityRepository {
  const _FakeSecurityRepository(this.hasPasscodeResult);

  final Result<bool, AppError> hasPasscodeResult;

  @override
  Future<Result<bool, AppError>> hasPasscode() async => hasPasscodeResult;

  @override
  Future<Result<bool, AppError>> authenticateWithBiometrics({
    required String localizedReason,
  }) async => Result.success(false);

  @override
  Future<Result<bool, AppError>> canCheckBiometrics() async =>
      Result.success(false);

  @override
  Future<Result<void, AppError>> deletePasscode() async => Result.success(null);

  @override
  Future<Result<void, AppError>> setPasscode(String passcode) async =>
      Result.success(null);

  @override
  Future<Result<bool, AppError>> verifyPasscode(String passcode) async =>
      Result.success(false);
}

void main() {
  Future<ProviderContainer> buildContainer({
    required Result<bool, AppError> hasPasscode,
    PrivacySettings settings = const PrivacySettings(),
  }) async {
    SharedPreferences.setMockInitialValues({
      'privacy_settings': jsonEncode(settings.toJson()),
    });
    final preferences = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        privacyRepositoryProvider.overrideWithValue(
          PrivacyRepository(preferences),
        ),
        securityRepositoryProvider.overrideWithValue(
          _FakeSecurityRepository(hasPasscode),
        ),
      ],
    );
  }

  test('パスコード確認に失敗した場合はfail-closedでロックする', () async {
    final container = await buildContainer(
      hasPasscode: Result.failure(
        AppError.unknown('secure storage unavailable'),
      ),
    );
    addTearDown(container.dispose);

    expect(await container.read(securityGuardProvider.future), isFalse);
  });

  test('設定がOFFでもパスコードが残っていればロックする', () async {
    final container = await buildContainer(hasPasscode: Result.success(true));
    addTearDown(container.dispose);

    expect(await container.read(securityGuardProvider.future), isFalse);
  });

  test('パスコードなし・設定OFFの場合だけ起動時に解除済みとする', () async {
    final container = await buildContainer(hasPasscode: Result.success(false));
    addTearDown(container.dispose);

    expect(await container.read(securityGuardProvider.future), isTrue);
  });

  test('パスコードなし・設定ONの不整合は安全側でロックする', () async {
    final container = await buildContainer(
      hasPasscode: Result.success(false),
      settings: const PrivacySettings(isAppLockEnabled: true),
    );
    addTearDown(container.dispose);

    expect(await container.read(securityGuardProvider.future), isFalse);
  });
}
