import 'package:private_shelf/core/services/storage_operation_gate.dart';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'package:private_shelf/core/services/import_safety_policy.dart';
import 'package:private_shelf/features/library/domain/models/media_format_utils.dart';

/// Only local Documents/CharmShelf is supported. The native side verifies document
/// identities, propagates listing failures and never recursively deletes a tree.
abstract interface class LegacyStorage {
  Future<List<LegacyEntry>> scan(Uri tree);
  Future<void> copy(Uri tree, LegacyEntry entry, File destination);
  Future<void> deleteFile(Uri tree, LegacyEntry entry);
}

class AndroidLegacyStorage implements LegacyStorage {
  static const _channel = MethodChannel('com.tsmusic.privateshelf/legacy');
  @override
  Future<List<LegacyEntry>> scan(Uri tree) async {
    final rows = await _channel.invokeListMethod<dynamic>('scan', {
      'tree': tree.toString(),
    });
    if (rows == null) throw StateError('Cannot inspect legacy folder');
    return rows
        .map(
          (row) => LegacyEntry.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  @override
  Future<void> copy(Uri tree, LegacyEntry entry, File destination) async {
    final ok = await _channel.invokeMethod<bool>('copy', {
      'tree': tree.toString(),
      'path': entry.path,
      'hash': entry.hash,
      'destination': destination.path,
    });
    if (ok != true) throw StateError('Copy failed');
  }

  @override
  Future<void> deleteFile(Uri tree, LegacyEntry entry) async {
    final ok = await _channel.invokeMethod<bool>('deleteFile', {
      'tree': tree.toString(),
      'path': entry.path,
      'hash': entry.hash,
    });
    if (ok != true) throw StateError('Delete failed');
  }
}

class LegacyEntry {
  LegacyEntry({
    required this.path,
    required this.directory,
    required this.size,
    required this.hash,
  }) {
    final parts = path.split('/');
    if (p.isAbsolute(path) ||
        parts.length > 64 ||
        parts.any(
          (part) =>
              part.isEmpty ||
              part == '.' ||
              part == '..' ||
              part.contains('\\'),
        ) ||
        size < 0 ||
        (!directory && !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash))) {
      throw const FormatException('Invalid legacy entry');
    }
  }
  factory LegacyEntry.fromJson(Map<String, dynamic> json) => LegacyEntry(
    path: json['path'] as String,
    directory: json['directory'] as bool,
    size: json['size'] as int,
    hash: json['hash'] as String,
  );
  final String path;
  final bool directory;
  final int size;
  final String hash;
  Map<String, dynamic> toJson() => {
    'path': path,
    'directory': directory,
    'size': size,
    'hash': hash,
  };
}

enum LegacyIssue {
  wrongFolder,
  unknownFiles,
  sourceChanged,
  unsupportedFiles,
  invalidMetadata,
  linkedFolder,
}

class LegacyMigrationException implements Exception {
  const LegacyMigrationException(this.issue);
  final LegacyIssue issue;
}

enum LegacyOutcome { notFound, restored, deleted }

enum LegacyPhase { choice, restoring, importing, deleting, complete }

class LegacyMigrationRecord {
  LegacyMigrationRecord({
    required this.id,
    required this.tree,
    required this.entries,
    this.phase = LegacyPhase.choice,
    this.restored = false,
    this.outcome,
  });
  final String id;
  final Uri tree;
  final List<LegacyEntry> entries;
  LegacyPhase phase;
  bool restored;
  final LegacyOutcome? outcome;
  bool get requiresRecovery =>
      phase != LegacyPhase.choice && phase != LegacyPhase.complete;
  LegacyOutcome get completedOutcome =>
      outcome ??
      (fileCount == 0
          ? LegacyOutcome.notFound
          : restored
          ? LegacyOutcome.restored
          : LegacyOutcome.deleted);
  int get fileCount => entries.where((e) => !e.directory).length;
  int get bytes => entries.fold(0, (sum, e) => sum + e.size);
}

/// The journal is the completion authority. No old preference is consent.
/// All operations are serialized, and every destructive resume checks the
/// original manifest. A partial delete can only continue the same decision.
class LegacyMigrationService {
  LegacyMigrationService({
    required this.root,
    required this.storage,
    required this.restorePrepared,
    required this.checkReferences,
    this.verifyDatabase,
    this.restoredCatalogTitle = 'Restored CharmShelf',
  });
  final String restoredCatalogTitle;
  final Directory root;
  final LegacyStorage storage;
  final Future<void> Function(Directory prepared) restorePrepared;
  final Future<void> Function(Uri tree) checkReferences;
  final Future<void> Function(List<String> paths)? verifyDatabase;
  bool _busy = false;
  void Function(LegacyPhase phase, int completed, int total)? onProgress;
  File get _journal =>
      File(p.join(root.path, '.tagshelf', 'legacy-migration-v1.json'));
  Directory _stage(LegacyMigrationRecord record) =>
      Directory(p.join(root.path, '.tagshelf', 'legacy-${record.id}'));

