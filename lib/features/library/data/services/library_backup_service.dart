import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart' hide Collection;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../../core/providers/isar_provider.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/logger/log_tag.dart';
import '../../../../core/services/local_storage_manager.dart';
import '../../../../core/services/private_storage_service.dart';
import '../../../../core/services/storage_operation_gate.dart';
import '../../../../core/services/storage_sandbox.dart';
import '../../domain/models/library_backup.dart';
import '../../domain/models/media_item.dart';
import '../../domain/models/collection.dart';
import 'library_backup_archive.dart';
import 'library_backup_database.dart';
import 'library_backup_workspace.dart';

final libraryBackupServiceProvider = FutureProvider<LibraryBackupService>((
  ref,
) async {
  return LibraryBackupService(
    await ref.watch(isarProvider.future),
    await ref.watch(localStorageManagerProvider).getPrivateRootDirectory(),
  );
});

/// Explicit portable backup. Export is read-only; restore adds new identities,
/// and never replaces existing files or existing user edits.
class LibraryBackupService {
  LibraryBackupService(this.isar, this.root, {this.beforeRestoreCommit});
  final Isar isar;
  final Directory root;
  final Future<void> Function()? beforeRestoreCommit;

  Future<Directory> _workspace() async {
    final parent = Directory(p.join(root.path, '.backup-work'));
    await StorageSandbox.rejectSymbolicLinkAncestors(root.path, parent.path);
    await parent.create(recursive: true);
    await PrivateStorageService.enforceBackupExclusion(parent);
    return parent.createTemp('work-');
  }

  /// The returned completed private archive belongs to a disposable workspace.
  /// Call [disposeExport] after destination selection/copy, including cancel.
  Future<File> createBackup({
    LibraryBackupCancellation? cancellation,
    void Function(int completed, int total)? onProgress,
  }) => StorageOperationGate.maintenance(() async {
    await _recoverInterruptedRestores();
    final workspace = await _workspace();
    try {
      cancellation?.check();
      final document = await LibraryBackupDatabase(isar).snapshot();
      return await LibraryBackupArchive.write(
        root: root,
        workspace: workspace,
        document: document,
        cancellation: cancellation,
        onProgress: onProgress,
      );
    } catch (_) {
      await LibraryBackupWorkspace.removeStaging(root, workspace);
      rethrow;
    }
  });

  Future<void> disposeExport(File archive) async {
    final parent = p.join(root.path, '.backup-work');
    if (!p.isWithin(parent, archive.parent.path)) {
      throw const FileSystemException('Invalid backup workspace');
    }
    if (await archive.parent.exists()) {
      await LibraryBackupWorkspace.removeStaging(root, archive.parent);
    }
  }

  /// Validate and freeze the selected backup before presenting its summary.
  /// This does not write library files or database records.
  Future<PreparedLibraryBackup> prepareRestore(
    File source, {
    LibraryBackupCancellation? cancellation,
    void Function(int completed, int total)? onProgress,
  }) async {
    final workspace = await _workspace();
    try {
      final document = await LibraryBackupArchive.verify(
        source,
        extractTo: workspace,
        cancellation: cancellation,
        onProgress: onProgress,
      );
      final files = (document['files'] as List).cast<Map<String, dynamic>>();
      return PreparedLibraryBackup(
        directory: workspace,
        document: document,
        createdAt: LibraryBackupArchive.date(document, 'createdAt'),
        fileCount: (document['items'] as List)
            .where(
              (item) => item['type'] == 'file' && item['isMissing'] != true,
            )
            .length,
        disposeStaging: () =>
            LibraryBackupWorkspace.removeStaging(root, workspace),
        totalBytes: files.fold(
          0,
          (sum, record) => sum + (record['size'] as int),
        ),
      );
    } catch (_) {
      await LibraryBackupWorkspace.removeStaging(root, workspace);
      rethrow;
    }
  }

