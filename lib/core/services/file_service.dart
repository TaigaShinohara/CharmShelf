import 'dart:convert';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;

import 'storage_sandbox.dart';
import 'private_storage_service.dart';
import 'import_safety_policy.dart';
import 'import_copy_artifacts.dart';

part 'file_service.g.dart';

class TrashStagingEntry {
  const TrashStagingEntry({
    required this.operationId,
    required this.modifiedAt,
  });

  final String operationId;
  final DateTime modifiedAt;
}

@Riverpod(keepAlive: true)
FileService fileService(Ref ref) {
  return FileService();
}

class FileService {
  final _uuid = const Uuid();
  static const _libraryRoots = {'library'};
  static const _managedRoots = {'library', '.thumbnails', '.trash', '.imports'};
  static final _activeImports = <String, int>{};

  static bool isImportActive(String operationId) =>
      _activeImports.containsKey(operationId);

  /// Recovery must not race a live copy or its subsequent database commit.
  static Future<T> runImportOperation<T>(
    String operationId,
    Future<T> Function() action,
  ) async {
    _activeImports.update(operationId, (count) => count + 1, ifAbsent: () => 1);
    try {
      return await action();
    } finally {
      final count = _activeImports[operationId]!;
      if (count == 1) {
        _activeImports.remove(operationId);
      } else {
        _activeImports[operationId] = count - 1;
      }
    }
  }

  /// Check ownership before recovery touches the destination or temporary files.
  Future<Result<void, AppError>> validateImportCopyArtifacts(
    ImportCopyArtifacts artifacts, {
    required bool destinationWasStaged,
  }) async {
    try {
      if (isImportActive(artifacts.operationId)) {
        throw const FileSystemException('Import operation is still active');
      }
      final docs = await getPrivateStorageDirectory();
      final destination = await _resolveManagedPath(
        docs,
        artifacts.destinationPath,
        allowedRoots: _libraryRoots,
      );
      final partial = await _resolveManagedPath(
        docs,
        artifacts.partialPath,
        allowedRoots: _libraryRoots,
      );
      final reservation = File(
        await _resolveManagedPath(
          docs,
          artifacts.reservationPath,
          allowedRoots: _libraryRoots,
        ),
      );
      final reservationType = await FileSystemEntity.type(reservation.path);
      final partialType = await FileSystemEntity.type(partial);
      final destinationType = await FileSystemEntity.type(destination);
      if ((destinationType != FileSystemEntityType.file &&
              destinationType != FileSystemEntityType.notFound) ||
          (!destinationWasStaged &&
              partialType != FileSystemEntityType.notFound &&
              destinationType != FileSystemEntityType.notFound)) {
        // A partial that still exists has not been renamed to the destination.
        // An entity at both paths may be somebody else's newly created data.
        throw const FileSystemException(
          'Import destination ownership conflicts',
        );
      }
      if (partialType != FileSystemEntityType.file &&
          partialType != FileSystemEntityType.notFound) {
        throw const FileSystemException('Import partial is not a regular file');
      }
      if (reservationType == FileSystemEntityType.file) {
        if (await reservation.length() > 2048 ||
            !artifacts.ownsReservation(
              jsonDecode(await reservation.readAsString()),
            )) {
          throw const FileSystemException(
            'Import reservation ownership is uncertain',
          );
        }
      } else if (reservationType != FileSystemEntityType.notFound ||
          partialType != FileSystemEntityType.notFound ||
          (!destinationWasStaged &&
              await FileSystemEntity.type(destination) !=
                  FileSystemEntityType.notFound)) {
        // A crash before writing ownership, or between rename and staged journal
        // persistence, cannot be resolved by guessing from a similar filename.
        throw const FileSystemException(
          'Import copy ownership requires review',
        );
      }
      return Result.success(null);
    } catch (error, stack) {
      return Result.failure(
        _operationError('Could not verify import copy ownership', error, stack),
      );
    }
  }

  Future<Result<void, AppError>> cleanupImportCopyArtifacts(
    ImportCopyArtifacts artifacts,
  ) async {
    final validation = await validateImportCopyArtifacts(
      artifacts,
      destinationWasStaged: true,
    );
    if (validation.isFailure) return validation;
    // Both exact paths were verified together before deleting either one.
    for (final path in [artifacts.partialPath, artifacts.reservationPath]) {
      final result = await deleteFile(path);
      if (result.isFailure) return result;
    }
    return Result.success(null);
  }