  Future<LegacyMigrationRecord?> load() async {
    if (!await _journal.exists()) return null;
    final json =
        jsonDecode(await _journal.readAsString()) as Map<String, dynamic>;
    if (json['version'] != 1 ||
        !RegExp(r'^[0-9]+$').hasMatch(json['id'] as String)) {
      throw const FormatException('Invalid migration journal');
    }
    final tree = Uri.parse(json['tree'] as String);
    _validateTree(tree);
    final entries = (json['entries'] as List)
        .map((e) => LegacyEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    _validateEntries(entries);
    final record = LegacyMigrationRecord(
      id: json['id'] as String,
      tree: tree,
      entries: entries,
      phase: LegacyPhase.values.byName(json['phase'] as String),
      restored: json['restored'] as bool,
      outcome: json['outcome'] == null
          ? null
          : LegacyOutcome.values.byName(json['outcome'] as String),
    );
    return record;
  }

  Future<void> _save(LegacyMigrationRecord record) async {
    await _journal.parent.create(recursive: true);
    final temp = File('${_journal.path}.pending');
    await temp.writeAsString(
      jsonEncode({
        'version': 1,
        'id': record.id,
        'tree': record.tree.toString(),
        'phase': record.phase.name,
        'restored': record.restored,
        if (record.phase == LegacyPhase.complete)
          'outcome': record.completedOutcome.name,
        'entries': record.entries.map((e) => e.toJson()).toList(),
      }),
      flush: true,
    );
    await temp.rename(_journal.path);
  }

  static void _validateTree(Uri tree) {
    if (tree.scheme != 'content' ||
        tree.authority != 'com.android.externalstorage.documents' ||
        tree.pathSegments.length != 2 ||
        tree.pathSegments[0] != 'tree' ||
        tree.pathSegments[1] != 'primary:Documents') {
      throw const LegacyMigrationException(LegacyIssue.wrongFolder);
    }
  }

  static void _validateEntries(List<LegacyEntry> entries) {
    if (entries.length > ImportSafetyPolicy.maxScannedEntryCount ||
        entries.map((e) => e.path).toSet().length != entries.length) {
      throw const FormatException('Invalid legacy inventory');
    }
    const roots = {'library', 'folders', '.tagshelf', 'covers', '.thumbnails'};
    for (final entry in entries) {
      if (!roots.contains(entry.path.split('/').first)) {
        throw const LegacyMigrationException(LegacyIssue.unknownFiles);
      }
    }
    if (entries.fold<int>(0, (n, e) => n + e.size) >
        ImportSafetyPolicy.maxTotalBytes) {
      throw const FormatException('Legacy data too large');
    }
  }

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    if (_busy) throw StateError('Migration already running');
    _busy = true;
    try {
      return await StorageOperationGate.maintenance(action);
    } finally {
      _busy = false;
    }
  }

