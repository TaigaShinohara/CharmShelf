import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/settings/data/repositories/privacy_repository.dart';
import 'package:private_shelf/features/settings/domain/models/privacy_settings.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';
import 'package:private_shelf/features/security/domain/repositories/security_repository.dart';
import 'package:private_shelf/features/security/presentation/providers/security_repository_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePrivacyRepository extends PrivacyRepository {
  _FakePrivacyRepository(
    super.preferences, {
    required this.initial,
    this.failSave = false,
  });

  final PrivacySettings initial;
  bool failSave;

  @override
  Future<Result<PrivacySettings, AppError>> loadSettings() async =>
      Result.success(initial);

  @override
  Future<Result<void, AppError>> saveSettings(PrivacySettings settings) async {
    if (failSave) {
      return Result.failure(AppError.unknown('simulated save failure'));
    }
    return Result.success(null);
  }
}

class _FakeSecurityRepository implements SecurityRepository {
  _FakeSecurityRepository({this.failDelete = false});

  bool passcodeExists = true;
  int deleteCalls = 0;
  bool failDelete;

  @override
  Future<Result<bool, AppError>> hasPasscode() async =>
      Result.success(passcodeExists);

  @override
  Future<Result<void, AppError>> deletePasscode() async {
    deleteCalls++;
    if (failDelete) {
      return Result.failure(AppError.unknown('simulated delete failure'));
    }
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
      Result.success(true);

  @override
  Future<Result<bool, AppError>> canCheckBiometrics() async =>
      Result.success(false);

  @override
  Future<Result<bool, AppError>> authenticateWithBiometrics({
    required String localizedReason,
  }) async => Result.success(false);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('設定保存失敗時は以前の状態へ戻してfalseを返す', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = _FakePrivacyRepository(
      preferences,
      initial: const PrivacySettings(isAppLockEnabled: true),
      failSave: true,
    );
    final container = ProviderContainer(
      overrides: [privacyRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(privacySettingsNotifierProvider.future);

    final saved = await container
        .read(privacySettingsNotifierProvider.notifier)
        .updateSettings(const PrivacySettings(isAppLockEnabled: false));

    expect(saved, isFalse);
    expect(
      container.read(privacySettingsNotifierProvider).value,
      const PrivacySettings(isAppLockEnabled: true),
    );
  });

  test('設定保存成功時だけ新しい状態を確定してtrueを返す', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = _FakePrivacyRepository(
      preferences,
      initial: const PrivacySettings(isAppLockEnabled: true),
    );
    final container = ProviderContainer(
      overrides: [privacyRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(privacySettingsNotifierProvider.future);

    final saved = await container
        .read(privacySettingsNotifierProvider.notifier)
        .updateSettings(const PrivacySettings(isAppLockEnabled: false));

    expect(saved, isTrue);
    expect(
      container.read(privacySettingsNotifierProvider).value,
      const PrivacySettings(isAppLockEnabled: false),
    );
  });

  test('破損した設定JSONをロックOFFの成功値として扱わない', () async {
    SharedPreferences.setMockInitialValues({'privacy_settings': '{broken'});
    final preferences = await SharedPreferences.getInstance();

    final result = await PrivacyRepository(preferences).loadSettings();

    expect(result.isFailure, isTrue);
  });

  test('ロックOFF設定の保存失敗時はパスコードを削除しない', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = _FakePrivacyRepository(
      preferences,
      initial: const PrivacySettings(isAppLockEnabled: true),
      failSave: true,
    );
    final securityRepository = _FakeSecurityRepository();
    final container = ProviderContainer(
      overrides: [
        privacyRepositoryProvider.overrideWithValue(repository),
        securityRepositoryProvider.overrideWithValue(securityRepository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(privacySettingsNotifierProvider.future);

    final disabled = await container
        .read(privacySettingsNotifierProvider.notifier)
        .disableAppLock();

    expect(disabled, isFalse);
    expect(securityRepository.deleteCalls, 0);
    expect(securityRepository.passcodeExists, isTrue);
  });

  test('パスコード削除失敗時はロックON設定へロールバックする', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = _FakePrivacyRepository(
      preferences,
      initial: const PrivacySettings(
        isAppLockEnabled: true,
        isBiometricEnabled: true,
      ),
    );
    final securityRepository = _FakeSecurityRepository(failDelete: true);
    final container = ProviderContainer(
      overrides: [
        privacyRepositoryProvider.overrideWithValue(repository),
        securityRepositoryProvider.overrideWithValue(securityRepository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(privacySettingsNotifierProvider.future);

    final disabled = await container
        .read(privacySettingsNotifierProvider.notifier)
        .disableAppLock();

    expect(disabled, isFalse);
    expect(securityRepository.deleteCalls, 1);
    expect(securityRepository.passcodeExists, isTrue);
    expect(
      container.read(privacySettingsNotifierProvider).value,
      const PrivacySettings(isAppLockEnabled: true, isBiometricEnabled: true),
    );
  });
}