  bool _isManagedRoot(String relativePath) {
    final normalized = p.normalize(relativePath);
    return _managedRoots.contains(normalized);
  }

  AppError _operationError(String message, Object error, StackTrace stack) {
    if (error is FileSystemException) {
      return AppError(
        message: message,
        category: ErrorCategory.validation,
        severity: ErrorSeverity.info,
        originalError: error,
        stackTrace: stack,
        context: 'FileService',
      );
    }
    return AppError.file(message, original: error, stackTrace: stack);
  }

  Future<String> _resolveManagedPath(
    Directory docsDir,
    String relativePath, {
    Set<String> allowedRoots = _managedRoots,
  }) async {
    final resolved = StorageSandbox.resolveRelative(
      docsDir.path,
      relativePath,
      allowedTopLevelDirectories: allowedRoots,
    );
    await StorageSandbox.rejectSymbolicLinkAncestors(docsDir.path, resolved);
    return resolved;
  }

  /// アプリのドキュメントディレクトリ配下の `library` ディレクトリを取得
  Future<Directory> getLibraryDirectory() async {
    final docsDir = await getPrivateStorageDirectory();
    final libraryDir = Directory(p.join(docsDir.path, 'library'));
    if (!libraryDir.existsSync()) {
      await libraryDir.create(recursive: true);
    }
    return libraryDir;
  }

  /// 管理ライブラリ配下に、衝突しない名前でディレクトリを作成する。
  ///
  /// 戻り値は Documents ディレクトリからの相対パス。
  Future<Result<String, AppError>> createUniqueDirectory({
    required String parentRelativePath,
    required String name,
    Future<void> Function(String relativePath)? onDestinationPrepared,
  }) async {
    try {
      if (name.isEmpty ||
          name == '.' ||
          name == '..' ||
          p.basename(name) != name) {
        return Result.failure(AppError.validation('Invalid directory name'));
      }

      final docsDir = await getPrivateStorageDirectory();
      final parentPath = await _resolveManagedPath(
        docsDir,
        parentRelativePath,
        allowedRoots: _libraryRoots,
      );
      await Directory(parentPath).create(recursive: true);

      var candidateName = name;
      var suffix = 1;
      while (true) {
        final candidatePath = p.join(parentPath, candidateName);
        final entityType = FileSystemEntity.typeSync(candidatePath);
        if (entityType == FileSystemEntityType.notFound) {
          final relativePath = p.relative(candidatePath, from: docsDir.path);
          await onDestinationPrepared?.call(relativePath);
          await Directory(candidatePath).create();
          return Result.success(relativePath);
        }
        candidateName = '$name ($suffix)';
        suffix++;
      }
    } catch (e, st) {
      return Result.failure(
        _operationError('Failed to create directory', e, st),
      );
    }
  }

  /// 指定されたパス内のファイルを走査する
  Future<Result<List<File>, AppError>> scanDirectory(String path) async {
    try {
      final dir = Directory(path);
      if (!dir.existsSync()) {
        return Result.failure(AppError.file('Directory not found: $path'));
      }

      final files = await dir
          .list(recursive: true, followLinks: false)
          .where((entity) {
            if (entity is! File) return false;
            final fileName = p.basename(entity.path);
            if (fileName.startsWith('.') ||
                fileName.startsWith('._') ||
                fileName.endsWith('.tmp') ||
                fileName.endsWith('.bak') ||
                fileName == 'crash_reports.json' ||
                fileName == '__MACOSX' ||
                fileName == 'Thumbs.db' ||
                fileName == 'desktop.ini') {
              return false;
            }
            final relParts = p.split(p.relative(entity.path, from: path));
            if (relParts.any(
              (part) => part.startsWith('.') || part == '__MACOSX',
            )) {
              return false;
            }
            return true;
          })
          .cast<File>()
          .toList();

      return Result.success(files);
    } catch (e, st) {
      return Result.failure(
        AppError.file(
          'Failed to scan directory: $e',
          original: e,
          stackTrace: st,
        ),
      );
    }
  }

