import '../../domain/models/reference_migration.dart';
import 'dart:io';
import 'dart:convert';
import 'package:isar/isar.dart';
import '../repositories/import_source_repository.dart';
import '../../../../core/providers/isar_provider.dart';
import '../../domain/models/collection.dart';
import '../../domain/models/import_source.dart';
import '../../domain/models/media_item.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_storage/shared_storage.dart' as saf;
import 'package:uuid/uuid.dart';

import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/services/import_safety_policy.dart';
import 'package:private_shelf/core/services/secure_storage_service.dart';
import 'package:private_shelf/core/providers/shared_preferences_provider.dart';
import 'package:private_shelf/features/library/data/services/ios_security_scoped_resource.dart';
import 'package:downloadsfolder/downloadsfolder.dart';
import 'package:private_shelf/features/library/domain/models/media_format_utils.dart';

part 'external_storage_service.g.dart';

Future<String> selectUniqueDestinationPath(
  String requestedPath,
  Future<bool> Function(String path) exists,
) async {
  if (!await exists(requestedPath)) return requestedPath;
  final directory = p.dirname(requestedPath);
  final extension = p.extension(requestedPath);
  final baseName = p.basenameWithoutExtension(requestedPath);
  var suffix = 1;
  while (true) {
    final candidate = p.join(directory, '$baseName ($suffix)$extension');
    if (!await exists(candidate)) return candidate;
    suffix++;
  }
}

int _externalTempCopySequence = 0;

/// 完成前のファイルを公開せず、一時コピーを原子的に確定する。
Future<bool> writeAtomicExternalSnapshot({
  required File destination,
  required Future<bool> Function(File partialFile) writePartial,
}) async {
  final partialFile = File('${destination.path}.part');
  if (!await destination.parent.exists()) {
    await destination.parent.create(recursive: true);
  }
  if (await partialFile.exists()) {
    await partialFile.delete(); // audit: allow-file-io
  }

  try {
    final completed = await writePartial(partialFile);
    if (!completed || !await partialFile.exists()) {
      if (await partialFile.exists()) {
        await partialFile.delete(); // audit: allow-file-io
      }
      return false;
    }
    await partialFile.rename(destination.path);
    return true;
  } catch (_) {
    if (await partialFile.exists()) {
      await partialFile.delete(); // audit: allow-file-io
    }
    rethrow;
  }
}

/// プラットフォーム非依存のファイル情報。
/// Android の `saf.DocumentFile` と iOS の `FileSystemEntity` を統一する。
class ExternalFileInfo {
  final String uri;
  final String? name;
  final String? mimeType;
  final int? size;
  final DateTime? lastModified;

  /// ルートフォルダからの相対パス（フォルダインポート時のみ使用）
  final String? relativePath;

  final bool isDirectory;
  final bool isMedia;

  ExternalFileInfo({
    required this.uri,
    this.name,
    this.mimeType,
    this.size,
    this.lastModified,
    this.relativePath,
    this.isDirectory = false,
    this.isMedia = false,
  });
}

/// 外部ストレージアクセスサービス。
///
/// - **Android**: SAF (Storage Access Framework) 経由
/// - **iOS**: `file_picker` + Security-Scoped Bookmarks (MethodChannel) 経由
class ExternalStorageService {
  final SharedPreferences _prefs;
  Future<bool> Function(Uri)? isAccessInUse;
  final Set<Uri> activeImportGrants = {};
  final SecureStorageService? _secureStorage;
  final _iosResource = IosSecurityScopedResource();
  final int _maxImportFileCount;
  final int _maxScannedEntryCount;
  final int _maxImportTotalBytes;

  // ネイティブコードとの通信用チャネル（SAFのストリームコピーなど）
  static const _nativeChannel = MethodChannel('com.tsmusic.privateshelf/saf');

  ExternalStorageService(
    this._prefs, {
    this._secureStorage,
    this._maxImportFileCount = ImportSafetyPolicy.maxFileCount,
    this._maxScannedEntryCount = ImportSafetyPolicy.maxScannedEntryCount,
    this._maxImportTotalBytes = ImportSafetyPolicy.maxTotalBytes,
  });

  /// iOS用のBookmarkキーのプレフィックス
  static const _iosBookmarkPrefix = 'ios_bookmarks_';
  static const _iosBookmarkStoreKey = 'ios_security_scoped_bookmarks_v1';

  /// 現在のプラットフォームが外部ストレージ機能をサポートしているか。
  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  /// 初期化処理。
  ///
  /// - iOS: 保存されたBookmarkからアクセス権を復元
  /// - 共通: 24時間以上経過した孤立一時プレビューファイルを自動パージ
  Future<void> initialize() async {
    // 起動時に孤立した一時プレビューファイルを非同期パージ（ストレージリーク防止）
    cleanupOldTempFiles().catchError((Object e, StackTrace st) {
      AppLogger.w(LogTag.storage, '一時ファイルの自動パージに失敗', e, st);
    });

    if (!Platform.isIOS) return;

    final secureStorage = _secureStorage;
    if (secureStorage == null) {
      throw StateError('Secure storage is required for iOS bookmarks');
    }
    final bookmarks = await _readBookmarks();
    final legacyKeys = _prefs.getKeys().where(
      (key) => key.startsWith(_iosBookmarkPrefix),
    );
    for (final key in legacyKeys.toList(growable: false)) {
      if (key.startsWith(_iosBookmarkPrefix)) {
        final path = key.substring(_iosBookmarkPrefix.length);
        final base64 = _prefs.getString(key);
        if (base64 != null) {
          bookmarks[path] = base64;
        }
      }
    }
    await _writeBookmarks(bookmarks);
    for (final key in legacyKeys) {
      final removed = await _prefs.remove(key);
      if (!removed && _prefs.containsKey(key)) {
        throw StateError('Legacy bookmark migration could not be completed');
      }
    }
    for (final entry in bookmarks.entries) {
      try {
        final resolvedPath = await _iosResource.resolveBookmark(entry.value);
        if (resolvedPath == null) {
          AppLogger.w(LogTag.storage, 'Bookmark復元失敗（解決不可）');
        }
      } catch (e) {
        AppLogger.e(LogTag.storage, 'Bookmark復元エラー', e);
      }
    }
  }

