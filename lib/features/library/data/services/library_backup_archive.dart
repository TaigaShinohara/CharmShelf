import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../../core/services/import_safety_policy.dart';
import '../../../../core/services/storage_sandbox.dart';
import '../../domain/models/library_backup.dart';

/// Streaming, uncompressed portable container. Its manifest and every file are
/// hashed; untrusted paths are never used without sandbox validation. No DB,
/// settings, passcode, access tokens, or OS bookmarks are included.
abstract final class LibraryBackupArchive {
  static const roots = {
    'library',
    'folders',
    'covers',
    '.trash',
    '.thumbnails',
  };
  static final _magic = utf8.encode('TSHELF1\n');
  static const _chunkSize = 64 * 1024;

  static String safePath(Directory root, String path) {
    if (path.length > 4096 ||
        path.split('/').length > ImportSafetyPolicy.maxRelativePathDepth ||
        path.split('/').any((s) => s == '.' || s == '..' || s.isEmpty)) {
      throw const FormatException('Invalid backup path');
    }
    return StorageSandbox.resolveRelative(
      root.path,
      path,
      allowedTopLevelDirectories: roots,
    );
  }

  static Future<File> write({
    required Directory root,
    required Directory workspace,
    required Map<String, dynamic> document,
    LibraryBackupCancellation? cancellation,
    void Function(int completed, int total)? onProgress,
  }) async {
    final files = <Map<String, dynamic>>[];
    var totalBytes = 0;
    for (final name in roots) {
      final directory = Directory(p.join(root.path, name));
      await StorageSandbox.rejectSymbolicLinkAncestors(
        root.path,
        directory.path,
      );
      if (!await directory.exists()) continue;
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        cancellation?.check();
        final type = await FileSystemEntity.type(
          entity.path,
          followLinks: false,
        );
        if (type == FileSystemEntityType.link) {
          throw const FileSystemException('Cannot back up symbolic links');
        }
        if (type != FileSystemEntityType.file) continue;
        final relative = p.posix.joinAll(
          p.split(p.relative(entity.path, from: root.path)),
        );
        safePath(root, relative);
        final file = File(entity.path);
        final size = await file.length();
        totalBytes += size;
        if (files.length >= ImportSafetyPolicy.maxFileCount ||
            totalBytes > ImportSafetyPolicy.maxTotalBytes) {
          throw const FormatException('Backup exceeds the safety limit');
        }
        files.add({
          'path': relative,
          'size': size,
          'sha256': await hashFile(file, cancellation: cancellation),
        });
      }
    }
    files.sort((a, b) => (a['path'] as String).compareTo(b['path'] as String));
    final itemRecords = (document['items'] as List)
        .cast<Map<String, dynamic>>();
    final itemsByPath = {for (final item in itemRecords) item['path']: item};
    for (final item in itemRecords) {
      if (item['type'] != 'folder' || item['isMissing'] == true) continue;
      final actual = item['isTrashed'] == true
          ? trashLocation(item, itemsByPath)
          : item['path'] as String;
      final directory = Directory(safePath(root, actual));
      await StorageSandbox.rejectSymbolicLinkAncestors(
        root.path,
        directory.path,
      );
      if (!await directory.exists()) {
        throw const FormatException('Backup is missing a library folder');
      }
    }
    document['files'] = files;
    final manifest = await Isolate.run(() => utf8.encode(jsonEncode(document)));
    if (manifest.length > ImportSafetyPolicy.maxMetadataBytes) {
      throw const FormatException('Backup metadata exceeds the safety limit');
    }
    await ImportSafetyPolicy.ensureAvailableCapacity(
      workspace.path,
      totalBytes + manifest.length + 44,
    );
    final file = File(p.join(workspace.path, 'library.tagshelf'));
    final output = await file.open(mode: FileMode.write);
    try {
      await output.writeFrom(_magic);
      final length = ByteData(4)..setUint32(0, manifest.length);
      await output.writeFrom(length.buffer.asUint8List());
      await output.writeFrom(sha256.convert(manifest).bytes);
      await output.writeFrom(manifest);
      for (var index = 0; index < files.length; index++) {
        cancellation?.check();
        final entry = files[index];
        final source = File(safePath(root, entry['path'] as String));
        await StorageSandbox.rejectSymbolicLinkAncestors(
          root.path,
          source.path,
        );
        var copied = 0;
        await for (final bytes in source.openRead()) {
          cancellation?.check();
          copied += bytes.length;
          if (copied > (entry['size'] as int)) {
            throw const FileSystemException('File changed during backup');
          }
          await output.writeFrom(bytes);
        }
        if (copied != entry['size']) {
          throw const FileSystemException('File changed during backup');
        }
        onProgress?.call(index + 1, files.length);
      }
      await output.flush();
    } finally {
      await output.close();
    }
    // Validate the completed private artifact before a user-chosen destination
    // receives it, including changes to source contents while the copy ran.
    await verify(file, cancellation: cancellation);
    return file;
  }

  static Future<Map<String, dynamic>> verify(
    File file, {
    Directory? extractTo,
    LibraryBackupCancellation? cancellation,
    void Function(int completed, int total)? onProgress,
  }) async {
    final input = await file.open();
    try {
      final header = await _readExactly(input, 44);
      if (!_same(header.sublist(0, 8), _magic)) {
        throw const FormatException('Not a CharmShelf backup');
      }
      final length = ByteData.sublistView(header, 8, 12).getUint32(0);
      if (length == 0 || length > ImportSafetyPolicy.maxMetadataBytes) {
        throw const FormatException('Invalid backup manifest length');
      }
      final bytes = await _readExactly(input, length);
      if (!_same(sha256.convert(bytes).bytes, header.sublist(12))) {
        throw const FormatException('Backup metadata is damaged');
      }
      final decoded = await Isolate.run(() {
        final parsed = jsonDecode(utf8.decode(bytes));
        if (parsed is! Map<String, dynamic>) {
          throw const FormatException('Invalid backup metadata');
        }
        validateDocument(parsed);
        return parsed;
      });
      final entries = (decoded['files'] as List).cast<Map<String, dynamic>>();
      final totalBytes = entries.fold<int>(
        0,
        (sum, e) => sum + (e['size'] as int),
      );
      if (await file.length() != 44 + length + totalBytes) {
        throw const FormatException(
          'Backup is incomplete or contains extra data',
        );
      }
      if (extractTo != null) {
        await ImportSafetyPolicy.ensureAvailableCapacity(
          extractTo.path,
          totalBytes,
        );
      }
      for (var index = 0; index < entries.length; index++) {
        cancellation?.check();
        final entry = entries[index];
        final digest = _DigestCollector();
        final hash = sha256.startChunkedConversion(digest);
        RandomAccessFile? output;
        try {
          if (extractTo != null) {
            final target = File(safePath(extractTo, entry['path'] as String));
            await StorageSandbox.rejectSymbolicLinkAncestors(
              extractTo.path,
              target.path,
            );
            await target.parent.create(recursive: true);
            output = await target.open(mode: FileMode.write);
          }
          var remaining = entry['size'] as int;
          while (remaining > 0) {
            cancellation?.check();
            final chunk = await _readExactly(
              input,
              remaining < _chunkSize ? remaining : _chunkSize,
            );
            hash.add(chunk);
            if (output != null) await output.writeFrom(chunk);
            remaining -= chunk.length;
          }
          hash.close();
          if (digest.value.toString() != entry['sha256']) {
            throw const FormatException('Backup file is damaged');
          }
          if (output != null) await output.flush();
        } finally {
          await output?.close();
        }
        onProgress?.call(index + 1, entries.length);
      }
      return decoded;
    } finally {
      await input.close();
    }
  }

  static void validateDocument(Map<String, dynamic> document) {
    if (document['format'] != 'TagShelf library' || document['version'] != 1) {
      throw const FormatException('Unsupported backup version');
    }
    date(document, 'createdAt');
    final lists = <String, List<Map<String, dynamic>>>{};
    for (final key in [
      'files',
      'items',
      'collections',
      'tags',
      'facets',
      'history',
    ]) {
      final value = document[key];
      if (value is! List ||
          value.length > ImportSafetyPolicy.maxMetadataRecordsPerType ||
          value.any((e) => e is! Map<String, dynamic>)) {
        throw const FormatException('Invalid backup records');
      }
      lists[key] = value.cast<Map<String, dynamic>>();
    }
    final paths = <String>{};
    var totalBytes = 0;
    for (final file in lists['files']!) {
      final path = text(file, 'path');
      safePath(Directory('/backup'), path);
      if (!paths.add(path)) {
        throw const FormatException('Duplicate backup file');
      }
      final size = integer(file, 'size');
      totalBytes += size;
      if (size < 0 ||
          totalBytes > ImportSafetyPolicy.maxTotalBytes ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(text(file, 'sha256'))) {
        throw const FormatException('Invalid backup file');
      }
    }
    final itemUids = _unique(lists['items']!, 'uid');
    final collectionUids = _unique(lists['collections']!, 'uid');
    final tagKeys = _unique(lists['tags']!, 'key');
    final facetNames = _unique(lists['facets']!, 'name');
    final itemPaths = _unique(lists['items']!, 'path');
    _unique(lists['collections']!, 'path');
    for (final facet in lists['facets']!) {
      integer(facet, 'sortOrder');
      optionalInteger(facet, 'colorValue');
      date(facet, 'createdAt');
    }
    final tagParents = <String, String?>{};
    final logicalTags = <String>{};
    final tagRecords = {
      for (final tag in lists['tags']!) text(tag, 'key'): tag,
    };
    for (final tag in lists['tags']!) {
      text(tag, 'name');
      integer(tag, 'level');
      integer(tag, 'usageCount');
      optionalInteger(tag, 'colorValue');
      boolean(tag, 'isHidden');
      date(tag, 'createdAt');
      final facet = optionalText(tag, 'facetName');
      final parent = optionalText(tag, 'parentKey');
      if (!logicalTags.add(jsonEncode([facet, tag['name']])) ||
          integer(tag, 'level') < 0) {
        throw const FormatException('Duplicate or invalid logical tag');
      }
      if ((facet != null && !facetNames.contains(facet)) ||
          (parent != null && !tagKeys.contains(parent))) {
        throw const FormatException('Invalid tag relationship');
      }
      if (parent != null &&
          tagRecords[parent]!['facetName'] != tag['facetName']) {
        throw const FormatException('Tag parent belongs to another category');
      }
      tagParents[text(tag, 'key')] = parent;
    }
    for (final key in tagKeys) {
      final seen = <String>{};
      String? current = key;
      while (current != null) {
        if (!seen.add(current) || seen.length > 100) {
          throw const FormatException('Invalid tag hierarchy');
        }
        current = tagParents[current];
      }
    }
    final itemsByPath = {
      for (final item in lists['items']!) text(item, 'path'): item,
    };
    for (final item in lists['items']!) {
      safePath(Directory('/backup'), text(item, 'path'));
      enumName(item, 'type', const ['file', 'folder']);
      date(item, 'addedAt');
      date(item, 'updatedAt');
      optionalDate(item, 'missingCheckedAt');
      optionalDate(item, 'trashedAt');
      for (final key in [
        'isMissing',
        'isArchived',
        'isHidden',
        'isFavorite',
        'isTrashed',
        'isTrashRoot',
      ]) {
        boolean(item, key);
      }
      optionalInteger(item, 'size');
      for (final key in [
        'parentPath',
        'thumbnailPath',
        'trashPath',
        'trashRootPath',
      ]) {
        _optionalPath(item, key);
      }
      final parent = optionalText(item, 'parentPath');
      if (parent != null &&
          parent != 'library' &&
          parent != 'folders' &&
          (!itemPaths.contains(parent) ||
              itemsByPath[parent]!['type'] != 'folder')) {
        throw const FormatException('Invalid file parent');
      }
      final seen = <String>{text(item, 'path')};
      var current = parent;
      while (current != null && current != 'library' && current != 'folders') {
        if (!seen.add(current) ||
            seen.length > ImportSafetyPolicy.maxRelativePathDepth) {
          throw const FormatException('Invalid file hierarchy');
        }
        current = optionalText(itemsByPath[current]!, 'parentPath');
      }
      if (item['type'] == 'folder' && paths.contains(item['path'])) {
        throw const FormatException('Folder collides with a backup file');
      }
      if (item['isTrashed'] == true && item['isMissing'] != true) {
        safePath(Directory('/backup'), trashLocation(item, itemsByPath));
      }
    }
    final owned = <String>{};
    for (final collection in lists['collections']!) {
      safePath(Directory('/backup'), text(collection, 'path'));
      text(collection, 'title');
      optionalText(collection, 'alias');
      optionalText(collection, 'notes');
      enumName(collection, 'type', const ['file', 'folder']);
      enumName(collection, 'defaultViewMode', const ['grid', 'list']);
      enumName(collection, 'defaultSortOrder', const [
        'dateDesc',
        'dateAsc',
        'nameAsc',
        'nameDesc',
        'sizeDesc',
        'sizeAsc',
        'tierDesc',
        'tierAsc',
        'favoriteDesc',
        'lastViewedDesc',
        'addedDesc',
        'updatedDesc',
        'addedAsc',
        'updatedAsc',
      ]);
      integer(collection, 'tier');
      date(collection, 'createdAt');
      date(collection, 'updatedAt');
      optionalDate(collection, 'lastViewedAt');
      for (final key in [
        'isCatalog',
        'isFavorite',
        'isPinned',
        'isArchived',
        'isHidden',
        'isTrashed',
        'splitSpreadView',
        'isHeaderExpanded',
      ]) {
        boolean(collection, key);
      }
      _optionalPath(collection, 'coverImagePath');
      _optionalPath(collection, 'trashRootPath');
      final items = stringList(collection, 'itemUids');
      if (items.any((uid) => !itemUids.contains(uid) || !owned.add(uid)) ||
          stringList(
            collection,
            'tagKeys',
          ).any((key) => !tagKeys.contains(key))) {
        throw const FormatException('Invalid collection relationship');
      }
      final viewed = optionalText(collection, 'lastViewedItemUid');
      if (viewed != null && !itemUids.contains(viewed)) {
        throw const FormatException('Invalid viewing position');
      }
    }
    _unique(lists['history']!, 'itemUid');
    for (final entry in lists['history']!) {
      if (!itemUids.contains(text(entry, 'itemUid'))) {
        throw const FormatException('Invalid viewing history');
      }
      date(entry, 'openedAt');
    }
    // An archive cannot silently declare a present local file without bytes.
    for (final item in lists['items']!) {
      if (item['type'] != 'file' || item['isMissing'] == true) continue;
      if (item['isTrashed'] == true) {
        if (!paths.contains(trashLocation(item, itemsByPath))) {
          throw const FormatException('Backup is missing a trashed file');
        }
        continue;
      }
      if (!paths.contains(item['path'])) {
        throw const FormatException('Backup is missing a library file');
      }
    }
    for (final path in paths) {
      var parent = p.posix.dirname(path);
      while (parent != '.') {
        if (paths.contains(parent)) {
          throw const FormatException('Backup file paths overlap');
        }
        parent = p.posix.dirname(parent);
      }
    }
    // Keep the local variable to make the unique collection identity check
    // explicit, even when an empty library is backed up.
    if (collectionUids.length != lists['collections']!.length) {
      throw const FormatException('Invalid collection identity');
    }
  }

  static Future<String> hashFile(
    File file, {
    LibraryBackupCancellation? cancellation,
  }) async {
    final digest = _DigestCollector();
    final hash = sha256.startChunkedConversion(digest);
    await for (final bytes in file.openRead()) {
      cancellation?.check();
      hash.add(bytes);
    }
    hash.close();
    return digest.value.toString();
  }

  static String trashLocation(
    Map<String, dynamic> item,
    Map<dynamic, Map<String, dynamic>> itemsByPath,
  ) {
    final root = itemsByPath[item['trashRootPath']];
    final trashPath = root == null ? null : optionalText(root, 'trashPath');
    if (trashPath == null) {
      throw const FormatException('Backup is missing trash information');
    }
    final path = item['path'] as String;
    final rootPath = root!['path'] as String;
    if (path == rootPath) return trashPath;
    if (!path.startsWith('$rootPath/')) {
      throw const FormatException('Invalid trash relationship');
    }
    return '$trashPath/${path.substring(rootPath.length + 1)}';
  }

  static Set<String> _unique(List<Map<String, dynamic>> records, String key) {
    final result = <String>{};
    for (final record in records) {
      if (!result.add(text(record, key))) {
        throw const FormatException('Duplicate backup identity');
      }
    }
    return result;
  }

  static void _optionalPath(Map<String, dynamic> record, String key) {
    final value = optionalText(record, key);
    if (value != null) safePath(Directory('/backup'), value);
  }

  static String text(Map<String, dynamic> record, String key) {
    final value = record[key];
    if (value is! String ||
        value.isEmpty ||
        value.length > 1000000 ||
        value.contains('\u0000')) {
      throw const FormatException('Invalid backup text');
    }
    return value;
  }

  static String? optionalText(Map<String, dynamic> record, String key) {
    if (record[key] == null) return null;
    final value = record[key];
    if (value is! String ||
        value.length > 1000000 ||
        value.contains('\u0000')) {
      throw const FormatException('Invalid backup text');
    }
    return value.isEmpty ? null : value;
  }

  static int integer(Map<String, dynamic> record, String key) {
    final value = record[key];
    if (value is! int) throw const FormatException('Invalid backup number');
    return value;
  }

  static int? optionalInteger(Map<String, dynamic> record, String key) =>
      record[key] == null ? null : integer(record, key);
  static bool boolean(Map<String, dynamic> record, String key) {
    final value = record[key];
    if (value is! bool) throw const FormatException('Invalid backup state');
    return value;
  }

  static DateTime date(Map<String, dynamic> record, String key) {
    final result = DateTime.tryParse(text(record, key));
    if (result == null) throw const FormatException('Invalid backup date');
    return result;
  }

  static DateTime? optionalDate(Map<String, dynamic> record, String key) =>
      record[key] == null ? null : date(record, key);
  static String enumName(
    Map<String, dynamic> record,
    String key,
    List<String> values,
  ) {
    final value = text(record, key);
    if (!values.contains(value)) {
      throw const FormatException('Invalid backup option');
    }
    return value;
  }

  static List<String> stringList(Map<String, dynamic> record, String key) {
    final value = record[key];
    if (value is! List ||
        value.length > ImportSafetyPolicy.maxMetadataRecordsPerType ||
        value.any((e) => e is! String)) {
      throw const FormatException('Invalid backup relationship');
    }
    final result = value.cast<String>();
    if (result.toSet().length != result.length) {
      throw const FormatException('Duplicate backup relationship');
    }
    return result;
  }

  static Future<Uint8List> _readExactly(
    RandomAccessFile file,
    int count,
  ) async {
    final result = Uint8List(count);
    var position = 0;
    while (position < count) {
      final read = await file.readInto(result, position, count);
      if (read == 0) throw const FormatException('Incomplete backup');
      position += read;
    }
    return result;
  }

  static bool _same(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }
}

class _DigestCollector implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}
