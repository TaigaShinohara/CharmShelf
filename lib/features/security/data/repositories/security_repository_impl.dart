import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/services/secure_storage_service.dart';
import 'package:private_shelf/features/security/domain/repositories/security_repository.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/security/pbkdf2.dart';

part 'security_repository_impl.g.dart';

class SecurityRepositoryImpl implements SecurityRepository {
  SecurityRepositoryImpl(this._secureStorage, this._auth);

  final SecureStorageService _secureStorage;
  final LocalAuthentication _auth;
  static const _passcodePrefix = 'v2';
  static const _passcodeIterations = 10000;

  @override
  Future<Result<void, AppError>> setPasscode(String passcode) async {
    final saltBytes = _generateSalt();
    final salt = base64UrlEncode(saltBytes);
    final hash = await _computeHash(passcode, saltBytes, _passcodeIterations);
    return _secureStorage.write(
      key: SecureStorageKeys.pinCode,
      value: '$_passcodePrefix:$_passcodeIterations:$salt:$hash',
    );
  }

  @override
  Future<Result<bool, AppError>> verifyPasscode(String passcode) async {
    final result = await _secureStorage.read(key: SecureStorageKeys.pinCode);
    if (result is Failure<String?, AppError>) {
      return Result.failure(result.error);
    }
    final storedPasscode = (result as Success<String?, AppError>).data;
    if (storedPasscode == null || storedPasscode.isEmpty) {
      return Result.success(false);
    }
    final parsed = _parseStoredPasscode(storedPasscode);
    if (parsed != null) {
      final hash = await _computeHash(passcode, parsed.salt, parsed.iterations);
      final isValid = _constantTimeEquals(hash, parsed.hash);
      if (isValid && parsed.iterations != _passcodeIterations) {
        await setPasscode(passcode);
      }
      return Result.success(isValid);
    }
    final legacy = _parseLegacyStoredPasscode(storedPasscode);
    if (legacy != null) {
      final hash = sha256.convert([
        ...legacy.salt,
        ...utf8.encode(passcode),
      ]).bytes;
      final isValid = _constantTimeEquals(base64UrlEncode(hash), legacy.hash);
      if (isValid) await setPasscode(passcode);
      return Result.success(isValid);
    }
    final isValid = storedPasscode == passcode;
    if (isValid) {
      await setPasscode(passcode);
    }
    return Result.success(isValid);
  }

  @override
  Future<Result<bool, AppError>> hasPasscode() async {
    final result = await _secureStorage.containsKey(
      key: SecureStorageKeys.pinCode,
    );
    return result;
  }

  @override
  Future<Result<void, AppError>> deletePasscode() async {
    return _secureStorage.delete(key: SecureStorageKeys.pinCode);
  }

  @override
  Future<Result<bool, AppError>> canCheckBiometrics() async {
    try {
      // local_auth_windows は biometricOnly をサポートしないため、端末資格情報を
      // 生体認証として提示しない。Windowsでもアプリ固有PINは引き続き利用できる。
      if (Platform.isWindows) return Result.success(false);
      final availableBiometrics = await _auth.getAvailableBiometrics();
      return Result.success(availableBiometrics.isNotEmpty);
    } catch (e, st) {
      return Result.failure(
        AppError.unknown('生体認証の確認に失敗しました', original: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<bool, AppError>> authenticateWithBiometrics({
    required String localizedReason,
  }) async {
    try {
      AppLogger.d(LogTag.auth, 'local_auth: 認証開始');
      if (Platform.isWindows) return Result.success(false);
      final availableBiometrics = await _auth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        return Result.success(false);
      }
      final authenticated = await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        persistAcrossBackgrounding: false,
      );
      AppLogger.d(LogTag.auth, 'local_auth: 認証完了結果 = $authenticated');
      return Result.success(authenticated);
    } catch (e, st) {
      AppLogger.e(LogTag.auth, 'local_auth: 例外発生', e, st);
      return Result.failure(
        AppError.unknown('生体認証に失敗しました', original: e, stackTrace: st),
      );
    }
  }
}

@Riverpod(keepAlive: true)
SecurityRepository securityRepositoryImpl(Ref ref) {
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return SecurityRepositoryImpl(secureStorage, LocalAuthentication());
}

({List<int> salt, String hash, int iterations})? _parseStoredPasscode(
  String value,
) {
  final parts = value.split(':');
  if (parts.length != 4 || parts[0] != SecurityRepositoryImpl._passcodePrefix) {
    return null;
  }
  try {
    final iterations = int.parse(parts[1]);
    if (iterations < 1000 || iterations > 2000000) return null;
    final saltBytes = base64Url.decode(parts[2]);
    return (salt: saltBytes, hash: parts[3], iterations: iterations);
  } catch (_) {
    return null;
  }
}

({List<int> salt, String hash})? _parseLegacyStoredPasscode(String value) {
  final parts = value.split(':');
  if (parts.length != 3 || parts[0] != 'v1') return null;
  try {
    return (salt: base64Url.decode(parts[1]), hash: parts[2]);
  } catch (_) {
    return null;
  }
}

Future<String> _computeHash(
  String passcode,
  List<int> saltBytes,
  int iterations,
) {
  // 端末では現在の反復回数でも1フレームを超えるため、UI Isolateでは計算しない。
  return Isolate.run(() => _hashPasscode(passcode, saltBytes, iterations));
}

String _hashPasscode(String passcode, List<int> saltBytes, int iterations) {
  return base64UrlEncode(
    derivePbkdf2Sha256(
      password: passcode,
      salt: saltBytes,
      iterations: iterations,
      length: 32,
    ),
  );
}

bool _constantTimeEquals(String left, String right) {
  final leftBytes = utf8.encode(left);
  final rightBytes = utf8.encode(right);
  if (leftBytes.isEmpty || rightBytes.isEmpty) return false;
  var difference = leftBytes.length ^ rightBytes.length;
  final length = max(leftBytes.length, rightBytes.length);
  for (var i = 0; i < length; i++) {
    difference |=
        leftBytes[i % leftBytes.length] ^ rightBytes[i % rightBytes.length];
  }
  return difference == 0;
}

List<int> _generateSalt() {
  final random = Random.secure();
  return List<int>.generate(16, (_) => random.nextInt(256));
}