  /// サムネイルを生成して保存する
  /// 戻り値: アプリ内相対パス
  Future<Result<String, AppError>> generateThumbnail(
    File file, {
    int? timeMs,
  }) async {
    try {
      final docsDir = await getPrivateStorageDirectory();
      final thumbDir = Directory(p.join(docsDir.path, '.thumbnails'));
      if (!thumbDir.existsSync()) {
        await thumbDir.create(recursive: true);
      }

      final fileName = '${_uuid.v4()}.jpg';
      final targetPath = p.join(thumbDir.path, fileName);

      final mimeType = lookupMimeType(file.path) ?? '';

      if (mimeType.startsWith('image/')) {
        // 画像圧縮 & リサイズ
        final result = await FlutterImageCompress.compressAndGetFile(
          file.absolute.path,
          targetPath,
          minWidth: 512,
          minHeight: 512,
          quality: 80,
        );
        if (result == null) {
          return Result.failure(
            AppError.unknown('Image thumbnail generation failed'),
          );
        }
      } else if (mimeType.startsWith('video/')) {
        // 動画サムネイル生成
        final result = await vt.VideoThumbnail.thumbnailFile(
          video: file.path,
          thumbnailPath: targetPath,
          imageFormat: vt.ImageFormat.JPEG,
          maxWidth: 512,
          maxHeight: 512,
          quality: 75,
          timeMs: timeMs ?? 0, // 指定がなければ冒頭
        );
        if (result == null) {
          return Result.failure(
            AppError.unknown('Video thumbnail generation failed'),
          );
        }
      } else {
        return Result.failure(
          AppError.unknown('Unsupported file type for thumbnail: $mimeType'),
        );
      }

      final relativePath = p.relative(targetPath, from: docsDir.path);
      return Result.success(relativePath);
    } catch (e, st) {
      return Result.failure(
        AppError.file(
          'Failed to generate thumbnail: $e',
          original: e,
          stackTrace: st,
        ),
      );
    }
  }

  /// フォルダ（漫画など）内の特定ファイルからサムネイルを生成する
  Future<Result<String, AppError>> generateFolderThumbnail(
    Directory dir,
    String fileName,
  ) async {
    try {
      final file = File(p.join(dir.path, fileName));
      if (!file.existsSync()) {
        return Result.failure(AppError.file('Source file not found'));
      }
      return await generateThumbnail(file);
    } catch (e, st) {
      return Result.failure(
        AppError.file(
          'Failed to generate folder thumbnail: $e',
          original: e,
          stackTrace: st,
        ),
      );
    }
  }

