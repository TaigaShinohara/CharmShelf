import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../../core/services/storage_sandbox.dart';
import 'library_backup_archive.dart';

/// The sole recursive-delete boundary for portable backup work. It accepts only
/// private temporary workspaces or this restore journal's newly created path.
abstract final class LibraryBackupWorkspace {
  static Future<void> removeStaging(Directory root, Directory directory) async {
    final relative = p.relative(
      directory.absolute.path,
      from: root.absolute.path,
    );
    final parts = p.split(relative);
    if (parts.length != 2 ||
        parts.first != '.backup-work' ||
        !RegExp(r'^work-[a-zA-Z0-9]+$').hasMatch(parts.last)) {
      throw const FileSystemException('Invalid backup staging cleanup path');
    }
    await _remove(root, directory);
  }

  static Future<void> removePublished(
    Directory root,
    Directory directory, {
    required File journal,
  }) async {
    final relative = p.relative(
      directory.absolute.path,
      from: root.absolute.path,
    );
    final parts = p.split(relative);
    if (parts.length != 2 ||
        !LibraryBackupArchive.roots.contains(parts.first) ||
        !RegExp(r'^restored-[0-9a-f-]{36}$').hasMatch(parts.last) ||
        p.normalize(journal.absolute.path) !=
            p.normalize(
              p.join(root.absolute.path, '.backup-work', '${parts.last}.json'),
            )) {
      throw const FileSystemException('Invalid restore cleanup path');
    }
    await StorageSandbox.rejectSymbolicLinkAncestors(root.path, journal.path);
    if (!await journal.exists() || await journal.length() > 1024) {
      throw const FileSystemException('Restore cleanup journal is missing');
    }
    final decoded = jsonDecode(await journal.readAsString());
    if (decoded is! Map || decoded['namespace'] != parts.last) {
      throw const FileSystemException('Invalid restore cleanup journal');
    }
    await _remove(root, directory);
  }

  static Future<void> _remove(Directory root, Directory directory) async {
    await StorageSandbox.rejectSymbolicLinkAncestors(root.path, directory.path);
    if (await directory.exists()) {
      await directory.delete(recursive: true); // audit: allow-file-io
    }
  }
}