  /// Called only after the restore preview is explicitly confirmed.
  Future<LibraryRestoreResult> restore(
    PreparedLibraryBackup prepared, {
    LibraryBackupCancellation? cancellation,
    String? folderName,
  }) => StorageOperationGate.maintenance(() async {
    final workspaceParent = p.join(root.path, '.backup-work');
    if (!p.isWithin(workspaceParent, prepared.directory.path)) {
      throw const FileSystemException('Invalid restore workspace');
    }
    await _recoverInterruptedRestores();
    cancellation?.check();
    LibraryBackupArchive.validateDocument(prepared.document);
    await _verifyPreparedFiles(prepared, cancellation);
    final existingItems = {
      for (final item in await isar.mediaItems.where().findAll())
        LibraryBackupDatabase.identity(item.uid, 'item', item.path): item,
    };
    final existingCollections = {
      for (final collection in await isar.mediaCollections.where().findAll())
        LibraryBackupDatabase.identity(
          collection.uid,
          'collection',
          collection.path,
        ): collection,
    };
    final existingItemUids = existingItems.keys.toSet();
    final existingCollectionUids = existingCollections.keys.toSet();
    final hasNewItems = (prepared.document['items'] as List).any(
      (record) => !existingItemUids.contains(record['uid']),
    );
    final hasNewCollections = (prepared.document['collections'] as List).any(
      (record) => !existingCollectionUids.contains(record['uid']),
    );
    if (!hasNewItems && !hasNewCollections) {
      var committed = false;
      try {
        final result = await LibraryBackupDatabase(isar).merge(
          prepared.document,
          (path) => path,
          beforeCommit: () async {
            cancellation?.check();
            await beforeRestoreCommit?.call();
            cancellation?.check();
          },
        );
        committed = true;
        return await _finishCommittedRestore(result, prepared);
      } finally {
        if (!committed) await prepared.dispose();
      }
    }
    final records = (prepared.document['items'] as List)
        .cast<Map<String, dynamic>>();
    final neededFolders = <String>{};
    final sourceItemsByPath = {
      for (final record in records) record['path']: record,
    };
    final pathOverrides = <String, String>{};
    for (final record in records) {
      final existing = existingItems[record['uid']];
      if (existing != null && existing.type == MediaType.file) {
        if (existing.sourceType != MediaSourceType.localCopy) {
          throw const FormatException(
            'External references must be copied into the library before restore',
          );
        }
        pathOverrides[record['path'] as String] = existing.path;
        if (record['isTrashed'] == true) {
          final sourceRoot = sourceItemsByPath[record['trashRootPath']];
          final sourceTrash = sourceRoot?['trashPath'] as String?;
          if (sourceTrash != null) {
            final rootPath = sourceRoot!['path'] as String;
            final originalPath = record['path'] as String;
            final suffix = originalPath == rootPath
                ? ''
                : originalPath.substring(rootPath.length + 1);
            pathOverrides[suffix.isEmpty
                    ? sourceTrash
                    : '$sourceTrash/$suffix'] =
                existing.trashPath ?? existing.path;
          }
        }
        if (record['thumbnailPath'] is String &&
            existing.thumbnailPath != null) {
          pathOverrides[record['thumbnailPath'] as String] =
              existing.thumbnailPath!;
        }
      }
      if (existing == null) {
        if (record['type'] == 'folder' && record['isTrashed'] != true) {
          neededFolders.add(record['path'] as String);
        }
        var parent = record['parentPath'] as String?;
        final visited = <String>{};
        while (parent != null && parent != 'library' && parent != 'folders') {
          cancellation?.check();
          if (!visited.add(parent)) {
            throw const FormatException('Invalid file hierarchy');
          }
          neededFolders.add(parent);
          parent = sourceItemsByPath[parent]!['parentPath'] as String?;
        }
      }
    }
    for (final record
        in (prepared.document['collections'] as List)
            .cast<Map<String, dynamic>>()) {
      final existing = existingCollections[record['uid']];
      if (existing != null &&
          record['coverImagePath'] is String &&
          existing.coverImagePath != null) {
        pathOverrides.putIfAbsent(
          record['coverImagePath'] as String,
          () => existing.coverImagePath!,
        );
      }
      if (existing == null &&
          record['type'] == 'folder' &&
          record['isTrashed'] != true) {
        neededFolders.add(record['path'] as String);
      }
    }
    // A skipped UID must not leave a physical duplicate that a later scan can
    // rediscover. Reuse its current file/cache path and keep existing edits.
    for (final record
        in (prepared.document['files'] as List).cast<Map<String, dynamic>>()) {
      if (pathOverrides.containsKey(record['path'])) {
        await File(
          LibraryBackupArchive.safePath(
            prepared.directory,
            record['path'] as String,
          ),
        ).delete();
      }
    }
    final stagedDirectories = <Directory>[
      await for (final entity in prepared.directory.list(
        recursive: true,
        followLinks: false,
      ))
        if (entity is Directory) entity,
    ]..sort((a, b) => b.path.length.compareTo(a.path.length));
    for (final directory in stagedDirectories) {
      final relative = p.posix.joinAll(
        p.split(p.relative(directory.path, from: prepared.directory.path)),
      );
      if (!neededFolders.contains(relative) &&
          await directory.list(followLinks: false).isEmpty) {
        await directory.delete();
      }
    }
    // Empty folders have no file records in the streaming container. Recreate
    // their validated paths in staging before publishing the namespace.
    for (final record
        in (prepared.document['items'] as List).cast<Map<String, dynamic>>()) {
      if (!existingItemUids.contains(record['uid'])) {
        await Directory(
          p.join(
            prepared.directory.path,
            (record['path'] as String).split('/').first,
          ),
        ).create(recursive: true);
      }
      if (record['type'] == 'folder' &&
          record['isTrashed'] == true &&
          record['isMissing'] != true &&
          !existingItemUids.contains(record['uid'])) {
        final actual = LibraryBackupArchive.trashLocation(
          record,
          sourceItemsByPath,
        );
        await Directory(
          LibraryBackupArchive.safePath(prepared.directory, actual),
        ).create(recursive: true);
      }
      if (record['type'] == 'folder' &&
          record['isTrashed'] != true &&
          neededFolders.contains(record['path'])) {
        await Directory(
          LibraryBackupArchive.safePath(
            prepared.directory,
            record['path'] as String,
          ),
        ).create(recursive: true);
      }
    }
    for (final record
        in (prepared.document['collections'] as List)
            .cast<Map<String, dynamic>>()) {
      if (record['type'] == 'folder' &&
          record['isTrashed'] != true &&
          neededFolders.contains(record['path'])) {
        await Directory(
          LibraryBackupArchive.safePath(
            prepared.directory,
            record['path'] as String,
          ),
        ).create(recursive: true);
      }
    }
    final namespace = 'restored-${const Uuid().v4()}';
    final journal = File(p.join(workspaceParent, '$namespace.json'));
    await journal.writeAsString(
      jsonEncode({'namespace': namespace}),
      flush: true,
    );
    final published = <Directory>[];
    var committed = false;
    try {
      for (final topLevel in LibraryBackupArchive.roots) {
        cancellation?.check();
        final source = Directory(p.join(prepared.directory.path, topLevel));
        if (!await source.exists()) continue;
        final destination = Directory(p.join(root.path, topLevel, namespace));
        await StorageSandbox.rejectSymbolicLinkAncestors(
          root.path,
          destination.path,
        );
        if (await destination.exists()) {
          throw const FileSystemException('Restore destination already exists');
        }
        await destination.parent.create(recursive: true);
        await source.rename(destination.path);
        published.add(destination);
      }
      String remap(String path) {
        LibraryBackupArchive.safePath(root, path);
        if (pathOverrides.containsKey(path)) return pathOverrides[path]!;
        final segments = path.split('/');
        return p.posix.joinAll([
          segments.first,
          namespace,
          ...segments.skip(1),
        ]);
      }

      cancellation?.check();
      final result = await LibraryBackupDatabase(isar).merge(
        prepared.document,
        remap,
        contextFolderPaths: neededFolders,
        restoreContainers: {
          for (final directory in published)
            if (p.basename(directory.parent.path) == 'library' ||
                p.basename(directory.parent.path) == 'folders')
              p.posix.join(p.basename(directory.parent.path), namespace):
                  folderName ??
                  'Restored ${prepared.createdAt.toIso8601String().substring(0, 10)}',
        },
        beforeCommit: () async {
          cancellation?.check();
          await beforeRestoreCommit?.call();
          cancellation?.check();
        },
      );
      committed = true;
      return await _finishCommittedRestore(result, prepared, journal: journal);
    } finally {
      if (!committed) {
        // Only this attempt's newly published namespace is ever removed.
        for (final directory in published) {
          await LibraryBackupWorkspace.removePublished(
            root,
            directory,
            journal: journal,
          );
        }
        if (await journal.exists()) await journal.delete();
        await prepared.dispose();
      }
    }
  });

