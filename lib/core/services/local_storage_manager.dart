import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';

import 'private_storage_service.dart';

part 'local_storage_manager.g.dart';

@Riverpod(keepAlive: true)
LocalStorageManager localStorageManager(Ref ref) {
  return LocalStorageManager();
}

/// 端末内のCharmShelf専用ストレージディレクトリを管理するサービス。
///
/// - **Android**: 公開フォルダは復元元、表示用ファイルとメタデータは私有領域。
/// - **iOS**: Application Support配下のアプリ専用ディレクトリ
class LocalStorageManager {
  static const String appFolderName = 'CharmShelf';
  static const String sidecarMetaDirName = '.tagshelf';
  static const String metadataFileName = 'metadata.json';

  LocalStorageManager({
    bool? isAndroid,
    Directory? privateRootDirectory,
    Directory? androidPublicRootDirectory,
  }) : _isAndroid = isAndroid ?? Platform.isAndroid,
       _privateRootDirectoryOverride = privateRootDirectory,
       _androidPublicRootDirectoryOverride = androidPublicRootDirectory;

  final bool _isAndroid;
  final Directory? _privateRootDirectoryOverride;
  final Directory? _androidPublicRootDirectoryOverride;

  Directory? _cachedRootDirectory;

  Directory get _androidPublicRootDirectory =>
      _androidPublicRootDirectoryOverride ??
      Directory('/storage/emulated/0/Documents/$appFolderName');

  Future<Directory> _privateRootDirectory() async =>
      _privateRootDirectoryOverride ?? await getPrivateStorageDirectory();

  /// アプリが管理する私有ルート。公開復元元の選択状態に左右されない。
  Future<Directory> getPrivateRootDirectory() async {
    final root = await _privateRootDirectory();
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  /// 権限変更後などに、以前のフォールバック先を再利用しないようキャッシュを破棄する。
  void clearRootDirectoryCache() {
    _cachedRootDirectory = null;
  }

  /// ルートディレクトリが外部共有ストレージ（権限が必要な領域）かどうかを判定
  Future<bool> isExternalPublicDirectory({
    bool forceRefresh = false,
    bool allowPublic = true,
  }) async {
    if (!_isAndroid) return false;
    final root = await getRootDirectory(
      forceRefresh: forceRefresh,
      allowPublic: allowPublic,
    );
    return _isExternalPublicPath(root.path);
  }

  bool _isExternalPublicPath(String path) {
    if (!_isAndroid) return false;
    // アプリ専用内部ストレージ（/data/user/0/..., /data/data/...）以外の共有領域
    return !path.contains('/data/user/') && !path.contains('/data/data/');
  }

  /// 専用ルートディレクトリを取得（存在しない場合は作成）
  Future<Directory> getRootDirectory({
    bool forceRefresh = false,
    bool allowPublic = true,
  }) async {
    if (forceRefresh) {
      clearRootDirectoryCache();
    }
    if (_cachedRootDirectory != null && await _cachedRootDirectory!.exists()) {
      return _cachedRootDirectory!;
    }

    Directory rootDir;
    if (_isAndroid && allowPublic) {
      // Android: Documents/CharmShelf を優先（アプリ外共有領域）
      final publicDocs = _androidPublicRootDirectory;
      try {
        if (!await publicDocs.exists()) {
          await publicDocs.create(recursive: true);
        }
        // 実際に書き込み可能か、非機密の一時ファイルで検証する。
        // 公開領域に .tagshelf を新規作成しない。
        final accessProbe = File(
          p.join(
            publicDocs.path,
            '.tagshelf-access-$pid-${DateTime.now().microsecondsSinceEpoch}',
          ),
        );
        try {
          await accessProbe.writeAsString('access');
        } finally {
          if (await accessProbe.exists()) {
            await accessProbe.delete();
          }
        }
        rootDir = publicDocs;
      } catch (e) {
        // パーミッションやパス非互換時のフォールバック (アプリ専用ストレージ)
        AppLogger.i(
          LogTag.storage,
          '外部共有ストレージへのアクセスが制限されているため、アプリ内部ストレージを使用します',
        );
        final appDocs = await getPrivateRootDirectory();
        rootDir = appDocs;
      }
    } else {
      // 権限未取得のAndroidおよびその他プラットフォームは私有領域を使う。
      final privateRoot = await getPrivateRootDirectory();
      rootDir = privateRoot;
    }

    _cachedRootDirectory = rootDir;
    AppLogger.i(LogTag.storage, 'CharmShelf専用ルートフォルダ: ${rootDir.path}');
    return rootDir;
  }

  /// メタデータディレクトリ (.tagshelf) を取得
  Future<Directory> getMetadataDirectory() async {
    // タグ・メモ・非表示状態などは、公開メディアフォルダとは分離して
    // 常にアプリの私有領域へ保存する。
    final privateRoot = await getPrivateRootDirectory();
    final metaDir = Directory(p.join(privateRoot.path, sidecarMetaDirName));
    if (!await metaDir.exists()) {
      await metaDir.create(recursive: true);
    }
    return metaDir;
  }

  /// メタデータファイル (.tagshelf/metadata.json) を取得
  Future<File> getMetadataFile() async {
    final metaDir = await getMetadataDirectory();
    return File(p.join(metaDir.path, metadataFileName));
  }

  /// 旧Android版が公開フォルダに保存していたサイドカーファイルを返す。
  ///
  /// 新規書き込みには使用せず、移行読み込み専用とする。
  Future<File?> getLegacyMetadataFile() async {
    if (!_isAndroid) return null;
    final root = await getRootDirectory();
    final legacy = File(
      p.join(root.path, sidecarMetaDirName, metadataFileName),
    );
    final current = await getMetadataFile();
    if (p.canonicalize(legacy.absolute.path) ==
        p.canonicalize(current.absolute.path)) {
      return null;
    }
    return legacy;
  }

  /// ルートディレクトリからの相対パスを取得
  Future<String> toRelativePath(String fullPath) async {
    final root = await getRootDirectory();
    if (p.isWithin(root.path, fullPath)) {
      return p.relative(fullPath, from: root.path);
    }
    return fullPath;
  }

  /// 相対パスから絶対パスを解決
  Future<String> toAbsolutePath(String relativePath) async {
    if (p.isAbsolute(relativePath)) {
      return relativePath;
    }
    final root = await getRootDirectory();
    return p.join(root.path, relativePath);
  }
}
