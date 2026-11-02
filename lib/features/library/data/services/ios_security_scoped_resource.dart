import 'package:flutter/services.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';

/// iOS Security-Scoped Bookmarks を操作するためのクラス。
///
/// Native 側の `AppDelegate.swift` に実装された MethodChannel を呼び出す。
class IosSecurityScopedResource {
  static const _channel = MethodChannel(
    'com.example.private_shelf/security_scoped_resource',
  );

  /// 指定されたパスの Security-Scoped Bookmark を作成する。
  ///
  /// 戻り値: Base64エンコードされた Bookmark データ。
  Future<String?> createBookmark(String path) async {
    try {
      final base64 = await _channel.invokeMethod<String>('createBookmark', {
        'path': path,
      });
      return base64;
    } catch (_) {
      AppLogger.e(LogTag.storage, 'Bookmark作成に失敗');
      return null;
    }
  }

  /// Bookmark データから URL を解決し、アクセス権を取得する。
  ///
  /// 戻り値: 解決されたパス（成功時）。
  Future<String?> resolveBookmark(String base64Data) async {
    try {
      final path = await _channel.invokeMethod<String>('resolveBookmark', {
        'bookmark': base64Data,
      });
      return path;
    } catch (_) {
      AppLogger.e(LogTag.storage, 'Bookmark解決に失敗');
      return null;
    }
  }

  /// 指定されたパスのアクセス権を解放する。
  Future<void> stopAccessing(String path) async {
    try {
      await stopAccessingStrict(path);
    } catch (_) {
      AppLogger.e(LogTag.storage, 'アクセス権解放に失敗');
    }
  }

  /// 呼び出し側が再試行状態を保持する必要がある解放処理。
  Future<void> stopAccessingStrict(String path) async {
    final stopped = await _channel.invokeMethod<bool>('stopAccessing', {
      'path': path,
    });
    if (stopped != true) {
      throw PlatformException(
        code: 'STOP_ACCESS_FAILED',
        message: 'Security-scoped access could not be released',
      );
    }
  }

  /// 現在のプロセスで開始したすべてのアクセス権を解放する。
  Future<void> stopAllAccessing() async {
    try {
      await stopAllAccessingStrict();
    } catch (_) {
      AppLogger.e(LogTag.storage, 'すべてのアクセス権解放に失敗');
    }
  }

  /// すべてのアクセス権を解放し、失敗を呼び出し側へ伝える。
  Future<void> stopAllAccessingStrict() async {
    final stopped = await _channel.invokeMethod<bool>('stopAllAccessing');
    if (stopped != true) {
      throw PlatformException(
        code: 'STOP_ALL_ACCESS_FAILED',
        message: 'Security-scoped access could not be fully released',
      );
    }
  }
}