  /// A read-only, full-access check may complete only a never-started migration.
  /// Existing decisions and in-progress journals must always be recovered normally.
  Future<LegacyMigrationRecord?> completeIfNoLegacyData(
    Future<bool> Function() inspectEmpty,
  ) => _exclusive(() async {
    final previous = await load();
    if (previous != null) return previous;
    if (!await inspectEmpty()) return null;
    final record = LegacyMigrationRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      tree: Uri.parse(
        'content://com.android.externalstorage.documents/tree/primary%3ADocuments',
      ),
      entries: const [],
      phase: LegacyPhase.complete,
    );
    await _save(record);
    return record;
  });

  Future<LegacyMigrationRecord> inspect(Uri tree) => _exclusive(() async {
    _validateTree(tree);
    final previous = await load();
    if (previous?.requiresRecovery == true) {
      throw StateError('Resume the existing operation before inspecting again');
    }
    if (previous?.phase == LegacyPhase.complete) {
      await _cleanup(previous!);
      // Keep the completed decision when a later inspection starts a new one.
      final history = File(
        p.join(root.path, '.tagshelf', 'legacy-history', '${previous.id}.json'),
      );
      await history.parent.create(recursive: true);
      await _journal.copy(history.path);
    }
    final entries = await storage.scan(tree);
    _validateEntries(entries);
    if (entries.any((entry) => !entry.directory)) await checkReferences(tree);
    final record = LegacyMigrationRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      tree: tree,
      entries: entries,
    );
    if (record.fileCount == 0) record.phase = LegacyPhase.complete;
    await _save(record);
    if (previous != null) await _cleanup(previous);
    return record;
  });

  Future<void> finishCleanup() => _exclusive(() async {
    final record = await load();
    if (record?.phase == LegacyPhase.complete) await _cleanup(record!);
  });

  /// Refresh only the permission. Never replace an in-progress manifest.
  Future<void> reconnect(Uri tree) => _exclusive(() async {
    _validateTree(tree);
    final record = await load();
    if (record == null || !record.requiresRecovery) {
      throw StateError('No operation to resume');
    }
    _checkUnchanged(
      record,
      await storage.scan(tree),
      allowMissing: record.phase == LegacyPhase.deleting,
    );
  });

  /// restore=false is only called after the destructive confirmation dialog.
  Future<LegacyMigrationRecord> execute({required bool restore}) =>
      _exclusive(() async {
        try {
          return await _execute(restore: restore);
        } finally {
          // An unreadable journal must never unlock normal storage work.
          StorageOperationGate.recoveryRequired = true;
          StorageOperationGate.recoveryRequired =
              (await load())?.requiresRecovery ?? false;
        }
      });

  Future<LegacyMigrationRecord> _execute({required bool restore}) async {
    final record = await load();
    if (record == null) throw StateError('Inspect before deciding');
    if (record.phase == LegacyPhase.complete) {
      await _cleanup(record);
      return record;
    }
    if (record.requiresRecovery &&
        restore !=
            (record.restored ||
                record.phase == LegacyPhase.restoring ||
                record.phase == LegacyPhase.importing)) {
      throw StateError('An active migration decision cannot be changed');
    }
    await checkReferences(record.tree);
    final current = await storage.scan(record.tree);
    _checkUnchanged(
      record,
      current,
      allowMissing: record.phase == LegacyPhase.deleting,
    );
    if (record.phase == LegacyPhase.choice) {
      if (restore) _validateRestorable(record);
      record.phase = restore ? LegacyPhase.restoring : LegacyPhase.deleting;
      await _save(record); // Persist consent before copy or delete.
    }
    if (record.phase == LegacyPhase.restoring) {
      final stage = _stage(record);
      await stage.create(recursive: true);
      await ImportSafetyPolicy.ensureAvailableCapacity(
        root.path,
        record.bytes * 3,
      );
      for (final entry in record.entries.where((e) => e.directory)) {
        await Directory(
          p.join(stage.path, 'original', entry.path),
        ).create(recursive: true);
      }
      var copied = 0;
      for (final entry in record.entries.where((e) => !e.directory)) {
        onProgress?.call(LegacyPhase.restoring, copied, record.fileCount);
        final copy = File(p.join(stage.path, 'original', entry.path));
        if (!await _matches(copy, entry)) {
          await storage.copy(record.tree, entry, copy);
        }
        if (!await _matches(copy, entry)) {
          throw StateError('Copy verification failed');
        }
        copied++;
      }
      await _prepare(record);
      record.phase = LegacyPhase.importing;
      await _save(record);
    }
    if (record.phase == LegacyPhase.importing) {
      final prepared = Directory(p.join(_stage(record).path, 'prepared'));
      // Source copies and planned names are durable before touching the DB.
      onProgress?.call(LegacyPhase.importing, 0, 0);
      await restorePrepared(prepared);
      await _verifyCopies(record);
      record.restored = true;
      record.phase = LegacyPhase.deleting;
      await _save(record); // Never repeat metadata import after this point.
    }
    if (record.restored) await _verifyCopies(record);
    // Recheck the whole inventory before the first destructive operation.
    final remaining = await storage.scan(record.tree);
    _checkUnchanged(record, remaining, allowMissing: true);
    var deleted =
        record.fileCount - remaining.where((e) => !e.directory).length;
    for (final entry in remaining.where((e) => !e.directory)) {
      onProgress?.call(LegacyPhase.deleting, deleted, record.fileCount);
      await storage.deleteFile(record.tree, entry);
      deleted++;
    }
    final after = await storage.scan(record.tree);
    _checkUnchanged(record, after, allowMissing: true);
    if (after.any((e) => !e.directory)) throw StateError('Legacy files remain');
    record.phase = LegacyPhase.complete;
    await _save(record);
    await _cleanup(record);
    // Empty source directories are intentionally retained: SAF recursive tree
    // deletion could also remove files added concurrently by another app.
    return record;
  }

  void _checkUnchanged(
    LegacyMigrationRecord record,
    List<LegacyEntry> current, {
    required bool allowMissing,
  }) {
    _validateEntries(current);
    final expected = {for (final e in record.entries) e.path: e};
    for (final entry in current) {
      final before = expected[entry.path];
      if (before == null ||
          before.directory != entry.directory ||
          before.hash != entry.hash ||
          before.size != entry.size) {
        throw const LegacyMigrationException(LegacyIssue.sourceChanged);
      }
    }
    if (!allowMissing && current.length != record.entries.length) {
      throw const LegacyMigrationException(LegacyIssue.sourceChanged);
    }
  }

  void _validateRestorable(LegacyMigrationRecord record) {
    for (final entry in record.entries.where((e) => !e.directory)) {
      if (entry.path.startsWith('.tagshelf/')) continue;
      final mapped = _mapped(record, entry.path);
      if (!MediaFormatUtils.allSupportedExtensions.contains(
            p.extension(mapped).toLowerCase(),
          ) ||
          mapped.split('/').any(MediaFormatUtils.isIgnoredDirectory)) {
        throw const LegacyMigrationException(LegacyIssue.unsupportedFiles);
      }
    }
  }

  String _mapped(LegacyMigrationRecord record, String path) {
    // Isolate imported catalogs so current metadata and files cannot be replaced.
    final safe = LegacyEntry(
      path: path,
      directory: true,
      size: 0,
      hash: '',
    ).path;
    final parts = safe.split('/');
    if (!{
      'library',
      'folders',
      'covers',
      '.thumbnails',
    }.contains(parts.first)) {
      throw const FormatException('Invalid metadata path');
    }
    if (parts.first == 'covers' || parts.first == '.thumbnails') {
      if (parts.first == '.thumbnails') parts[0] = 'thumbnails';
      return p.posix.joinAll(['covers', 'Restored-${record.id}', ...parts]);
    }
    return p.posix.joinAll(['library', 'Restored-${record.id}', ...parts]);
  }

  Future<Directory> _prepare(LegacyMigrationRecord record) async {
    final stage = _stage(record);
    final original = Directory(p.join(stage.path, 'original'));
    final prepared = Directory(p.join(stage.path, 'prepared'));
    await prepared.create(recursive: true);
    for (final entry in record.entries) {
      if (entry.path.startsWith('.tagshelf')) continue;
      final destination = p.join(prepared.path, _mapped(record, entry.path));
      if (entry.directory) {
        await Directory(destination).create(recursive: true);
      } else {
        final copy = File(destination);
        await copy.parent.create(recursive: true);
        if (!await _matches(copy, entry)) {
          await File(p.join(original.path, entry.path)).copy(copy.path);
        }
      }
    }
    // Keep the original metadata as a durable recovery record. Validate the
    // source BEFORE rewriting paths; legacy path filtering must not hide errors.
    final metadata = File(p.join(original.path, '.tagshelf', 'metadata.json'));
    Map<String, dynamic>? document;
    final candidates = [metadata, File('${metadata.path}.bak')];
    var found = false;
    for (final candidate in candidates) {
      if (!await candidate.exists()) continue;
      found = true;
      try {
        if (await candidate.length() > ImportSafetyPolicy.maxMetadataBytes) {
          throw const FormatException('Metadata too large');
        }
        final parsed =
            jsonDecode(await candidate.readAsString()) as Map<String, dynamic>;
        if (parsed['version'] != 1 && parsed['version'] != 2) {
          throw const FormatException('Invalid version');
        }
        for (final key in ['tags', 'collections', 'mediaItems']) {
          if (parsed[key] is! List ||
              (parsed[key] as List).length >
                  ImportSafetyPolicy.maxMetadataRecordsPerType) {
            throw const FormatException('Invalid records');
          }
        }
        final tagKeys = <String>{};
        for (final raw in parsed['tags'] as List) {
          if (raw is! Map<String, dynamic> ||
              raw['key'] is! String ||
              (raw['key'] as String).isEmpty ||
              !tagKeys.add(raw['key'] as String)) {
            throw const FormatException('Invalid charm');
          }
          for (final field in ['name', 'parentKey', 'createdAt']) {
            if (raw[field] != null && raw[field] is! String) {
              throw const FormatException('Invalid charm text');
            }
          }
          for (final field in ['facetId', 'level', 'colorValue', 'parentId']) {
            if (raw[field] != null && raw[field] is! int) {
              throw const FormatException('Invalid charm number');
            }
          }
          if (raw['isHidden'] != null && raw['isHidden'] is! bool) {
            throw const FormatException('Invalid charm state');
          }
        }
        final rawTags = parsed['tags'] as List;
        for (final raw in rawTags) {
          if (raw['parentId'] != null && raw['parentKey'] == null) {
            final parents = rawTags
                .where((parent) => parent['id'] == raw['parentId'])
                .toList();
            if (parents.length != 1) {
              throw const FormatException('Ambiguous legacy parent');
            }
            raw['parentKey'] = parents.single['key'];
          }
          if (raw['parentKey'] != null && !tagKeys.contains(raw['parentKey'])) {
            throw const FormatException('Missing parent charm');
          }
          raw.remove('parentId');
        }
        final orderedTags = <dynamic>[];
        final visited = <String>{};
        while (orderedTags.length < rawTags.length) {
          final previousCount = orderedTags.length;
          for (final raw in rawTags) {
            final key = raw['key'] as String;
            if (!visited.contains(key) &&
                (raw['parentKey'] == null ||
                    visited.contains(raw['parentKey']))) {
              orderedTags.add(raw);
              visited.add(key);
            }
          }
          if (previousCount == orderedTags.length) {
            throw const FormatException('Cyclic charm hierarchy');
          }
        }
        parsed['tags'] = orderedTags;
        for (final key in ['collections', 'mediaItems']) {
          for (final raw in parsed[key] as List) {
            if (raw is! Map<String, dynamic>) {
              throw const FormatException('Invalid record');
            }
            for (final field in [
              'isCatalog',
              'isFavorite',
              'isPinned',
              'isArchived',
              'isHidden',
              'isTrashed',
              'splitSpreadView',
              'isHeaderExpanded',
            ]) {
              if (raw[field] != null && raw[field] is! bool) {
                throw const FormatException('Invalid state');
              }
            }
            for (final field in [
              'title',
              'alias',
              'type',
              'notes',
              'defaultSortOrder',
              'defaultViewMode',
              'lastViewedAt',
              'createdAt',
              'updatedAt',
            ]) {
              if (raw[field] != null && raw[field] is! String) {
                throw const FormatException('Invalid text');
              }
            }
            if (raw['tier'] != null && raw['tier'] is! int) {
              throw const FormatException('Invalid rank');
            }
            if (raw['tagKeys'] != null &&
                (raw['tagKeys'] is! List ||
                    (raw['tagKeys'] as List).any(
                      (key) => key is! String || !tagKeys.contains(key),
                    ))) {
              throw const FormatException('Invalid charm reference');
            }
            final relative = raw['relativePath'];
            if (relative is! String || relative.isEmpty) {
              throw const FormatException('Missing path');
            }
            final sourcePath = p.join(original.path, relative);
            if (await FileSystemEntity.type(sourcePath, followLinks: false) ==
                FileSystemEntityType.notFound) {
              throw const FormatException('Missing original item');
            }
            raw['uid'] = 'legacy-${record.id}-${raw['relativePath']}';
            for (final field in [
              'relativePath',
              'coverImagePath',
              'trashRootPath',
            ]) {
              if (raw[field] != null) {
                raw[field] = _mapped(record, raw[field] as String);
              }
            }
          }
        }
        document = parsed;
        break;
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    if (found && document == null) {
      throw const LegacyMigrationException(LegacyIssue.invalidMetadata);
    }
    document ??= {
      'version': 2,
      'tags': [],
      'collections': [],
      'mediaItems': [],
    };
    final restoredRoot = 'library/Restored-${record.id}';
    if (await Directory(p.join(prepared.path, restoredRoot)).exists()) {
      (document['collections'] as List).add({
        'uid': 'legacy-${record.id}',
        'relativePath': restoredRoot,
        'title': restoredCatalogTitle,
        'alias': restoredCatalogTitle,
        'isCatalog': true,
        'tagKeys': <String>[],
      });
    }
    {
      final target = File(p.join(prepared.path, '.tagshelf', 'metadata.json'));
      await target.parent.create(recursive: true);
      await target.writeAsString(jsonEncode(document), flush: true);
    }
    return prepared;
  }

  Future<void> _verifyCopies(LegacyMigrationRecord record) async {
    final paths = <String>[];
    for (final entry in record.entries.where((e) => !e.directory)) {
      final metadata = entry.path.startsWith('.tagshelf/');
      final file = File(
        metadata
            ? p.join(_stage(record).path, 'original', entry.path)
            : p.join(root.path, _mapped(record, entry.path)),
      );
      if (!await _matches(file, entry)) {
        throw StateError('Restored data verification failed');
      }
      if (!metadata && _mapped(record, entry.path).startsWith('library/')) {
        paths.add(_mapped(record, entry.path));
      }
    }
    await verifyDatabase?.call(paths);
  }

  Future<void> _cleanup(LegacyMigrationRecord record) async {
    final stage = _stage(record);
    if (!await stage.exists()) return;
    // Keep only the original metadata as a private recovery record. Media
    // copies used for verification must not permanently triple disk usage.
    final prepared = Directory(p.join(stage.path, 'prepared'));
    if (await prepared.exists()) {
      await prepared.delete(recursive: true); // audit: allow-file-io
    }
    final original = Directory(p.join(stage.path, 'original'));
    if (await original.exists()) {
      await for (final entry in original.list(followLinks: false)) {
        if (record.restored && p.basename(entry.path) == '.tagshelf') {
          continue;
        }
        await entry.delete(recursive: true); // audit: allow-file-io
      }
    }
  }

  Future<bool> _matches(File file, LegacyEntry entry) async =>
      await file.exists() &&
      await file.length() == entry.size &&
      (await sha256.bind(file.openRead()).first).toString() == entry.hash;
}
