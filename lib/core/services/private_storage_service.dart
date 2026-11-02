import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../logger/app_logger.dart';
import '../logger/log_tag.dart';

/// アプリが管理する機密ファイルのルートを返す。
///
/// iOS の Documents は File Sharing 設定の影響を受けるため、機密データは
/// Application Support 配下へ保存する。他プラットフォームは既存の保存場所を
/// 維持し、不要なデータ移行を発生させない。
class PrivateStorageService {
  PrivateStorageService._();

  static const privateDirectoryName = 'PrivateShelf';
  static const migrationMarkerName = '.private_storage_migration_v1.json';
  static const _privacyChannel = MethodChannel(
    'com.tsmusic.privateshelf/privacy',
  );
  static Directory? _activeDirectory;

  /// runApp より前に呼び出し、必要ならiOSの旧Documentsデータを移行する。
  static Future<Directory> prepare() async {
    final documents = await getApplicationDocumentsDirectory();
    if (!Platform.isIOS) {
      _activeDirectory = documents;
      return documents;
    }

    final support = await getApplicationSupportDirectory();
    final destination = Directory(p.join(support.path, privateDirectoryName));
    final marker = File(p.join(support.path, migrationMarkerName));

    late final Directory selectedDirectory;
    try {
      await PrivateStorageMigrator().migrate(
        source: documents,
        destination: destination,
        marker: marker,
      );
      selectedDirectory = destination;
    } catch (error, stackTrace) {
      // Info.plist で Documents の共有は無効化済みなので、移行失敗時も
      // 旧ルートを使えば機密境界を保ったままデータ損失を避けられる。
      AppLogger.e(
        LogTag.storage,
        'プライベートストレージ移行に失敗したため旧保存先を使用します',
        error,
        stackTrace,
      );
      selectedDirectory = documents;
    }

    await enforceBackupExclusion(selectedDirectory);
    _activeDirectory = selectedDirectory;
    return selectedDirectory;
  }

  static Future<Directory> getDirectory() async {
    final active = _activeDirectory;
    if (active != null) return active;

    final documents = await getApplicationDocumentsDirectory();
    if (!Platform.isIOS) return documents;

    final support = await getApplicationSupportDirectory();
    final destination = Directory(p.join(support.path, privateDirectoryName));
    final marker = File(p.join(support.path, migrationMarkerName));
    if (await PrivateStorageMigrator().isComplete(
      destination: destination,
      marker: marker,
    )) {
      await enforceBackupExclusion(destination);
      _activeDirectory = destination;
      return destination;
    }
    await enforceBackupExclusion(documents);
    _activeDirectory = documents;
    return documents;
  }

  /// iOSのアプリコンテナ内にある機密ディレクトリを自動バックアップから除外する。
  static Future<void> enforceBackupExclusion(Directory directory) async {
    if (!Platform.isIOS) return;

    final applied = await _privacyChannel.invokeMethod<bool>(
      'setExcludedFromBackup',
      {'path': directory.absolute.path},
    );
    if (applied != true) {
      throw StateError('Private storage backup exclusion was not applied');
    }
  }

  @visibleForTesting
  static void resetForTesting() {
    _activeDirectory = null;
  }
}

Future<Directory> getPrivateStorageDirectory() =>
    PrivateStorageService.getDirectory();

/// Documents から私有領域への、再実行可能なコピー移行。
///
/// コピー先は既存ファイルを上書きせず、同一内容だけを再利用する。全ファイルを
/// ハッシュ検証して完了マーカーを確定した後にだけ移行元を削除するため、強制終了後も
/// 安全に再開でき、旧Documentsに機密コピーを残さない。
class PrivateStorageMigrator {
  static const migrationVersion = 1;

  Future<bool> isComplete({
    required Directory destination,
    required File marker,
  }) async {
    return await destination.exists() && await _hasValidMarker(marker);
  }

  Future<void> migrate({
    required Directory source,
    required Directory destination,
    required File marker,
  }) async {
    final sourcePath = p.canonicalize(source.absolute.path);
    final destinationPath = p.canonicalize(destination.absolute.path);
    if (sourcePath == destinationPath ||
        p.isWithin(sourcePath, destinationPath)) {
      throw StateError('Invalid private storage migration destination');
    }

    if (await isComplete(destination: destination, marker: marker)) {
      await _cleanupSourceAfterCommit(source);
      return;
    }

    await destination.create(recursive: true);
    // 移行途中の部分コピーもバックアップ対象にしない。最初のコピーより前に
    // 毎回適用し、強制終了後に残った既存destinationにも再適用する。
    await PrivateStorageService.enforceBackupExclusion(destination);
    if (await source.exists()) {
      await _copyDirectory(source, destination, source.path);
      final sourceStats = await _collectStats(source);
      final destinationStats = await _collectStats(destination);
      if (sourceStats.fileCount != destinationStats.fileCount ||
          sourceStats.totalBytes != destinationStats.totalBytes) {
        throw StateError('Private storage migration verification failed');
      }
      await _verifyCopiedFiles(source, destination);

      await _writeMarker(
        marker,
        fileCount: sourceStats.fileCount,
        totalBytes: sourceStats.totalBytes,
      );
      await _cleanupSourceAfterCommit(source);
      return;
    }

    await _writeMarker(marker, fileCount: 0, totalBytes: 0);
  }

