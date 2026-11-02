import 'dart:io';

/// A validated private staging area. Nothing is imported until [restore] is
/// explicitly requested by the user. Dispose it after cancel, failure or success.
class PreparedLibraryBackup {
  PreparedLibraryBackup({
    required this.directory,
    required this.document,
    required this.createdAt,
    required this.fileCount,
    required this.totalBytes,
    required this._disposeStaging,
  });

  final Directory directory;
  final Map<String, dynamic> document;
  final DateTime createdAt;
  final int fileCount;
  final int totalBytes;
  final Future<void> Function() _disposeStaging;

  int get itemCount => (document['items'] as List).length;
  int get collectionCount => (document['collections'] as List).length;
  int get tagCount => (document['tags'] as List).length;

  Future<void> dispose() => _disposeStaging();
}

class LibraryBackupCancellation {
  bool isCancelled = false;

  void check() {
    if (isCancelled) throw const LibraryBackupCancelled();
  }
}

class LibraryBackupCancelled implements Exception {
  const LibraryBackupCancelled();
}

class LibraryRestoreResult {
  const LibraryRestoreResult({
    required this.addedItems,
    required this.skippedItems,
    this.cleanupIncomplete = false,
  });

  final int addedItems;
  final int skippedItems;
  final bool cleanupIncomplete;
}
