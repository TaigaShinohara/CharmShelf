import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_storage/shared_storage.dart' as saf;
import 'package:uuid/uuid.dart';

import 'external_storage_service.dart';

/// Copies only a completed private artifact. The final backup name is published
/// after a successful stream copy; existing user files are never selected as
/// output, and failure cleanup touches only the new random partial created here.
abstract final class LibraryBackupDestination {
  static Future<void> save({
    required File archive,
    required Uri folder,
    required String fileName,
    ExternalStorageService? externalStorage,
    bool? isAndroid,
  }) async {
    if (p.basename(fileName) != fileName || !fileName.endsWith('.tagshelf')) {
      throw const FileSystemException('Invalid backup name');
    }
    final partialName = '.tagshelf-${const Uuid().v4()}.part';
    if (isAndroid ?? Platform.isAndroid) {
      final storage = externalStorage;
      if (storage == null) {
        throw const FileSystemException('No backup destination access');
      }
      final parent = await saf.DocumentFile.fromTreeUri(folder);
      if (parent == null ||
          await parent.findFile(fileName) != null ||
          await parent.findFile(partialName) != null) {
        throw const FileSystemException(
          'Backup destination already exists or is unavailable',
        );
      }
      Uri? partial;
      var published = false;
      try {
        partial = await storage.createFile(
          folder,
          partialName,
          'application/octet-stream',
        );
        if (partial == null || !await storage.copyFileToUri(archive, partial)) {
          throw const FileSystemException('Backup destination copy failed');
        }
        if (await parent.findFile(fileName) != null) {
          throw const FileSystemException('Backup destination already exists');
        }
        final renamed = await saf.renameTo(partial, fileName);
        if (renamed != null) partial = renamed.uri;
        if (renamed == null || renamed.name != fileName) {
          throw const FileSystemException('Backup could not be published');
        }
        published = true;
      } finally {
        if (!published && partial != null) await saf.delete(partial);
      }
      return;
    }
    if (!folder.isScheme('file')) {
      throw const FileSystemException('Invalid backup destination');
    }
    final directory = Directory(folder.toFilePath());
    final destination = File(p.join(directory.path, fileName));
    final partial = File(p.join(directory.path, partialName));
    if (await destination.exists() || await partial.exists()) {
      throw const FileSystemException('Backup destination already exists');
    }
    var published = false;
    try {
      await archive.openRead().pipe(partial.openWrite());
      if (await partial.length() != await archive.length()) {
        throw const FileSystemException('Backup copy is incomplete');
      }
      if (await destination.exists()) {
        throw const FileSystemException('Backup destination already exists');
      }
      await partial.rename(destination.path);
      published = true;
    } finally {
      if (!published && await partial.exists()) await partial.delete();
    }
  }
}