  Future<Map<String, String>> _readBookmarks() async {
    final result = await _secureStorage!.read(key: _iosBookmarkStoreKey);
    if (result.isFailure) throw result.errorOrNull!;
    final value = result.dataOrNull;
    if (value == null || value.isEmpty) return <String, String>{};
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid bookmark store');
    }
    return decoded.map((key, value) {
      if (value is! String) throw const FormatException('Invalid bookmark');
      return MapEntry(key, value);
    });
  }

  Future<void> _writeBookmarks(Map<String, String> bookmarks) async {
    final result = await _secureStorage!.write(
      key: _iosBookmarkStoreKey,
      value: jsonEncode(bookmarks),
    );
    if (result.isFailure) throw result.errorOrNull!;
  }

  Future<void> _deleteBookmarkStore() async {
    final result = await _secureStorage!.delete(key: _iosBookmarkStoreKey);
    if (result.isFailure) throw result.errorOrNull!;
  }

  Future<void> _saveBookmark(String path, String bookmark) async {
    final bookmarks = await _readBookmarks();
    bookmarks[path] = bookmark;
    await _writeBookmarks(bookmarks);
  }

  // ─── フォルダ選択 ───

  /// フォルダ選択ピッカーを表示し、アクセスを取得する。
  Future<Uri?> pickFolder({bool persistAccess = true}) async {
    if (!isSupported) return null;
    try {
      if (Platform.isAndroid) {
        return await _pickFolderAndroid();
      } else {
        return await _pickFolderIOS(persistAccess: persistAccess);
      }
    } catch (e, st) {
      AppLogger.e(LogTag.storage, '外部フォルダ選択に失敗', e, st);
      return null;
    }
  }

  Future<Uri?> _pickFolderAndroid() async {
    final uri = await saf.openDocumentTree();
    if (uri != null) {
      AppLogger.d(LogTag.storage, '外部フォルダを選択 (Android): $uri');
    }
    return uri;
  }

  Future<Uri?> _pickFolderIOS({required bool persistAccess}) async {
    final dirPath = await FilePicker.getDirectoryPath();
    if (dirPath == null) return null;

    // Security-Scoped Bookmark を作成して保存
    final bookmarkBase64 = await _iosResource.createBookmark(dirPath);
    if (bookmarkBase64 == null) return null;
    final resolvedPath = await _iosResource.resolveBookmark(bookmarkBase64);
    if (resolvedPath == null) return null;

    if (persistAccess) {
      try {
        await _saveBookmark(resolvedPath, bookmarkBase64);
      } catch (_) {
        await _iosResource.stopAccessing(resolvedPath);
        rethrow;
      }
      AppLogger.d(LogTag.storage, 'Bookmark保存・アクセス開始完了: $resolvedPath');
    } else {
      AppLogger.d(LogTag.storage, '一時アクセス開始完了: $resolvedPath');
    }

    final uri = Uri.file(resolvedPath);
    AppLogger.d(LogTag.storage, '外部フォルダを選択 (iOS): $uri');
    return uri;
  }

  // ─── ファイル選択 ───

  /// ファイル選択ピッカーを表示し、複数の外部ファイルへのアクセスを取得する。
  Future<List<Uri>> pickFiles() async {
    if (!isSupported) return [];
    try {
      if (Platform.isAndroid) {
        return await _pickFilesAndroid();
      } else {
        return await _pickFilesIOS();
      }
    } catch (e, st) {
      AppLogger.e(LogTag.storage, '外部ファイル選択に失敗', e, st);
      return [];
    }
  }

  Future<List<Uri>> _pickFilesAndroid() async {
    final uris = await saf.openDocument(multiple: true);
    if (uris != null && uris.isNotEmpty) {
      AppLogger.d(LogTag.storage, '外部ファイルを選択 (Android): ${uris.length}件');
      return uris;
    }
    return [];
  }

  Future<List<Uri>> _pickFilesIOS() async {
    final result = await FilePicker.pickFiles(type: FileType.any);

    if (result.isEmpty) return [];

    final uris = <Uri>[];
    for (final file in result) {
      final path = file.path;
      if (path == null) continue;

      // Security-Scoped Bookmark を作成して保存
      final bookmarkBase64 = await _iosResource.createBookmark(path);
      if (bookmarkBase64 == null) continue;
      final resolvedPath = await _iosResource.resolveBookmark(bookmarkBase64);
      if (resolvedPath == null) continue;

      try {
        await _saveBookmark(resolvedPath, bookmarkBase64);
      } catch (_) {
        await _iosResource.stopAccessing(resolvedPath);
        rethrow;
      }
      AppLogger.d(LogTag.storage, 'Bookmark保存・アクセス開始完了 (File): $resolvedPath');
      uris.add(Uri.file(resolvedPath));
    }

    AppLogger.d(LogTag.storage, '外部ファイルを選択 (iOS): ${uris.length}件');
    return uris;
  }

  // ─── フォルダ権限管理 ───

  /// 永続化されたフォルダ権限の一覧を取得する（Android専用）。
  Future<List<saf.UriPermission>> getPersistedFolders() async {
    if (!Platform.isAndroid) return [];
    try {
      final permissions = await saf.persistedUriPermissions();
      return permissions ?? [];
    } catch (e, st) {
      AppLogger.e(LogTag.storage, '永続化済みURI取得に失敗', e, st);
      return [];
    }
  }

  /// 指定フォルダの永続的アクセス権を解放する。
  Future<void> releaseFolder(Uri folderUri) async {
    try {
      await releasePersistedAccess(folderUri);
    } catch (e, st) {
      AppLogger.e(LogTag.storage, '外部フォルダ権限解放に失敗', e, st);
    }
  }

  /// DB側の削除ジャーナルと連携し、失敗を呼び出し側へ返す厳密な解放処理。
  Future<void> releasePersistedAccess(Uri uri) async {
    if (Platform.isAndroid) {
      if (activeImportGrants.any((other) => sharesImportGrant(uri, other)) ||
          ImportSourceRepository(
            _prefs,
          ).read().any((s) => sharesImportGrant(uri, s.treeUri)) ||
          await isAccessInUse?.call(uri) == true) {
        return;
      }
      final permissions = await saf.persistedUriPermissions() ?? const [];
      if (!permissions.any((permission) => permission.uri == uri)) return;
      // A new selection may have adopted this URI while the queries awaited.
      if (activeImportGrants.any((other) => sharesImportGrant(uri, other)) ||
          ImportSourceRepository(
            _prefs,
          ).read().any((source) => sharesImportGrant(uri, source.treeUri))) {
        return;
      }
      await saf.releasePersistableUriPermission(uri);
      AppLogger.d(LogTag.storage, '外部ストレージ権限を解放 (SAF): $uri');
      return;
    }
    if (!Platform.isIOS) return;
    if (activeImportGrants.isNotEmpty ||
        await isAccessInUse?.call(uri) == true) {
      return;
    }

    final path = uri.toFilePath();
    final bookmarks = await _readBookmarks();
    if (!bookmarks.containsKey(path)) return;
    bookmarks.remove(path);
    await _writeBookmarks(bookmarks);
    // 永続bookmarkを先に消すことで、停止失敗後の次回起動で再取得しない。
    await _iosResource.stopAccessingStrict(path);
    AppLogger.d(LogTag.storage, '外部ストレージ権限を解放 (iOS): $path');
  }

  /// アプリが保持している外部ファイル・フォルダへの永続アクセスをすべて解放する。
  /// 元ファイルは変更しない。
  Future<void> releaseAllPersistedAccess() async {
    if (Platform.isAndroid) {
      final permissions = await saf.persistedUriPermissions() ?? const [];
      for (final permission in permissions) {
        try {
          await saf.releasePersistableUriPermission(permission.uri);
        } catch (error, stackTrace) {
          AppLogger.e(LogTag.storage, '外部ストレージ権限の一括解放に失敗', error, stackTrace);
        }
      }
      final remaining = await saf.persistedUriPermissions() ?? const [];
      if (remaining.isNotEmpty) {
        throw StateError('外部ストレージ権限を完全に解放できませんでした');
      }
      return;
    }
    if (!Platform.isIOS) return;

    // 現在のプロセスで取得済みのアクセスをすべて停止できた後でのみ、
    // 永続Bookmarkを削除する。停止失敗時はBookmarkを残して次回再試行する。
    await _iosResource.stopAllAccessingStrict();
    await _deleteBookmarkStore();
  }

  /// 選択された復元元だけを一時領域へコピーする。元データは変更しない。
  Future<Directory> stageRecoveryFolder(Uri folderUri) async {
    if (!folderUri.isScheme('content')) {
      throw const FileSystemException('SAFのフォルダを選択してください');
    }
    final temporary = await getTemporaryDirectory();
    final staging = await temporary.createTemp('tagshelf_restore_');
    try {
      final entries = <ExternalFileInfo>[];
      var scannedCount = 0;
      var declaredBytes = 0;
      await for (final entry in _listFilesRecursiveAndroid(
        folderUri,
        '',
        includeRecoveryMetadata: true,
      )) {
        scannedCount++;
        if (scannedCount > _maxScannedEntryCount) {
          throw const FileSystemException('復元元の項目数が安全上限を超えています');
        }
        if (entry.isDirectory) continue;
        final relative = entry.relativePath!;
        if (p.split(p.normalize(relative)).length >
            ImportSafetyPolicy.maxRelativePathDepth) {
          throw const FileSystemException('復元元のフォルダ階層が深すぎます');
        }
        final isMetadata =
            relative == '.tagshelf/metadata.json' ||
            relative == '.tagshelf/metadata.json.bak';
        if (!entry.isMedia && !isMetadata) continue;
        if (entries.length >= _maxImportFileCount) {
          throw const FileSystemException('復元可能なファイル数が安全上限を超えています');
        }
        final declaredSize = entry.size;
        if (declaredSize != null) {
          if (declaredSize < 0 ||
              (isMetadata &&
                  declaredSize > ImportSafetyPolicy.maxMetadataBytes)) {
            throw const FileSystemException('復元メタデータの容量が安全上限を超えています');
          }
          declaredBytes += declaredSize;
          if (declaredBytes > _maxImportTotalBytes) {
            throw const FileSystemException('復元データの合計容量が安全上限を超えています');
          }
        }
        entries.add(entry);
      }
      if (entries.isEmpty) {
        throw const FileSystemException('選択したフォルダに復元可能なデータがありません');
      }

      await ImportSafetyPolicy.ensureAvailableCapacity(
        staging.path,
        declaredBytes,
      );
      var copiedBytes = 0;
      for (final entry in entries) {
        final relative = entry.relativePath!;
        final isMetadata =
            relative == '.tagshelf/metadata.json' ||
            relative == '.tagshelf/metadata.json.bak';
        final destination = File(p.join(staging.path, relative));
        if (!p.isWithin(staging.path, destination.path)) {
          throw const FileSystemException('復元元フォルダ外のパスです');
        }
        final remainingLimit = isMetadata
            ? ImportSafetyPolicy.maxMetadataBytes
            : _maxImportTotalBytes - copiedBytes;
        final safeCopyLimit = await ImportSafetyPolicy.availableCopyLimit(
          staging.path,
          hardLimit: remainingLimit,
        );
        final copied = await writeAtomicExternalSnapshot(
          destination: destination,
          writePartial: (partial) async =>
              await _nativeChannel.invokeMethod<bool>('copyUriToFile', {
                'uri': entry.uri,
                'destPath': partial.path,
                'maxBytes': safeCopyLimit,
              }) ==
              true,
        );
        if (!copied ||
            (entry.size != null && await destination.length() != entry.size)) {
          throw const FileSystemException('復元元ファイルを完全に読み取れませんでした');
        }
        final copiedLength = await destination.length();
        if (isMetadata && copiedLength > ImportSafetyPolicy.maxMetadataBytes) {
          throw const FileSystemException('復元メタデータの容量が安全上限を超えています');
        }
        copiedBytes += copiedLength;
        if (copiedBytes > _maxImportTotalBytes) {
          throw const FileSystemException('復元データの合計容量が安全上限を超えています');
        }
        if (entry.size == null) {
          await ImportSafetyPolicy.ensureAvailableCapacity(staging.path, 0);
        }
      }
      return staging;
    } catch (_) {
      await staging.delete(recursive: true); // audit: allow-file-io
      rethrow;
    }
  }

  // ─── ファイル一覧 ───

  /// フォルダ内のメディアファイル一覧を取得する（Stream）。
  Stream<ExternalFileInfo> listFiles(
    Uri folderUri, {
    bool Function()? isCancelled,
  }) {
    if (Platform.isAndroid) {
      return _listFilesAndroid(folderUri, isCancelled: isCancelled);
    } else {
      return _listFilesIOS(folderUri, isCancelled: isCancelled);
    }
  }

  Stream<ExternalFileInfo> _listFilesAndroid(
    Uri folderUri, {
    bool Function()? isCancelled,
  }) async* {
    // 再帰的にファイルをリストアップするためのヘルパー
    yield* _listFilesRecursiveAndroid(folderUri, '', isCancelled: isCancelled);
  }

  Stream<ExternalFileInfo> _listFilesRecursiveAndroid(
    Uri dirUri,
    String currentRelativePath, {
    bool includeRecoveryMetadata = false,
    bool Function()? isCancelled,
  }) async* {
    final pending = <({Uri uri, String path, int depth})>[
      (uri: dirUri, path: currentRelativePath, depth: 0),
    ];
    var nextDirectory = 0;
    var scannedEntries = 0;
    while (nextDirectory < pending.length) {
      if (isCancelled?.call() == true) return;
      final directory = pending[nextDirectory++];
      if (directory.depth > ImportSafetyPolicy.maxRelativePathDepth) {
        throw const FileSystemException('フォルダ階層が安全上限を超えています');
      }
      final docs = <saf.DocumentFile>[];
      try {
        await for (final doc in saf.listFiles(
          directory.uri,
          columns: [
            saf.DocumentFileColumn.id,
            saf.DocumentFileColumn.displayName,
            saf.DocumentFileColumn.mimeType,
            saf.DocumentFileColumn.size,
            saf.DocumentFileColumn.lastModified,
          ],
        )) {
          if (isCancelled?.call() == true) return;
          scannedEntries++;
          if (scannedEntries > _maxScannedEntryCount) {
            throw const FileSystemException('走査項目数が安全上限を超えています');
          }
          docs.add(doc);
        }
      } catch (e, st) {
        AppLogger.e(LogTag.storage, 'SAFスキャンエラー: $e (${directory.uri})', e, st);
        if (includeRecoveryMetadata || e is FileSystemException) rethrow;
        continue;
      }

      for (final doc in docs) {
        if (isCancelled?.call() == true) return;

        final name = doc.name ?? '';
        if (name.isEmpty ||
            name == '.' ||
            name == '..' ||
            name.contains('/') ||
            name.contains('\\')) {
          if (includeRecoveryMetadata) {
            throw const FileSystemException('不正な復元元ファイル名です');
          }
          continue;
        }
        final recoveryMetadataDirectory =
            includeRecoveryMetadata &&
            directory.path.isEmpty &&
            name == '.tagshelf';
        if (MediaFormatUtils.isIgnoredDirectory(name) &&
            !recoveryMetadataDirectory) {
          continue;
        }

        final mime = doc.type ?? '';
        final isDir = mime == 'vnd.android.document/directory';
        final isRecoveryMetadata =
            includeRecoveryMetadata &&
            directory.path == '.tagshelf' &&
            (name == 'metadata.json' || name == 'metadata.json.bak');
        if (!isDir &&
            MediaFormatUtils.isIgnoredFile(name) &&
            !isRecoveryMetadata) {
          continue;
        }

        final ext = p.extension(name).toLowerCase();
        final isMedia = !isDir && isSupportedExtension(ext);

        yield ExternalFileInfo(
          uri: doc.uri.toString(),
          name: name,
          mimeType: mime,
          size: doc.size,
          lastModified: doc.lastModified,
          relativePath: directory.path.isEmpty
              ? name
              : p.join(directory.path, name),
          isDirectory: isDir,
          isMedia: isMedia,
        );

        if (isDir) {
          final subRelativePath = directory.path.isEmpty
              ? name
              : p.join(directory.path, name);
          pending.add((
            uri: doc.uri,
            path: subRelativePath,
            depth: directory.depth + 1,
          ));
        }
      }
    }
  }

  Stream<ExternalFileInfo> _listFilesIOS(
    Uri folderUri, {
    bool Function()? isCancelled,
  }) async* {
    final rootPath = folderUri.toFilePath();
    final dir = Directory(rootPath);
    if (!await dir.exists()) return;

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (isCancelled?.call() == true) return;

      final isDirectory = entity is Directory;
      final isFile = entity is File;
      if (!isDirectory && !isFile) continue;

      final relativePath = p.relative(entity.path, from: rootPath);
      final parts = p.split(relativePath);
      if (parts.any(MediaFormatUtils.isIgnoredDirectory)) continue;

      final fileName = p.basename(entity.path);
      if (isFile && MediaFormatUtils.isIgnoredFile(fileName)) continue;

      final ext = p.extension(entity.path).toLowerCase();
      final isMedia = isFile && isSupportedExtension(ext);

      int? size;
      DateTime? lastModified;
      if (isFile) {
        final stat = await entity.stat();
        size = stat.size;
        lastModified = stat.modified;
      }

      yield ExternalFileInfo(
        uri: Uri.file(entity.path).toString(), // スキーム付きURIを返す
        name: fileName,
        mimeType: isFile ? _mimeFromExtension(ext) : null,
        size: size,
        lastModified: lastModified,
        relativePath: relativePath,
        isDirectory: isDirectory,
        isMedia: isMedia,
      );
    }
  }

  // ─── ファイルアクセス ───

  // ─── ファイル書き込み ───

  /// 外部フォルダ内に新規ファイルを作成し、そのURIを返す。
  Future<Uri?> createFile(Uri parentUri, String name, String mimeType) async {
    try {
      if (Platform.isAndroid) {
        final doc = await saf.DocumentFile.fromTreeUri(parentUri);
        final newFile = await doc?.createFile(
          mimeType: mimeType,
          displayName: name,
        );
        return newFile?.uri;
      } else if (Platform.isIOS) {
        final parentPath = parentUri.toFilePath();
        final filePath = p.join(parentPath, name);
        final file = File(filePath);
        if (!await file.exists()) {
          await file.create(recursive: true);
        }
        return Uri.file(filePath);
      }
      return null;
    } catch (e, st) {
      AppLogger.e(LogTag.storage, '外部ファイルの作成に失敗', e, st);
      return null;
    }
  }

  /// 外部フォルダ内に新規フォルダを作成し、そのURIを返す。
  Future<Uri?> createFolder(Uri parentUri, String name) async {
    try {
      if (Platform.isAndroid) {
        final doc = await saf.DocumentFile.fromTreeUri(parentUri);
        final newDir = await doc?.createDirectory(name);
        return newDir?.uri;
      } else if (Platform.isIOS) {
        final parentPath = parentUri.toFilePath();
        final dirPath = p.join(parentPath, name);
        final dir = Directory(dirPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return Uri.file(dirPath);
      }
      return null;
    } catch (e, st) {
      AppLogger.e(LogTag.storage, '外部フォルダの作成に失敗', e, st);
      return null;
    }
  }

  /// 外部ファイルにバイトデータを書き込む。
  Future<bool> writeContent(Uri fileUri, Uint8List bytes) async {
    try {
      if (Platform.isAndroid) {
        return await saf.writeToFile(fileUri, bytes: bytes) ?? false;
      } else {
        final path = fileUri.toFilePath();
        final file = File(path);
        await file.writeAsBytes(bytes, flush: true);
        return true;
      }
    } catch (e, st) {
      AppLogger.e(LogTag.storage, '外部ファイルへの書き込みに失敗', e, st);
      return false;
    }
  }

  /// ファイル全体をDartヒープに読み込まず、ストリームで外部URIへ複製する。
  ///
  /// 失敗時は作成途中の出力を削除し、破損ファイルを成功結果として残さない。
  Future<bool> copyFileToUri(File sourceFile, Uri targetUri) async {
    try {
      if (!await sourceFile.exists()) return false;
      final copied = Platform.isAndroid
          ? await _nativeChannel.invokeMethod<bool>('copyFileToUri', {
                  'sourcePath': sourceFile.absolute.path,
                  'uri': targetUri.toString(),
                }) ??
                false
          : await _copyFileToPath(sourceFile, targetUri);
      if (!copied) {
        await _deleteExternalTarget(targetUri);
      }
      return copied;
    } catch (e, st) {
      AppLogger.e(LogTag.storage, '外部URIへのストリームコピーに失敗', e, st);
      await _deleteExternalTarget(targetUri);
      return false;
    }
  }

  Future<bool> _copyFileToPath(File sourceFile, Uri targetUri) async {
    if (!targetUri.isScheme('file')) return false;
    final target = File(targetUri.toFilePath());
    await target.parent.create(recursive: true);
    await sourceFile.openRead().pipe(target.openWrite());
    return await target.length() == await sourceFile.length();
  }

  Future<void> _deleteExternalTarget(Uri targetUri) async {
    try {
      if (Platform.isAndroid && !targetUri.isScheme('file')) {
        await saf.delete(targetUri);
        return;
      }
      if (targetUri.isScheme('file')) {
        final target = File(targetUri.toFilePath());
        if (await target.exists()) await target.delete();
      }
    } catch (e, st) {
      AppLogger.w(LogTag.storage, '不完全な外部出力の削除に失敗', e, st);
    }
  }

  /// 指定されたパスのファイルをシステムダウンロードフォルダにコピーする（主にAndroid用）
  Future<bool> saveToDownloadFolder(
    String sourcePath,
    String fileName, {
    String? subdirectory,
  }) async {
    try {
      if (Platform.isAndroid) {
        // MediaStore経由でDownloadフォルダに登録
        // downloadsfolder v2.0.0-pre.1+ は subDirectoryPath をサポートし、File? を返す
        final result = await copyFileIntoDownloadFolder(
          sourcePath,
          fileName,
          subDirectoryPath: subdirectory,
        );
        return result != null;
      } else if (Platform.isIOS) {
        // iOSではDocumentsを公開しない。呼び出し元がpickFolderで取得した
        // security-scopedな保存先へ明示的に書き出す必要がある。
        return false;
      }
      return false;
    } catch (e, st) {
      AppLogger.e(LogTag.storage, 'システムダウンロードフォルダへの保存に失敗', e, st);
      return false;
    }
  }

  /// システムデフォルトのダウンロードディレクトリを取得する
  Future<Directory?> getSystemDownloadDirectory() async {
    try {
      return await getDownloadDirectory();
    } catch (e) {
      return null;
    }
  }

  /// 外部ファイルのパス（iOS/fileスキーム用）を取得する。
  String? getFilePath(Uri uri) {
    if (uri.isScheme('file')) return uri.toFilePath();
    return null;
  }

  /// 一時ライブラリディレクトリにコピーする
  Future<String?> copyToTemp(
    Uri fileUri,
    String fileName, {
    int? expectedBytes,
    int? maxBytes,
  }) async {
    try {
      if (maxBytes != null &&
          (maxBytes < 0 || maxBytes > _maxImportTotalBytes)) {
        throw const FileSystemException('外部ファイルの容量制限が不正です');
      }
      if (expectedBytes != null &&
          (expectedBytes < 0 || expectedBytes > _maxImportTotalBytes)) {
        throw const FileSystemException('外部ファイルの容量が安全上限を超えています');
      }
      final isFileScheme = fileUri.isScheme('file');

      if (Platform.isIOS || (Platform.isAndroid && isFileScheme)) {
        // iOSまたはAndroidでfileスキームの場合：直接パスを使用
        final filePath = isFileScheme ? fileUri.toFilePath() : fileUri.path;
        final directFile = File(filePath);
        if (await directFile.exists()) {
          if (maxBytes != null && await directFile.length() > maxBytes) {
            throw const FileSystemException('外部ファイルの容量が残り上限を超えています');
          }
          if (expectedBytes != null &&
              await directFile.length() != expectedBytes) {
            throw const FileSystemException('外部ファイルの容量が選択後に変化しました');
          }
          return filePath;
        }
        if (Platform.isIOS) return null;
        // Androidでfileスキームのパスが存在しない場合はSAFフォールバックを試みるため続行
      }

      // Android: SAF 経由でコピー
      final tempDir = await getTemporaryDirectory();
      final sanitizedName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final hash = fileUri.toString().hashCode.toRadixString(16);
      final sequence = _externalTempCopySequence++;
      final ext = p.extension(sanitizedName);
      final base = p.basenameWithoutExtension(sanitizedName);
      const maxFileNameLength = 80;
      final copyId = '${DateTime.now().microsecondsSinceEpoch}_$sequence';
      var maxBaseLength =
          maxFileNameLength - hash.length - copyId.length - 2 - ext.length;
      if (maxBaseLength < 8) maxBaseLength = 8;
      final truncatedBase = base.length > maxBaseLength
          ? base.substring(0, maxBaseLength)
          : base;
      final uniqueFileName = '${hash}_${copyId}_$truncatedBase$ext';
      final tempFile = File(
        p.join(tempDir.path, 'external_view', uniqueFileName),
      );
      final copyLimit = await ImportSafetyPolicy.availableCopyLimit(
        tempDir.path,
        hardLimit:
            maxBytes != null &&
                (expectedBytes == null || maxBytes < expectedBytes)
            ? maxBytes
            : expectedBytes ?? _maxImportTotalBytes,
      );

      bool copied;
      if (Platform.isAndroid) {
        copied = await writeAtomicExternalSnapshot(
          destination: tempFile,
          writePartial: (partialFile) async {
            final success = await _nativeChannel
                .invokeMethod<bool>('copyUriToFile', {
                  'uri': fileUri.toString(),
                  'destPath': partialFile.path,
                  'maxBytes': copyLimit,
                });
            return success == true;
          },
        );
      } else {
        final bytes = await saf.getDocumentContent(fileUri);
        if (bytes == null || bytes.length > copyLimit) {
          AppLogger.e(LogTag.storage, 'ファイル内容の取得に失敗: $fileUri');
          return null;
        }
        copied = await writeAtomicExternalSnapshot(
          destination: tempFile,
          writePartial: (partialFile) async {
            await partialFile.writeAsBytes(bytes, flush: true);
            return true;
          },
        );
      }

      if (!copied) {
        AppLogger.e(LogTag.storage, '一時ファイルコピーを完了できませんでした: $fileUri');
        return null;
      }
      if (expectedBytes != null && await tempFile.length() != expectedBytes) {
        await tempFile.delete(); // audit: allow-file-io
        throw const FileSystemException('外部ファイルの容量が選択後に変化しました');
      }
      AppLogger.d(LogTag.storage, '一時ファイルに原子的コピー: ${tempFile.path}');
      return tempFile.path;
    } catch (e, st) {
      AppLogger.e(LogTag.storage, '一時ファイルコピーに失敗', e, st);
      return null;
    }
  }

  /// 一時ファイルをクリーンアップする（全削除）。
  Future<void> cleanupTemp() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final viewDir = Directory(p.join(tempDir.path, 'external_view'));
      if (await viewDir.exists()) {
        await viewDir.delete(recursive: true); // audit: allow-file-io
        AppLogger.d(LogTag.storage, '一時ファイルをクリーンアップ');
      }
    } catch (e, st) {
      AppLogger.e(LogTag.storage, '一時ファイルクリーンアップに失敗', e, st);
    }
  }

  /// 一定期間以上経過した古い一時プレビューファイルのみを安全にパージする。
  Future<void> cleanupOldTempFiles({
    Duration maxAge = const Duration(hours: 24),
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final viewDir = Directory(p.join(tempDir.path, 'external_view'));
      if (!await viewDir.exists()) return;

      final now = DateTime.now();
      var deletedCount = 0;
      await for (final entity in viewDir.list(recursive: false)) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            if (now.difference(stat.modified) > maxAge) {
              await entity.delete(); // audit: allow-file-io
              deletedCount++;
            }
          } on FileSystemException catch (e) {
            // 他の処理で既に削除されている場合などは安全にスキップ
            AppLogger.d(
              LogTag.storage,
              '古い一時ファイル削除スキップ (消失またはアクセス不可): ${entity.path}, $e',
            );
          } catch (e, st) {
            AppLogger.w(
              LogTag.storage,
              '古い一時ファイルの個別削除中にエラー: ${entity.path}',
              e,
              st,
            );
          }
        }
      }
      if (deletedCount > 0) {
        AppLogger.d(LogTag.storage, '期限切れ一時ファイル $deletedCount 件をクリーンアップ');
      }
    } catch (e, st) {
      AppLogger.e(LogTag.storage, '古い一時ファイルクリーンアップに失敗', e, st);
    }
  }

  /// OS標準アプリでファイルを開く（動画再生など）。
  Future<bool> openWithSystem(Uri fileUri) async {
    try {
      if (Platform.isAndroid) {
        final result = await saf.openDocumentFile(fileUri);
        AppLogger.d(LogTag.storage, 'システムアプリで開く: $fileUri → $result');
        return result;
      } else {
        // iOS: open_file パッケージを使用して開く
        final path = fileUri.toFilePath();
        final result = await OpenFile.open(path);

        if (result.type != ResultType.done) {
          AppLogger.w(LogTag.storage, 'ファイルオープン失敗: ${result.message}');
          return false;
        }

        AppLogger.d(LogTag.storage, '外部アプリで開きました: $path');
        return true;
      }
    } catch (e, st) {
      AppLogger.e(LogTag.storage, 'システムアプリで開くのに失敗', e, st);
      return false;
    }
  }

  // ─── サムネイル ───

  /// ファイルのサムネイルバイトを取得する。
  Future<Uint8List?> getThumbnailBytes(Uri fileUri) async {
    try {
      final isFileScheme = fileUri.isScheme('file');
      if (Platform.isAndroid && !isFileScheme) {
        final bitmap = await saf.getDocumentThumbnail(
          uri: fileUri,
          width: 256,
          height: 256,
        );
        return bitmap?.bytes;
      } else {
        // iOS または Android で file スキームの場合
        final filePath = isFileScheme ? fileUri.toFilePath() : fileUri.path;
        final ext = p.extension(filePath).toLowerCase();
        final mime = _mimeFromExtension(ext);
        if (!mime.startsWith('image/')) {
          AppLogger.d(
            LogTag.storage,
            '[ImageDecodeTrace] skip thumbnail bytes for non-image file path=$filePath ext=$ext mime=$mime',
          );
          return null;
        }
        final file = File(filePath);
        if (await file.exists()) {
          final stat = await file.stat();
          // 一覧用の画像はネイティブ側で縮小し、元画像のバイト列を保持しない。
          final format = switch (ext) {
            '.png' => CompressFormat.png,
            '.webp' => CompressFormat.webp,
            _ => CompressFormat.jpeg,
          };
          try {
            final thumbnail = await FlutterImageCompress.compressWithFile(
              filePath,
              minWidth: 256,
              minHeight: 256,
              quality: 75,
              format: format,
            );
            if (thumbnail != null && thumbnail.isNotEmpty) return thumbnail;
          } catch (e) {
            AppLogger.d(LogTag.storage, '画像縮小に失敗したため元画像を確認します: $e');
          }
          // 非対応形式では従来どおり上限内の元画像を表示する。
          if (stat.size < 10 * 1024 * 1024) {
            return await file.readAsBytes();
          }
        }
        return null;
      }
    } catch (e) {
      AppLogger.d(LogTag.storage, 'サムネイル取得に失敗（正常な場合あり）: $e');
      return null;
    }
  }

  /// ファイルのバイトを読み込む（サムネイル生成用）。
  Future<Uint8List?> getFileBytes(Uri fileUri, {required int maxBytes}) async {
    try {
      if (maxBytes <= 0 || maxBytes > _maxImportTotalBytes) return null;
      final isFileScheme = fileUri.isScheme('file');
      if (Platform.isAndroid && !isFileScheme) {
        final tempDir = await getTemporaryDirectory();
        final snapshot = File(
          p.join(tempDir.path, 'bounded_read_${const Uuid().v4()}'),
        );
        try {
          final copied = await writeAtomicExternalSnapshot(
            destination: snapshot,
            writePartial: (partial) async =>
                await _nativeChannel.invokeMethod<bool>('copyUriToFile', {
                  'uri': fileUri.toString(),
                  'destPath': partial.path,
                  'maxBytes': maxBytes,
                }) ==
                true,
          );
          if (!copied || await snapshot.length() > maxBytes) return null;
          return await snapshot.readAsBytes();
        } finally {
          if (await snapshot.exists()) {
            await snapshot.delete(); // audit: allow-file-io
          }
        }
      } else {
        final filePath = isFileScheme ? fileUri.toFilePath() : fileUri.path;
        final file = File(filePath);
        if (await file.exists() && await file.length() <= maxBytes) {
          return await file.readAsBytes();
        }
        return null;
      }
    } catch (e) {
      AppLogger.d(LogTag.storage, 'ファイルバイト読み込みに失敗: $e');
      return null;
    }
  }

  /// ファイルが存在するかチェックする。
  Future<bool> fileExists(Uri fileUri) async {
    try {
      final isFileScheme = fileUri.isScheme('file');
      if (Platform.isAndroid && !isFileScheme) {
        final doc = await saf.DocumentFile.fromTreeUri(fileUri);
        final result = await doc?.exists();
        if (result == null) {
          throw StateError('外部ファイルの存在を確認できませんでした');
        }
        return result;
      } else {
        final filePath = isFileScheme ? fileUri.toFilePath() : fileUri.path;
        return await File(filePath).exists();
      }
    } catch (e, st) {
      AppLogger.w(LogTag.storage, '外部ファイルの存在確認に失敗', e, st);
      rethrow;
    }
  }

  /// フォルダが現在アクセス可能かチェックする。
  Future<bool> isDirAccessible(Uri folderUri) async {
    try {
      if (Platform.isAndroid) {
        // Android (SAF): 権限が永続化されていても、SDカード未装着などでアクセス不可になる場合がある
        final doc = await saf.DocumentFile.fromTreeUri(folderUri);
        if (doc == null) return false;
        final exists = await doc.exists();
        return exists == true && doc.isDirectory == true;
      } else if (Platform.isIOS) {
        final dir = Directory(folderUri.toFilePath());
        return await dir.exists();
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ─── ヘルパー ───

  static Set<String> get supportedExtensions =>
      MediaFormatUtils.allSupportedExtensions;

  bool isSupportedExtension(String ext) =>
      MediaFormatUtils.allSupportedExtensions.contains(ext.toLowerCase());

  String _mimeFromExtension(String ext) {
    switch (ext) {
      // Images
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.bmp':
        return 'image/bmp';
      case '.webp':
        return 'image/webp';
      case '.heic':
      case '.heif':
        return 'image/heic';
      case '.tiff':
      case '.tif':
        return 'image/tiff';
      case '.svg':
        return 'image/svg+xml';
      case '.ico':
        return 'image/x-icon';
      // Videos
      case '.mp4':
      case '.m4v':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.avi':
        return 'video/x-msvideo';
      case '.mkv':
        return 'video/x-matroska';
      case '.webm':
        return 'video/webm';
      case '.3gp':
        return 'video/3gpp';
      case '.flv':
        return 'video/x-flv';
      case '.wmv':
        return 'video/x-ms-wmv';
      case '.ts':
        return 'video/mp2t';
      // Audio
      case '.mp3':
        return 'audio/mpeg';
      case '.wav':
        return 'audio/wav';
      case '.m4a':
        return 'audio/mp4';
      case '.flac':
        return 'audio/flac';
      case '.aac':
        return 'audio/aac';
      case '.ogg':
        return 'audio/ogg';
      // Documents
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.xls':
        return 'application/vnd.ms-excel';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.ppt':
        return 'application/vnd.ms-powerpoint';
      case '.pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case '.txt':
        return 'text/plain';
      case '.csv':
        return 'text/csv';
      // Archives
      case '.zip':
        return 'application/zip';
      case '.rar':
        return 'application/vnd.rar';
      case '.7z':
        return 'application/x-7z-compressed';
      case '.tar':
        return 'application/x-tar';
      case '.gz':
        return 'application/gzip';
      default:
        return 'application/octet-stream';
    }
  }
}

@riverpod
Future<ExternalStorageService> externalStorageService(Ref ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  final service = ExternalStorageService(
    prefs,
    secureStorage: ref.read(secureStorageServiceProvider),
  );
  final isarFuture = ref.read(isarProvider.future);
  service.isAccessInUse = (grant) async {
    // Include hidden, archived and trashed references: they may be restored later.
    final isar = await isarFuture;
    final folders = await isar.mediaCollections
        .filter()
        .typeEqualTo(CollectionType.externalFolder)
        .findAll();
    final items = await isar.mediaItems
        .filter()
        .sourceTypeEqualTo(MediaSourceType.externalReference)
        .findAll();
    bool uses(String location) {
      var other = Uri.parse(location);
      if (!other.hasScheme) other = Uri.file(location);
      if (grant.isScheme('file') && other.isScheme('file')) {
        return p.equals(grant.toFilePath(), other.toFilePath()) ||
            p.isWithin(grant.toFilePath(), other.toFilePath()) ||
            p.isWithin(other.toFilePath(), grant.toFilePath());
      }
      return sharesImportGrant(grant, other);
    }

    if (folders.any((f) => uses(f.path)) || items.any((f) => uses(f.path))) {
      return true;
    }
    for (final record in await isar.referenceMigrations.where().findAll()) {
      if (record.committed) continue;
      final snapshot = jsonDecode(record.snapshot) as Map;
      final sources = snapshot['sources'] as Map? ?? {};
      if (sources.values.cast<String>().any(uses)) return true;
    }
    return false;
  };
  await service.initialize();
  return service;
}