  /// ファイルを指定されたパスにコピーする (インポート用)
  /// [targetParentPath]: 保存先の親フォルダパス (documents 相対)
  Future<Result<String, AppError>> importFile(
    File file, {
    String? targetParentPath,
    String? sourceFileName,
    Future<void> Function(String relativePath)? onDestinationPrepared,
    Future<void> Function(String relativePath)? onDestinationPublished,
    int maxBytes = ImportSafetyPolicy.maxTotalBytes,
    int? expectedBytes,
    String? importOperationId,
  }) {
    final operationId = importOperationId ?? _uuid.v4();
    return runImportOperation(operationId, () async {
      File? partialFile;
      File? reservationFile;
      var ownsPartial = false;
      var destinationPublished = false;
      try {
        final docsDir = await getPrivateStorageDirectory();
        final libraryDir = await getLibraryDirectory();
        final sourceLength = await file.length();
        if (sourceLength < 0 ||
            sourceLength > maxBytes ||
            (expectedBytes != null && sourceLength != expectedBytes)) {
          throw const FileSystemException(
            'Import source size changed or exceeds limit',
          );
        }
        await ImportSafetyPolicy.ensureAvailableCapacity(
          docsDir.path,
          sourceLength,
        );

        // 保存先ディレクトリの決定
        // targetParentPath が指定されている場合はそれを使用 (documents 相対)
        // 指定がない場合はデフォルトの libraryDir を使用
        final targetDir = targetParentPath != null
            ? Directory(
                await _resolveManagedPath(
                  docsDir,
                  targetParentPath,
                  allowedRoots: _libraryRoots,
                ),
              )
            : libraryDir;

        if (!targetDir.existsSync()) {
          await targetDir.create(recursive: true);
        }

        final originalName =
            (sourceFileName != null && sourceFileName.isNotEmpty)
            ? sourceFileName
            : p.basename(file.path);
        final sanitizedOriginalName = originalName.replaceAll(
          RegExp(r'[<>:"/\\|?*]'),
          '_',
        );
        final fallbackExt = p.extension(file.path);
        final ext = p.extension(sanitizedOriginalName).isNotEmpty
            ? p.extension(sanitizedOriginalName)
            : fallbackExt;
        final baseNameRaw = p.basenameWithoutExtension(sanitizedOriginalName);
        final baseName = baseNameRaw.isNotEmpty
            ? baseNameRaw
            : p.basenameWithoutExtension(file.path);

        var candidateName = '$baseName$ext';
        var candidatePath = p.join(targetDir.path, candidateName);
        var suffix = 2;
        late ImportCopyArtifacts artifacts;
        while (true) {
          final candidate = File(candidatePath);
          final reservation = File('$candidatePath.tagshelf-reservation');
          if (!candidate.existsSync()) {
            final relativePath = p.relative(candidatePath, from: docsDir.path);
            artifacts = ImportCopyArtifacts(
              operationId: operationId,
              destinationPath: relativePath,
            );
            // Persist exact paths before the first artifact is created. A stale
            // journal cannot claim an existing reservation owned by another copy.
            await onDestinationPrepared?.call(relativePath);
            try {
              await reservation.create(exclusive: true);
              reservationFile = reservation;
            } on FileSystemException {
              // 同時インポートが同じ名前を予約済み。
              if (!await reservation.exists()) rethrow;
            }
            if (reservationFile != null) {
              await reservation.writeAsString(
                jsonEncode(artifacts.ownership),
                flush: true,
              );
              break;
            }
          }
          candidateName = '${baseName}_$suffix$ext';
          candidatePath = p.join(targetDir.path, candidateName);
          suffix++;
        }

        final relativePath = p.relative(candidatePath, from: docsDir.path);
        partialFile = File(p.join(docsDir.path, artifacts.partialPath));
        await partialFile.create(exclusive: true);
        ownsPartial = true;
        final sink = partialFile.openWrite();
        var copiedBytes = 0;
        try {
          await for (final chunk in file.openRead()) {
            copiedBytes += chunk.length;
            if (copiedBytes > maxBytes ||
                (expectedBytes != null && copiedBytes > expectedBytes)) {
              throw const FileSystemException(
                'Import source exceeds size limit',
              );
            }
            sink.add(chunk);
          }
        } finally {
          await sink.close();
        }
        if (copiedBytes != sourceLength ||
            (expectedBytes != null && copiedBytes != expectedBytes)) {
          throw const FileSystemException('Import source changed during copy');
        }
        if (await FileSystemEntity.type(candidatePath, followLinks: false) !=
            FileSystemEntityType.notFound) {
          throw const FileSystemException(
            'Import destination appeared during copy',
          );
        }
        await partialFile.rename(candidatePath);
        destinationPublished = true;
        // Persist the completed copy before removing its ownership evidence.
        // If persistence fails or the process stops here, recovery can still
        // identify this exact destination from the reservation.
        await onDestinationPublished?.call(relativePath);
        final release = await deleteFile(artifacts.reservationPath);
        if (release.isFailure) throw release.errorOrNull!;
        reservationFile = null;

        return Result.success(relativePath);
      } catch (e, st) {
        final error = _operationError('Failed to import file', e, st);
        if (destinationPublished) {
          // The final file exists but no database row may exist yet. Retain its
          // journal and ownership evidence so recovery can resolve it safely.
          return Result.failure(
            error.withAdditionalData({'importRetryBlocked': true}),
          );
        }
        try {
          if (ownsPartial &&
              partialFile != null &&
              await partialFile.exists()) {
            await partialFile.delete(); // audit: allow-file-io
          }
          if (reservationFile != null && await reservationFile.exists()) {
            await reservationFile.delete(); // audit: allow-file-io
          }
        } catch (_) {
          return Result.failure(
            error.withAdditionalData({'importRetryBlocked': true}),
          );
        }
        return Result.failure(error);
      }
    });
  }

