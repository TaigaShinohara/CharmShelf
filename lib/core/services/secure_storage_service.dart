import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../error/app_error.dart';
import '../error/result.dart';
import '../logger/app_logger.dart';
import '../logger/log_tag.dart';

/// セキュアストレージサービス
///
/// センシティブなデータ（トークン、認証情報など）を
/// 暗号化して安全に保存するためのサービス。
///
/// - iOS: Keychain を使用
/// - Android: Android KeystoreとAES-GCM（旧形式は保護付きで移行）
///
/// 使用例:
/// ```dart
/// final secureStorage = ref.read(secureStorageServiceProvider);
///
/// // 保存
/// await secureStorage.write(key: 'auth_token', value: 'xyz123');
///
/// // 読み取り
/// final result = await secureStorage.read(key: 'auth_token');
/// result.when(
///   success: (value) => print('Token: $value'),
///   failure: (error) => print('Error: ${error.message}'),
/// );
///
/// // 削除
/// await secureStorage.delete(key: 'auth_token');
/// ```
class SecureStorageService {
  SecureStorageService()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(
          // 読取・移行の失敗を空データへ変換しない。暗号化バックアップから再試行する。
          resetOnError: false,
          migrateWithBackup: true,
        ),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );

  final FlutterSecureStorage _storage;

  /// 値を保存
  Future<Result<void, AppError>> write({
    required String key,
    required String value,
  }) async {
    try {
      await _storage.write(key: key, value: value);
      AppLogger.d(LogTag.auth, 'セキュアストレージに保存: $key');
      return Result.success(null);
    } catch (e, st) {
      AppLogger.e(LogTag.auth, 'セキュアストレージへの保存に失敗: $key', e, st);
      return Result.failure(
        AppError.database('セキュアデータの保存に失敗しました', original: e, stackTrace: st),
      );
    }
  }

  /// 値を読み取り
  Future<Result<String?, AppError>> read({required String key}) async {
    try {
      final value = await _storage.read(key: key);
      AppLogger.d(
        LogTag.auth,
        'セキュアストレージから読み取り: $key (exists: ${value != null})',
      );
      return Result.success(value);
    } catch (e, st) {
      AppLogger.e(LogTag.auth, 'セキュアストレージからの読み取りに失敗: $key', e, st);
      return Result.failure(
        AppError.database('セキュアデータの読み取りに失敗しました', original: e, stackTrace: st),
      );
    }
  }

  /// 値を削除
  Future<Result<void, AppError>> delete({required String key}) async {
    try {
      await _storage.delete(key: key);
      AppLogger.d(LogTag.auth, 'セキュアストレージから削除: $key');
      return Result.success(null);
    } catch (e, st) {
      AppLogger.e(LogTag.auth, 'セキュアストレージからの削除に失敗: $key', e, st);
      return Result.failure(
        AppError.database('セキュアデータの削除に失敗しました', original: e, stackTrace: st),
      );
    }
  }

  /// 全てのデータを削除
  Future<Result<void, AppError>> deleteAll() async {
    try {
      await _storage.deleteAll();
      AppLogger.i(LogTag.auth, 'セキュアストレージを全削除');
      return Result.success(null);
    } catch (e, st) {
      AppLogger.e(LogTag.auth, 'セキュアストレージの全削除に失敗', e, st);
      return Result.failure(
        AppError.database('セキュアデータの全削除に失敗しました', original: e, stackTrace: st),
      );
    }
  }

  /// 指定キーが存在するかチェック
  Future<Result<bool, AppError>> containsKey({required String key}) async {
    try {
      final exists = await _storage.containsKey(key: key);
      return Result.success(exists);
    } catch (e, st) {
      AppLogger.e(LogTag.auth, 'セキュアストレージのキー確認に失敗: $key', e, st);
      return Result.failure(
        AppError.database('セキュアデータの確認に失敗しました', original: e, stackTrace: st),
      );
    }
  }

  /// 全てのキーを取得
  Future<Result<Map<String, String>, AppError>> readAll() async {
    try {
      final all = await _storage.readAll();
      return Result.success(all);
    } catch (e, st) {
      AppLogger.e(LogTag.auth, 'セキュアストレージの全読み取りに失敗', e, st);
      return Result.failure(
        AppError.database('セキュアデータの読み取りに失敗しました', original: e, stackTrace: st),
      );
    }
  }
}

/// 定義済みのセキュアストレージキー
///
/// センシティブデータのキー名を一元管理します。
/// 新しいセンシティブデータを保存する場合は、ここにキーを追加してください。
abstract class SecureStorageKeys {
  /// 認証トークン
  static const String authToken = 'auth_token';

  /// リフレッシュトークン
  static const String refreshToken = 'refresh_token';

  /// ユーザーID
  static const String userId = 'user_id';

  /// PINコード（ローカル認証用）
  static const String pinCode = 'pin_code';

  /// PIN認証の連続失敗回数とロック期限
  static const String pinLockoutState = 'pin_lockout_state';

  /// バイオメトリクス設定
  static const String biometricsEnabled = 'biometrics_enabled';

  /// APIキー（外部サービス連携用）
  static const String apiKey = 'api_key';

  /// 暗号化キー（追加の暗号化に使用）
  static const String encryptionKey = 'encryption_key';
}

/// SecureStorageService のProvider
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});
