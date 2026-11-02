import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';

/// セキュリティ関連（パスコード、生体認証）の操作を行うリポジトリインターフェース
abstract class SecurityRepository {
  /// パスコードを設定（保存）する
  Future<Result<void, AppError>> setPasscode(String passcode);

  /// パスコードを検証する
  /// 正しい場合は true, 誤りの場合は false を返す
  Future<Result<bool, AppError>> verifyPasscode(String passcode);

  /// パスコードが設定済みかどうかを確認する
  Future<Result<bool, AppError>> hasPasscode();

  /// パスコードを削除する（ロックOFF時など）
  Future<Result<void, AppError>> deletePasscode();

  /// 生体認証が利用可能か確認する
  Future<Result<bool, AppError>> canCheckBiometrics();

  /// 生体認証を実行する
  /// 成功時は true, 失敗・キャンセルの場合は false
  Future<Result<bool, AppError>> authenticateWithBiometrics({
    required String localizedReason,
  });
}