  /// ファイルまたはディレクトリの削除 (アプリ内管理ファイルのみ)
  Future<Result<void, AppError>> deleteFile(String relativePath) async {
    try {
      if (_isManagedRoot(relativePath)) {
        return Result.failure(
          AppError.validation('Managed storage root cannot be deleted'),
        );
      }
      final docsDir = await getPrivateStorageDirectory();
      final fullPath = await _resolveManagedPath(docsDir, relativePath);
      final entity = FileSystemEntity.typeSync(fullPath);

      if (entity == FileSystemEntityType.file) {
        await File(fullPath).delete();
      } else if (entity == FileSystemEntityType.directory) {
        await Directory(fullPath).delete(
          recursive: true, // audit: allow-file-io
        );
      }
      return Result.success(null);
    } catch (e, st) {
      return Result.failure(_operationError('Failed to delete file', e, st));
    }
  }

  Future<Result<void, AppError>> stageDeletion(
    String originalRelativePath,
    String trashRelativePath,
  ) async {
    return _renameManagedEntity(originalRelativePath, trashRelativePath);
  }

  Future<Result<bool, AppError>> managedEntityExists(
    String relativePath,
  ) async {
    try {
      final docsDir = await getPrivateStorageDirectory();
      final resolved = await _resolveManagedPath(docsDir, relativePath);
      return Result.success(
        FileSystemEntity.typeSync(resolved) != FileSystemEntityType.notFound,
      );
    } catch (e, st) {
      return Result.failure(_operationError('Failed to inspect path', e, st));
    }
  }

  Future<Result<List<TrashStagingEntry>, AppError>>
  listTrashStagingEntries() async {
    try {
      final docsDir = await getPrivateStorageDirectory();
      final trashDir = Directory(p.join(docsDir.path, '.trash'));
      if (!await trashDir.exists()) return Result.success(const []);
      final entries = <TrashStagingEntry>[];
      await for (final entity in trashDir.list(followLinks: false)) {
        if (entity is! Directory) continue;
        final stat = await entity.stat();
        entries.add(
          TrashStagingEntry(
            operationId: p.basename(entity.path),
            modifiedAt: stat.modified,
          ),
        );
      }
      return Result.success(entries);
    } catch (e, st) {
      return Result.failure(
        _operationError('Failed to inspect Trash staging', e, st),
      );
    }
  }

  Future<Result<void, AppError>> restoreStagedDeletion(
    String trashRelativePath,
    String originalRelativePath,
  ) async {
    return _renameManagedEntity(trashRelativePath, originalRelativePath);
  }

  Future<Result<void, AppError>> _renameManagedEntity(
    String fromRelativePath,
    String toRelativePath,
  ) async {
    try {
      if (_isManagedRoot(fromRelativePath) || _isManagedRoot(toRelativePath)) {
        return Result.failure(
          AppError.validation('Managed storage root cannot be moved'),
        );
      }
      final docsDir = await getPrivateStorageDirectory();
      final from = await _resolveManagedPath(docsDir, fromRelativePath);
      final to = await _resolveManagedPath(docsDir, toRelativePath);
      final type = FileSystemEntity.typeSync(from);
      if (type == FileSystemEntityType.notFound) {
        return Result.failure(
          AppError.file('Source not found: $fromRelativePath'),
        );
      }
      if (FileSystemEntity.typeSync(to) != FileSystemEntityType.notFound) {
        return Result.failure(
          AppError.validation(
            'Destination already exists: $toRelativePath',
          ).withAdditionalData({'moveStarted': false}),
        );
      }
      await Directory(p.dirname(to)).create(recursive: true);
      if (type == FileSystemEntityType.file) {
        await _safeMoveFile(File(from), to);
      } else if (type == FileSystemEntityType.directory) {
        await _safeMoveDirectory(Directory(from), to);
      } else {
        return Result.failure(AppError.file('Unsupported file system entity'));
      }
      return Result.success(null);
    } catch (e, st) {
      return Result.failure(_operationError('Failed to stage file', e, st));
    }
  }