  /// A committed library remains usable even if temporary cleanup fails.
  /// Keep that outcome distinct from a transaction that must be retried.
  Future<LibraryRestoreResult> _finishCommittedRestore(
    LibraryRestoreResult result,
    PreparedLibraryBackup prepared, {
    File? journal,
  }) async {
    var cleanupIncomplete = false;
    try {
      if (journal != null && await journal.exists()) await journal.delete();
    } catch (error, stack) {
      cleanupIncomplete = true;
      AppLogger.w(
        LogTag.storage,
        'Committed restore journal cleanup failed',
        error,
        stack,
      );
    }
    try {
      await prepared.dispose();
    } catch (error, stack) {
      cleanupIncomplete = true;
      AppLogger.w(
        LogTag.storage,
        'Committed restore staging cleanup failed',
        error,
        stack,
      );
    }
    return LibraryRestoreResult(
      addedItems: result.addedItems,
      skippedItems: result.skippedItems,
      cleanupIncomplete: cleanupIncomplete,
    );
  }

  Future<void> _verifyPreparedFiles(
    PreparedLibraryBackup prepared,
    LibraryBackupCancellation? cancellation,
  ) async {
    final expected = <String>{};
    for (final record
        in (prepared.document['files'] as List).cast<Map<String, dynamic>>()) {
      cancellation?.check();
      final relative = record['path'] as String;
      expected.add(relative);
      final file = File(
        LibraryBackupArchive.safePath(prepared.directory, relative),
      );
      await StorageSandbox.rejectSymbolicLinkAncestors(
        prepared.directory.path,
        file.path,
      );
      if (!await file.exists() ||
          await file.length() != record['size'] ||
          await LibraryBackupArchive.hashFile(
                file,
                cancellation: cancellation,
              ) !=
              record['sha256']) {
        throw const FormatException('Prepared backup changed; select it again');
      }
    }
    await for (final entity in prepared.directory.list(
      recursive: true,
      followLinks: false,
    )) {
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type == FileSystemEntityType.link) {
        throw const FormatException('Invalid prepared backup');
      }
      if (type == FileSystemEntityType.file &&
          !expected.contains(
            p.posix.joinAll(
              p.split(p.relative(entity.path, from: prepared.directory.path)),
            ),
          )) {
        throw const FormatException('Unexpected file in prepared backup');
      }
    }
  }

  Future<void> _recoverInterruptedRestores() async {
    final work = Directory(p.join(root.path, '.backup-work'));
    if (!await work.exists()) return;
    await StorageSandbox.rejectSymbolicLinkAncestors(root.path, work.path);
    final committedPaths = [
      for (final item in await isar.mediaItems.where().findAll()) ...[
        item.path,
        if (item.thumbnailPath != null) item.thumbnailPath!,
        if (item.trashPath != null) item.trashPath!,
      ],
      for (final collection
          in await isar.mediaCollections.where().findAll()) ...[
        collection.path,
        if (collection.coverImagePath != null) collection.coverImagePath!,
      ],
    ];
    await for (final entity in work.list(followLinks: false)) {
      if (entity is! File ||
          !RegExp(
            r'^restored-[0-9a-f-]{36}\.json$',
          ).hasMatch(p.basename(entity.path))) {
        continue;
      }
      final namespace = p.basenameWithoutExtension(entity.path);
      final isCommitted = committedPaths.any(
        (path) => path.split('/').length > 1 && path.split('/')[1] == namespace,
      );
      if (!isCommitted) {
        for (final topLevel in LibraryBackupArchive.roots) {
          final directory = Directory(p.join(root.path, topLevel, namespace));
          await StorageSandbox.rejectSymbolicLinkAncestors(
            root.path,
            directory.path,
          );
          await LibraryBackupWorkspace.removePublished(
            root,
            directory,
            journal: entity,
          );
        }
      }
      await entity.delete();
    }
    // Abandoned export/preview workspaces contain no published library data.
    final threshold = DateTime.now().subtract(const Duration(days: 1));
    await for (final entity in work.list(followLinks: false)) {
      if (entity is Directory &&
          p.basename(entity.path).startsWith('work-') &&
          (await entity.stat()).modified.isBefore(threshold)) {
        await LibraryBackupWorkspace.removeStaging(root, entity);
      }
    }
  }
}
