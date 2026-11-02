import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/services/secure_storage_service.dart';
import 'package:private_shelf/features/security/domain/repositories/security_repository.dart';
import 'package:private_shelf/features/security/presentation/providers/security_repository_provider.dart';
import 'package:private_shelf/features/security/presentation/providers/passcode_provider.dart';

class MockSecureStorage extends Mock implements SecureStorageService {}

class MockSecurityRepository extends Mock implements SecurityRepository {}

void main() {
  late MockSecureStorage storage;
  late MockSecurityRepository repository;
  late ProviderContainer container;

  ProviderContainer createContainer() {
    final result = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(storage),
        securityRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(result.dispose);
    result.listen(
      passcodeNotifierProvider(PasscodeMode.unlock),
      (_, _) {},
      fireImmediately: true,
    );
    return result;
  }

  setUp(() {
    storage = MockSecureStorage();
    repository = MockSecurityRepository();
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => storage.delete(key: any(named: 'key')),
    ).thenAnswer((_) async => Result.success(null));
  });

  Future<void> enterPin(PasscodeNotifier notifier, List<int> digits) async {
    for (final digit in digits) {
      notifier.addDigit(digit);
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  test('再起動相当でも保存済みロックアウトを復元し入力を拒否する', () async {
    final lockoutUntil = DateTime.now().add(const Duration(minutes: 1));
    when(() => storage.read(key: SecureStorageKeys.pinLockoutState)).thenAnswer(
      (_) async => Result.success(
        jsonEncode({
          'version': 1,
          'failedAttempts': 5,
          'lockoutUntil': lockoutUntil.toUtc().toIso8601String(),
        }),
      ),
    );
    container = createContainer();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final notifier = container.read(
      passcodeNotifierProvider(PasscodeMode.unlock).notifier,
    );
    final restored = container.read(
      passcodeNotifierProvider(PasscodeMode.unlock),
    );
    expect(restored.isSecurityStateReady, isTrue);
    expect(restored.failedAttempts, 5);
    expect(restored.lockoutRemainingSeconds, greaterThan(0));

    notifier.addDigit(1);
    expect(
      container.read(passcodeNotifierProvider(PasscodeMode.unlock)).passcode,
      isEmpty,
    );
  });

  test('セキュアストレージ障害時はfail-closedで認証入力を許可しない', () async {
    when(() => storage.read(key: SecureStorageKeys.pinLockoutState)).thenAnswer(
      (_) async => Result.failure(AppError.database('storage unavailable')),
    );
    container = createContainer();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final notifier = container.read(
      passcodeNotifierProvider(PasscodeMode.unlock).notifier,
    );
    notifier.addDigit(1);
    final state = container.read(passcodeNotifierProvider(PasscodeMode.unlock));

    expect(state.isSecurityStateReady, isFalse);
    expect(state.errorType, PasscodeError.storageFailed);
    expect(state.passcode, isEmpty);
    verifyNever(() => repository.verifyPasscode(any()));
  });

  test('失敗回数の永続化に失敗した場合は認証をfail-closedにする', () async {
    when(
      () => storage.read(key: SecureStorageKeys.pinLockoutState),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => storage.write(
        key: SecureStorageKeys.pinLockoutState,
        value: any(named: 'value'),
      ),
    ).thenAnswer(
      (_) async => Result.failure(AppError.database('write unavailable')),
    );
    when(
      () => repository.verifyPasscode(any()),
    ).thenAnswer((_) async => Result.success(false));
    container = createContainer();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final notifier = container.read(
      passcodeNotifierProvider(PasscodeMode.unlock).notifier,
    );
    for (final digit in [1, 2, 3, 4]) {
      notifier.addDigit(digit);
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final state = container.read(passcodeNotifierProvider(PasscodeMode.unlock));
    expect(state.isSecurityStateReady, isFalse);
    expect(state.errorType, PasscodeError.storageFailed);
    expect(state.passcode, isEmpty);
  });

  test('5回目の失敗で30秒ロックし、待機中の入力を拒否する', () async {
    when(
      () => storage.read(key: SecureStorageKeys.pinLockoutState),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => repository.verifyPasscode(any()),
    ).thenAnswer((_) async => Result.success(false));
    container = createContainer();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final notifier = container.read(
      passcodeNotifierProvider(PasscodeMode.unlock).notifier,
    );

    for (var attempt = 1; attempt <= 4; attempt++) {
      await enterPin(notifier, const [1, 2, 3, 4]);
      final state = container.read(
        passcodeNotifierProvider(PasscodeMode.unlock),
      );
      expect(state.failedAttempts, attempt);
      expect(state.lockoutRemainingSeconds, isNull);
      expect(state.errorType, PasscodeError.incorrect);
    }

    await enterPin(notifier, const [1, 2, 3, 4]);
    final locked = container.read(
      passcodeNotifierProvider(PasscodeMode.unlock),
    );
    expect(locked.failedAttempts, PasscodeNotifier.maxAttempts);
    expect(locked.lockoutRemainingSeconds, inInclusiveRange(29, 30));
    expect(locked.errorType, isNull);

    notifier.addDigit(9);
    expect(
      container.read(passcodeNotifierProvider(PasscodeMode.unlock)).passcode,
      isEmpty,
    );

    final writes = verify(
      () => storage.write(
        key: SecureStorageKeys.pinLockoutState,
        value: captureAny(named: 'value'),
      ),
    ).captured;
    final persisted = jsonDecode(writes.last as String) as Map<String, dynamic>;
    expect(persisted['failedAttempts'], PasscodeNotifier.maxAttempts);
    expect(persisted['lockoutUntil'], isNotNull);
  });

  test('ロック前に認証成功すると失敗回数と永続状態を消去する', () async {
    when(
      () => storage.read(key: SecureStorageKeys.pinLockoutState),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => repository.verifyPasscode('1111'),
    ).thenAnswer((_) async => Result.success(false));
    when(
      () => repository.verifyPasscode('2468'),
    ).thenAnswer((_) async => Result.success(true));
    container = createContainer();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final notifier = container.read(
      passcodeNotifierProvider(PasscodeMode.unlock).notifier,
    );

    await enterPin(notifier, const [1, 1, 1, 1]);
    expect(
      container
          .read(passcodeNotifierProvider(PasscodeMode.unlock))
          .failedAttempts,
      1,
    );

    await enterPin(notifier, const [2, 4, 6, 8]);
    final state = container.read(passcodeNotifierProvider(PasscodeMode.unlock));
    expect(state.isSuccess, isTrue);
    expect(state.failedAttempts, 0);
    expect(state.lockoutRemainingSeconds, isNull);
    verify(
      () => storage.delete(key: SecureStorageKeys.pinLockoutState),
    ).called(1);
  });

  test('既存PINがある状態ではsetup直行からPINを上書きできない', () async {
    when(
      () => storage.read(key: SecureStorageKeys.pinLockoutState),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => repository.hasPasscode(),
    ).thenAnswer((_) async => Result.success(true));
    container = createContainer();
    final notifier = container.read(
      passcodeNotifierProvider(PasscodeMode.setup).notifier,
    );
    container.listen(
      passcodeNotifierProvider(PasscodeMode.setup),
      (_, _) {},
      fireImmediately: true,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await enterPin(notifier, const [1, 2, 3, 4]);
    await Future<void>.delayed(const Duration(milliseconds: 520));
    await enterPin(notifier, const [1, 2, 3, 4]);

    final state = container.read(passcodeNotifierProvider(PasscodeMode.setup));
    expect(state.isSuccess, isFalse);
    expect(state.errorType, PasscodeError.verifyFailed);
    verifyNever(() => repository.setPasscode(any()));
  });

  test('同一フローで旧PINを検証した後は新PINを保存できる', () async {
    when(
      () => storage.read(key: SecureStorageKeys.pinLockoutState),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => repository.verifyPasscode('1111'),
    ).thenAnswer((_) async => Result.success(true));
    when(
      () => repository.hasPasscode(),
    ).thenAnswer((_) async => Result.success(true));
    when(
      () => repository.setPasscode('2468'),
    ).thenAnswer((_) async => Result.success(null));
    container = createContainer();
    final provider = passcodeNotifierProvider(PasscodeMode.verifyOld);
    container.listen(provider, (_, _) {}, fireImmediately: true);
    final notifier = container.read(provider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await enterPin(notifier, const [1, 1, 1, 1]);
    expect(container.read(provider).hasVerifiedExistingPasscode, isTrue);
    await enterPin(notifier, const [2, 4, 6, 8]);
    await Future<void>.delayed(const Duration(milliseconds: 520));
    await enterPin(notifier, const [2, 4, 6, 8]);

    expect(container.read(provider).isSuccess, isTrue);
    verify(() => repository.setPasscode('2468')).called(1);
  });
}
