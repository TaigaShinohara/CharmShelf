import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/security/pbkdf2.dart';
import 'package:private_shelf/core/services/secure_storage_service.dart';
import 'package:private_shelf/features/security/data/repositories/security_repository_impl.dart';

class MockSecureStorageService extends Mock implements SecureStorageService {}

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

void main() {
  late MockSecureStorageService storage;
  late MockLocalAuthentication auth;
  late SecurityRepositoryImpl repository;

  setUp(() {
    storage = MockSecureStorageService();
    auth = MockLocalAuthentication();
    repository = SecurityRepositoryImpl(storage, auth);
  });

  group('SecurityRepositoryImpl - パスコード', () {
    test('パスコードを設定するとv2形式・10000イテレーションでセキュアストレージに保存される', () async {
      String? savedKey;
      String? savedValue;
      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        savedKey = invocation.namedArguments[#key] as String;
        savedValue = invocation.namedArguments[#value] as String;
        return Result.success(null);
      });

      final result = await repository.setPasscode('1234');

      expect(result.isSuccess, isTrue);
      expect(savedKey, SecureStorageKeys.pinCode);
      expect(savedValue, isNotNull);
      final parts = savedValue!.split(':');
      expect(parts.length, 4);
      expect(parts[0], 'v2');
      expect(parts[1], '10000');
    });

    test('パスコード計算中もメインIsolateのイベント処理を妨げない', () async {
      var eventLoopAdvanced = false;
      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {
        expect(eventLoopAdvanced, isTrue);
        return Result.success(null);
      });

      Timer.run(() {
        eventLoopAdvanced = true;
      });

      final result = await repository.setPasscode('1234');

      expect(result.isSuccess, isTrue);
    });

    test('正しく設定されたパスコードで認証が成功する', () async {
      String? storedValue;
      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        storedValue = invocation.namedArguments[#value] as String;
        return Result.success(null);
      });

      await repository.setPasscode('5678');

      when(
        () => storage.read(key: SecureStorageKeys.pinCode),
      ).thenAnswer((_) async => Result.success(storedValue));

      final verifySuccess = await repository.verifyPasscode('5678');
      expect(verifySuccess.isSuccess, isTrue);
      expect(verifySuccess.dataOrNull, isTrue);

      final verifyFailure = await repository.verifyPasscode('0000');
      expect(verifyFailure.isSuccess, isTrue);
      expect(verifyFailure.dataOrNull, isFalse);
    });

    test('旧形式（v1レガシー形式）のパスコードも認証でき、成功時にv2形式（10000イテレーション）に自動移行される', () async {
      final saltBytes = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];
      final salt = base64UrlEncode(saltBytes);

      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async => Result.success(null));

      final legacyV1Hash = base64UrlEncode(
        sha256.convert([...saltBytes, ...utf8.encode('9999')]).bytes,
      );
      final legacyV1Value = 'v1:$salt:$legacyV1Hash';

      when(
        () => storage.read(key: SecureStorageKeys.pinCode),
      ).thenAnswer((_) async => Result.success(legacyV1Value));

      final verifyResult = await repository.verifyPasscode('9999');
      expect(verifyResult.isSuccess, isTrue);
      expect(verifyResult.dataOrNull, isTrue);

      // setPasscodeが呼ばれてv2形式（10000イテレーション）で再保存されたことを検証
      final captured =
          verify(
                () => storage.write(
                  key: SecureStorageKeys.pinCode,
                  value: captureAny(named: 'value'),
                ),
              ).captured.last
              as String;

      expect(captured.startsWith('v2:10000:'), isTrue);
    });

    test('v2形式で異なるイテレーション数のパスコードも認証でき、成功時に10000イテレーションに自動移行される', () async {
      final saltBytes = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];
      final salt = base64UrlEncode(saltBytes);

      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async => Result.success(null));

      // 1000イテレーションでハッシュを生成した保存データをシミュレート
      final oldHash = base64UrlEncode(
        derivePbkdf2Sha256(
          password: '7777',
          salt: saltBytes,
          iterations: 1000,
          length: 32,
        ),
      );
      final oldIterValue = 'v2:1000:$salt:$oldHash';

      when(
        () => storage.read(key: SecureStorageKeys.pinCode),
      ).thenAnswer((_) async => Result.success(oldIterValue));

      final verifyResult = await repository.verifyPasscode('7777');
      expect(verifyResult.isSuccess, isTrue);
      expect(verifyResult.dataOrNull, isTrue);

      final captured =
          verify(
                () => storage.write(
                  key: SecureStorageKeys.pinCode,
                  value: captureAny(named: 'value'),
                ),
              ).captured.last
              as String;

      expect(captured.startsWith('v2:10000:'), isTrue);
    });

    test('未設定の場合はfalseを返す', () async {
      when(
        () => storage.read(key: SecureStorageKeys.pinCode),
      ).thenAnswer((_) async => Result.success(null));

      final result = await repository.verifyPasscode('1234');
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isFalse);
    });
  });

  group('SecurityRepositoryImpl - 生体認証', () {
    test('登録済みの生体情報がない場合は端末認証対応でも利用不可にする', () async {
      when(
        () => auth.getAvailableBiometrics(),
      ).thenAnswer((_) async => <BiometricType>[]);

      final result = await repository.canCheckBiometrics();

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isFalse);
      verifyNever(() => auth.isDeviceSupported());
    });

    test('認証は生体限定かつバックグラウンド継続なしで実行する', () async {
      when(
        () => auth.getAvailableBiometrics(),
      ).thenAnswer((_) async => <BiometricType>[BiometricType.strong]);
      when(
        () => auth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          biometricOnly: any(named: 'biometricOnly'),
          persistAcrossBackgrounding: any(named: 'persistAcrossBackgrounding'),
        ),
      ).thenAnswer((_) async => true);

      final result = await repository.authenticateWithBiometrics(
        localizedReason: '本人確認',
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isTrue);
      verify(
        () => auth.authenticate(
          localizedReason: '本人確認',
          biometricOnly: true,
          persistAcrossBackgrounding: false,
        ),
      ).called(1);
    });

    test('登録済みの生体情報がなければ端末PINへフォールバックしない', () async {
      when(
        () => auth.getAvailableBiometrics(),
      ).thenAnswer((_) async => <BiometricType>[]);

      final result = await repository.authenticateWithBiometrics(
        localizedReason: '本人確認',
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isFalse);
      verifyNever(
        () => auth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          biometricOnly: any(named: 'biometricOnly'),
          persistAcrossBackgrounding: any(named: 'persistAcrossBackgrounding'),
        ),
      );
    });
  });
}