  Future<void> _cleanupSourceAfterCommit(Directory source) async {
    if (!await source.exists()) return;
    try {
      await for (final entity in source.list(followLinks: false)) {
        if (entity is Directory) {
          await entity.delete(recursive: true); // audit: allow-file-io
        } else {
          await entity.delete(); // audit: allow-file-io
        }
      }
    } catch (error, stackTrace) {
      // 完了マーカーは検証済みコピーの存在を保証する。削除失敗を移行失敗として
      // 扱うと不完全な旧ルートへ戻るため、次回起動で再試行する。
      AppLogger.w(
        LogTag.storage,
        '検証済み移行元の削除に失敗しました。次回起動時に再試行します',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _copyDirectory(
    Directory source,
    Directory destination,
    String sourceRoot,
  ) async {
    await for (final entity in source.list(followLinks: false)) {
      final relativePath = p.relative(entity.path, from: sourceRoot);
      final targetPath = p.join(destination.path, p.basename(entity.path));
      final type = await FileSystemEntity.type(entity.path, followLinks: false);

      if (type == FileSystemEntityType.link) {
        throw StateError('Symbolic links are not allowed in private storage');
      }
      if (type == FileSystemEntityType.directory) {
        final targetDirectory = Directory(targetPath);
        await targetDirectory.create(recursive: true);
        await _copyDirectory(entity as Directory, targetDirectory, sourceRoot);
        continue;
      }
      if (type != FileSystemEntityType.file) continue;

      final sourceFile = entity as File;
      final targetFile = File(targetPath);
      if (await targetFile.exists()) {
        if (!await _filesMatch(sourceFile, targetFile)) {
          throw StateError('Conflicting migration file: $relativePath');
        }
        continue;
      }

      await targetFile.parent.create(recursive: true);
      final partial = File('$targetPath.migrating');
      if (await partial.exists()) {
        await partial.delete();
      }
      await sourceFile.copy(partial.path);
      if (await sourceFile.length() != await partial.length()) {
        await partial.delete();
        throw StateError('Incomplete migration copy: $relativePath');
      }
      await partial.rename(targetPath);
    }
  }

  Future<_StorageStats> _collectStats(Directory root) async {
    var fileCount = 0;
    var totalBytes = 0;
    if (!await root.exists()) return const _StorageStats(0, 0);

    await for (final entity in root.list(recursive: true, followLinks: false)) {
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type == FileSystemEntityType.link) {
        throw StateError('Symbolic links are not allowed in private storage');
      }
      if (type == FileSystemEntityType.file &&
          !entity.path.endsWith('.migrating')) {
        fileCount++;
        totalBytes += await (entity as File).length();
      }
    }
    return _StorageStats(fileCount, totalBytes);
  }

  Future<void> _verifyCopiedFiles(
    Directory source,
    Directory destination,
  ) async {
    await for (final entity in source.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final relativePath = p.relative(entity.path, from: source.path);
      final target = File(p.join(destination.path, relativePath));
      if (!await target.exists() || !await _filesMatch(entity, target)) {
        throw StateError('Migration verification failed: $relativePath');
      }
    }
  }

  Future<bool> _hasValidMarker(File marker) async {
    if (!await marker.exists()) return false;
    try {
      final decoded = jsonDecode(await marker.readAsString());
      return decoded is Map<String, dynamic> &&
          decoded['version'] == migrationVersion &&
          decoded['fileCount'] is int &&
          decoded['totalBytes'] is int;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _filesMatch(File left, File right) async {
    if (await left.length() != await right.length()) return false;
    final leftHash = await sha256.bind(left.openRead()).first;
    final rightHash = await sha256.bind(right.openRead()).first;
    return leftHash == rightHash;
  }

  Future<void> _writeMarker(
    File marker, {
    required int fileCount,
    required int totalBytes,
  }) async {
    await marker.parent.create(recursive: true);
    final temporaryMarker = File('${marker.path}.migrating');
    await temporaryMarker.writeAsString(
      jsonEncode({
        'version': migrationVersion,
        'fileCount': fileCount,
        'totalBytes': totalBytes,
      }),
      flush: true,
    );
    if (await marker.exists()) await marker.delete();
    await temporaryMarker.rename(marker.path);
  }
}

class _StorageStats {
  const _StorageStats(this.fileCount, this.totalBytes);

  final int fileCount;
  final int totalBytes;
}
