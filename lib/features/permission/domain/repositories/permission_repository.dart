/// 権限リクエストの結果
enum PermissionResult { granted, denied, permanentlyDenied, restricted }

/// 権限リポジトリのインターフェース
abstract class PermissionRepository {
  /// 現在の通知権限状態を取得
  Future<PermissionResult> getNotificationPermissionStatus();

  /// ストレージ（または写真ライブラリ）の権限をリクエスト
  Future<PermissionResult> requestStoragePermission();

  /// 外部ストレージ管理（MANAGE_EXTERNAL_STORAGE）の権限状態を取得
  Future<PermissionResult> getManageStoragePermissionStatus();

  /// 外部ストレージ管理（MANAGE_EXTERNAL_STORAGE）の権限をリクエスト
  Future<PermissionResult> requestManageStoragePermission();

  /// 通知の権限をリクエスト
  Future<PermissionResult> requestNotificationPermission();

  /// 権限設定画面を開く
  Future<bool> openAppSettings();
}