  /// ファイルまたはディレクトリを移動する (アプリ内管理ファイルのみ)
  Future<Result<void, AppError>> moveEntity(
    String oldRelativePath,
    String newRelativePath,
  ) async {
    try {
      if (_isManagedRoot(oldRelativePath) || _isManagedRoot(newRelativePath)) {
        return Result.failure(
          AppError.validation('Managed storage root cannot be moved'),
        );
      }
      final docsDir = await getPrivateStorageDirectory();
      final oldFullPath = await _resolveManagedPath(
        docsDir,
        oldRelativePath,
        allowedRoots: _libraryRoots,
      );
      final newFullPath = await _resolveManagedPath(
        docsDir,
        newRelativePath,
        allowedRoots: _libraryRoots,
      );

      final entity = FileSystemEntity.typeSync(oldFullPath);
      if (entity == FileSystemEntityType.notFound) {
        return Result.failure(
          AppError.file('Source not found: $oldRelativePath'),
        );
      }
      if (FileSystemEntity.typeSync(newFullPath) !=
          FileSystemEntityType.notFound) {
        return Result.failure(
          AppError.validation('Destination already exists: $newRelativePath'),
        );
      }

      // 移動先の親ディレクトリの存在確認
      final newDir = Directory(p.dirname(newFullPath));
      if (!newDir.existsSync()) {
        await newDir.create(recursive: true);
      }

      if (entity == FileSystemEntityType.file) {
        await _safeMoveFile(File(oldFullPath), newFullPath);
      } else if (entity == FileSystemEntityType.directory) {
        await _safeMoveDirectory(Directory(oldFullPath), newFullPath);
      }

      return Result.success(null);
    } catch (e, st) {
      return Result.failure(_operationError('Failed to move entity', e, st));
    }
  }

  /// クロスデバイス移動（EXDEV）にも安全に対応したファイル移動
  Future<void> _safeMoveFile(File source, String destinationPath) async {
    try {
      await source.rename(destinationPath);
    } on FileSystemException {
      // 別ボリュームや一時ディレクトリ等で EXDEV (Cross-device link) が発生した場合のフォールバック
      await source.copy(destinationPath);
      await source.delete();
    }
  }

  /// クロスデバイス移動（EXDEV）にも安全に対応したディレクトリ移動
  Future<void> _safeMoveDirectory(
    Directory source,
    String destinationPath,
  ) async {
    try {
      await source.rename(destinationPath);
    } on FileSystemException {
      await _copyDirectory(source, Directory(destinationPath));
      await source.delete(recursive: true); // audit: allow-file-io
    }
  }

  /// ファイルまたはディレクトリをコピーする (アプリ内管理ファイルのみ)
  Future<Result<void, AppError>> copyEntity(
    String oldRelativePath,
    String newRelativePath,
  ) async {
    try {
      if (_isManagedRoot(oldRelativePath) || _isManagedRoot(newRelativePath)) {
        return Result.failure(
          AppError.validation('Managed storage root cannot be copied'),
        );
      }
      final docsDir = await getPrivateStorageDirectory();
      final oldFullPath = await _resolveManagedPath(
        docsDir,
        oldRelativePath,
        allowedRoots: _managedRoots,
      );
      final newFullPath = await _resolveManagedPath(
        docsDir,
        newRelativePath,
        allowedRoots: _managedRoots,
      );

      final entity = FileSystemEntity.typeSync(oldFullPath);
      if (entity == FileSystemEntityType.notFound) {
        return Result.failure(
          AppError.file('Source not found: $oldRelativePath'),
        );
      }
      if (FileSystemEntity.typeSync(newFullPath) !=
          FileSystemEntityType.notFound) {
        return Result.failure(
          AppError.validation('Destination already exists: $newRelativePath'),
        );
      }

      // コピー先の親ディレクトリの存在確認
      final newDir = Directory(p.dirname(newFullPath));
      if (!newDir.existsSync()) {
        await newDir.create(recursive: true);
      }

      if (entity == FileSystemEntityType.file) {
        await File(oldFullPath).copy(newFullPath);
      } else if (entity == FileSystemEntityType.directory) {
        await _copyDirectory(Directory(oldFullPath), Directory(newFullPath));
      }

      return Result.success(null);
    } catch (e, st) {
      return Result.failure(_operationError('Failed to copy entity', e, st));
    }
  }

  /// ディレクトリを再帰的にコピーする
  Future<void> _copyDirectory(Directory source, Directory destination) async {
    if (!destination.existsSync()) {
      await destination.create(recursive: true);
    }

    await for (final entity in source.list(recursive: false)) {
      final newPath = p.join(destination.path, p.basename(entity.path));
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      } else if (entity is File) {
        await entity.copy(newPath);
      }
    }
  }
}
