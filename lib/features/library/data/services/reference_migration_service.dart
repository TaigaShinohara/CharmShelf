import '../../../../core/services/library_storage_lock.dart';
import '../../domain/models/viewing_history.dart';
import '../../domain/models/tag_facet.dart';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../../../core/services/storage_sandbox.dart';
import '../../../../core/services/import_safety_policy.dart';
import '../../domain/models/tag.dart';
import '../../domain/models/collection.dart';
import '../../domain/models/media_item.dart';
import '../../domain/models/reference_migration.dart';
import '../../domain/models/storage_ref.dart';

/// An isolated graph. Hidden/archived/trashed rows are deliberately included.
class ReferenceMigrationGroup {
  ReferenceMigrationGroup(this.items, this.collections);
  final List<MediaItem> items;
  final List<MediaCollection> collections;
  String get title =>
      collections.firstOrNull?.title ??
      p.basename(
        items.first.originalPath.isEmpty
            ? items.first.path
            : items.first.originalPath,
      );
  bool get isTrashed =>
      items.any((i) => i.isTrashed) || collections.any((c) => c.isTrashed);
  int get files => items.where((i) => i.type == MediaType.file).length;
  int get knownBytes => items
      .where((i) => i.type == MediaType.file)
      .fold(0, (n, i) => n + (i.size ?? 0));
  int get unknownSizes =>
      items.where((i) => i.type == MediaType.file && i.size == null).length;
}

class MigrationInterrupted implements Exception {}

/// The source callback only lends a readable File. This service NEVER deletes it.
/// The caller owns any temporary source snapshot and its lifetime.
class ReferenceMigrationService {
  ReferenceMigrationService(
    this.isar,
    this.root, {
    required this.withSource,
    required this.releaseAccess,
    this.checkpoint,
    this.beforeStart,
  });
  final Isar isar;
  final Directory root;
  final Future<void> Function(
    String locator,
    String name,
    Future<void> Function(File) read,
  )
  withSource;
  final Future<void> Function(Uri) releaseAccess;
  final Future<void> Function(String stage)? checkpoint;
  final Future<void> Function()? beforeStart;
  bool _running = false;
  bool _cancelled = false;
  String? currentSource;
  void cancel() => _cancelled = true;

  static bool externalPath(String path) =>
      path.isNotEmpty &&
      (p.isAbsolute(path) || Uri.tryParse(path)?.hasScheme == true);

  Future<List<ReferenceMigrationGroup>> inventory() async {
    final items = await isar.mediaItems
        .filter()
        .sourceTypeEqualTo(MediaSourceType.externalReference)
        .findAll();
    final collections = (await isar.mediaCollections.where().findAll())
        .where(
          (c) =>
              c.type == CollectionType.externalFolder || externalPath(c.path),
        )
        .toList();
    final parent = <String, String>{};
    for (final path in [
      ...items.map((i) => i.path),
      ...collections.map((c) => c.path),
    ]) {
      parent[path] = path;
    }
    String find(String path) {
      final next = parent[path]!;
      return next == path ? path : parent[path] = find(next);
    }

    void join(String a, String? b) {
      if (b != null && parent.containsKey(b)) parent[find(a)] = find(b);
    }

    for (final item in items) {
      join(item.path, item.parentPath);
    }
    for (final col in collections) {
      await col.items.load();
      for (final item in col.items) {
        if (parent.containsKey(item.path)) join(item.path, col.path);
      }
    }
    final groups = <String, ReferenceMigrationGroup>{};
    for (final item in items) {
      groups
          .putIfAbsent(find(item.path), () => ReferenceMigrationGroup([], []))
          .items
          .add(item);
    }
    for (final col in collections) {
      groups
          .putIfAbsent(find(col.path), () => ReferenceMigrationGroup([], []))
          .collections
          .add(col);
    }
    return groups.values.toList();
  }

  Future<Map<String, dynamic>> _snapshot(ReferenceMigrationGroup group) async {
    final itemIds = group.items.map((i) => i.id).toSet();
    final colIds = group.collections.map((c) => c.id).toSet();
    final items = itemIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await isar.mediaItems
              .filter()
              .anyOf(itemIds, (q, id) => q.idEqualTo(id))
              .exportJson();
    final cols = colIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await isar.mediaCollections
              .filter()
              .anyOf(colIds, (q, id) => q.idEqualTo(id))
              .exportJson();
    final itemUids = group.items.map((i) => i.uid).whereType<String>().toList();
    final ownerUids = [
      ...itemUids,
      ...group.collections.map((c) => c.uid).whereType<String>(),
    ];
    final links = <String, dynamic>{};
    final tagIds = <int>{};
    for (final c in (await isar.mediaCollections.getAll(
      colIds.toList(),
    )).whereType<MediaCollection>()) {
      await c.items.load();
      await c.tags.load();
      tagIds.addAll(c.tags.map((t) => t.id));
      links['${c.id}'] = {
        'items': c.items.map((i) => i.id).toList()..sort(),
        'tags': c.tags.map((t) => t.id).toList()..sort(),
      };
    }
    final pendingTags = tagIds.toList();
    for (var n = 0; n < pendingTags.length; n++) {
      final tag = await isar.tags.get(pendingTags[n]);
      if (tag == null) continue;
      for (final id in [
        ...tag.ancestorIds,
        if (tag.parentId != null) tag.parentId!,
      ]) {
        if (tagIds.add(id)) pendingTags.add(id);
      }
    }
    final tags = (await isar.tags.getAll(tagIds.toList())).whereType<Tag>();
    final facetIds = tags.map((t) => t.facetId).whereType<int>().toSet();
    return {
      'items': items,
      'collections': cols,
      'links': links,
      'tags': tagIds.isEmpty
          ? []
          : await isar.tags
                .filter()
                .anyOf(tagIds, (q, id) => q.idEqualTo(id))
                .exportJson(),
      'facets': facetIds.isEmpty
          ? []
          : await isar.tagFacets
                .filter()
                .anyOf(facetIds, (q, id) => q.idEqualTo(id))
                .exportJson(),
      'history': itemUids.isEmpty
          ? []
          : await isar.viewingHistorys
                .filter()
                .anyOf(
                  group.items.map((i) => i.uid).whereType<String>(),
                  (q, uid) => q.itemUidEqualTo(uid),
                )
                .exportJson(),
      'storageRefs': ownerUids.isEmpty
          ? []
          : await isar.storageRefs
                .filter()
                .anyOf(
                  [
                    ...group.items.map((i) => i.uid),
                    ...group.collections.map((c) => c.uid),
                  ].whereType<String>(),
                  (q, uid) => q.ownerUidEqualTo(uid),
                )
                .exportJson(),
    };
  }

  static String _name(String input) {
    final name = p
        .basename(input)
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_');
    if (name.isEmpty || name == '.' || name == '..') return 'file';
    final ext = p.extension(name);
    return name.length <= 100
        ? name
        : '${p.basenameWithoutExtension(name).substring(0, 60)}$ext';
  }

  Future<ReferenceMigration> _prepare(ReferenceMigrationGroup group) async {
    await beforeStart?.call();
    final paths = <String>{};
    final uids = <String>{};
    for (final item in group.items) {
      if (!paths.add(item.path) ||
          (item.uid?.isNotEmpty == true && !uids.add(item.uid!))) {
        throw StateError('migration_identity_conflict');
      }
    }
    uids.clear();
    for (final col in group.collections) {
      if (col.uid?.isNotEmpty == true && !uids.add(col.uid!)) {
        throw StateError('migration_identity_conflict');
      }
    }
    for (final old in await isar.referenceMigrations.where().findAll()) {
      if (old.committed) continue;
      final data = _decode(old);
      final ids = (data['before']['items'] as List).map((r) => r['id']).toSet();
      final cols = (data['before']['collections'] as List)
          .map((r) => r['id'])
          .toSet();
      if (group.items.any((i) => ids.contains(i.id)) ||
          group.collections.any((c) => cols.contains(c.id))) {
        if (jsonEncode(await _snapshot(group)) != jsonEncode(data['before'])) {
          // Preserve the old recovery record and staged bytes, then plan from
          // current metadata. Never overwrite edits made while migration paused.
          data['abandoned'] = true;
          old.snapshot = jsonEncode(data);
          old.committed = true;
          old.cleanupPending = false;
          await isar.writeTxn(() async {
            await isar.referenceMigrations.put(old);
          });
          continue;
        }
        return old;
      }
    }
    if (group.items.length > ImportSafetyPolicy.maxFileCount) {
      throw StateError('migration_limit');
    }
    final before = await _snapshot(group);
    final key = const Uuid().v4();
    final targets = <String, String>{};
    final directories = <String>{};
    final parents = <String, String?>{};
    final names = <String, String>{};
    for (final c in group.collections) {
      if (c.type != CollectionType.file) directories.add(c.path);
      names[c.path] = c.title;
    }
    for (final i in group.items) {
      if (i.type == MediaType.folder) directories.add(i.path);
      parents[i.path] = i.parentPath;
      names.putIfAbsent(
        i.path,
        () =>
            i.originalPath.isNotEmpty ? i.originalPath : Uri.decodeFull(i.path),
      );
    }
    final visiting = <String>{};
    final usedTargets = <String>{};
    String target(String source) {
      if (targets.containsKey(source)) return targets[source]!;
      if (!visiting.add(source)) throw StateError('migration_cycle');
      final parent = parents[source];
      final base =
          parent != null && names.containsKey(parent) && parent != source
          ? target(parent)
          : 'library';
      final name = _name(names[source]!);
      final ext = directories.contains(source) ? '' : p.extension(name);
      final stem = ext.isEmpty ? name : p.basenameWithoutExtension(name);
      // Unique per source, including case-insensitive filesystems.
      final suffix = sha256
          .convert(utf8.encode(source))
          .toString()
          .substring(0, 8);
      var destination = p.posix.join(
        base,
        base == 'library' ? '${stem}_${key.substring(0, 8)}_$suffix$ext' : name,
      );
      if (!usedTargets.add(destination.toLowerCase())) {
        destination = p.posix.join(base, '${stem}_$suffix$ext');
        if (!usedTargets.add(destination.toLowerCase())) {
          throw StateError('migration_name_collision');
        }
      }
      targets[source] = destination;
      visiting.remove(source);
      return targets[source]!;
    }

    for (final source in names.keys) {
      target(source);
    }
    final record = ReferenceMigration()
      ..key = key
      ..snapshot = jsonEncode({
        'version': 1,
        'before': before,
        'targets': targets,
        'directories': directories.toList(),
        'uids': {
          for (final i in group.items)
            'i${i.id}': (i.uid?.isNotEmpty == true
                ? i.uid!
                : const Uuid().v4()),
          for (final c in group.collections)
            'c${c.id}': (c.uid?.isNotEmpty == true
                ? c.uid!
                : const Uuid().v4()),
        },
      });
    if (utf8.encode(record.snapshot).length >
        ImportSafetyPolicy.maxMetadataBytes) {
      throw StateError('migration_limit');
    }
    await isar.writeTxn(() async {
      await isar.referenceMigrations.put(record);
    });
    await checkpoint?.call('planned');
    return record;
  }

  Map<String, dynamic> _decode(ReferenceMigration record) {
    if (record.snapshot.length > ImportSafetyPolicy.maxMetadataBytes) {
      throw StateError('migration_limit');
    }
    final data = jsonDecode(record.snapshot) as Map<String, dynamic>;
    if (data['version'] != 1 ||
        data['targets'] is! Map ||
        data['before'] is! Map ||
        !RegExp(r'^[a-f0-9-]{36}$').hasMatch(record.key)) {
      throw StateError('migration_version');
    }
    for (final target in (data['targets'] as Map).values) {
      if (target is! String ||
          !target.startsWith('library/') ||
          !target.split('/')[1].contains(record.key.substring(0, 8))) {
        throw StateError('migration_destination_invalid');
      }
    }
    return data;
  }

  Future<String> _owned(String path) async {
    final absolute = StorageSandbox.resolveRelative(
      root.path,
      path,
      allowedTopLevelDirectories: {'library', '.trash'},
    );
    await StorageSandbox.rejectSymbolicLinkAncestors(root.path, absolute);
    return absolute;
  }

  Stream<List<int>> _readChunks(File file) async* {
    await for (final chunk in file.openRead()) {
      if (_cancelled) throw MigrationInterrupted();
      yield chunk;
    }
  }

  Future<String> _digest(File file) async =>
      (await sha256.bind(_readChunks(file)).first).toString();

  Future<void> migrate(
    ReferenceMigrationGroup group, {
    void Function(int done, int total)? onProgress,
  }) => LibraryStorageLock.run(
    isar,
    () => _migrate(group, onProgress: onProgress),
  );

  Future<void> _migrate(
    ReferenceMigrationGroup group, {
    void Function(int done, int total)? onProgress,
  }) async {
    if (_running) throw StateError('migration_busy');
    _running = true;
    _cancelled = false;
    try {
      final record = await _prepare(group);
      final data = _decode(record);
      final targets = Map<String, String>.from(data['targets'] as Map);
      final done = Map<String, dynamic>.from(
        jsonDecode(record.checkpoints) as Map,
      );
      String physical(MediaItem item) {
        final dest = targets[item.path]!;
        if (!item.isTrashed) return dest;
        if (item.trashRootPath == null ||
            !targets.containsKey(item.trashRootPath)) {
          throw StateError('migration_trash_root');
        }
        return '.trash/${record.key}/$dest';
      }

      // Materialize directories without publishing them in the database.
      for (final source in (data['directories'] as List).cast<String>()) {
        final item = group.items.where((i) => i.path == source).firstOrNull;
        final col = group.collections
            .where((c) => c.path == source)
            .firstOrNull;
        final dest = item != null
            ? physical(item)
            : col?.isTrashed == true
            ? '.trash/${record.key}/${targets[source]}'
            : targets[source]!;
        await Directory(await _owned(dest)).create(recursive: true);
      }
      var copied = 0;
      for (final item in group.items.where((i) => i.type == MediaType.file)) {
        if (_cancelled) throw MigrationInterrupted();
        currentSource = item.originalPath.isEmpty
            ? item.path
            : item.originalPath;
        final dest = File(await _owned(physical(item)));
        final partial = File(await _owned('${physical(item)}.partial'));
        final saved = done['${item.id}'] as Map?;
        if (saved != null &&
            await dest.exists() &&
            await _digest(dest) == saved['hash']) {
          onProgress?.call(++copied, group.files);
          continue;
        }
        if (await dest.exists()) {
          throw StateError('migration_destination_changed');
        }
        if (saved != null &&
            await partial.exists() &&
            await _digest(partial) == saved['hash']) {
          await partial.rename(dest.path);
          onProgress?.call(++copied, group.files);
          continue;
        }
        await dest.parent.create(recursive: true);
        final sourceLocator =
            (data['sources'] as Map?)?[item.path] as String? ?? item.path;
        await withSource(
          sourceLocator,
          _name(item.originalPath.isEmpty ? item.path : item.originalPath),
          (source) async {
            final stat = await source.stat();
            if (item.size != null &&
                item.size != stat.size &&
                sourceLocator == item.path) {
              throw StateError('migration_source_changed');
            }
            await ImportSafetyPolicy.ensureAvailableCapacity(
              root.path,
              stat.size,
            );
            final beforeHash = await _digest(source);
            final sink = partial.openWrite();
            var written = 0;
            try {
              await for (final bytes in source.openRead()) {
                if (_cancelled) throw MigrationInterrupted();
                written += bytes.length;
                if (written > stat.size) {
                  throw StateError('migration_source_changed');
                }
                sink.add(bytes);
              }
              await sink.flush();
            } finally {
              await sink.close();
            }
            final after = await source.stat();
            if (stat.size != after.size ||
                stat.modified != after.modified ||
                await partial.length() != stat.size ||
                await _digest(partial) != beforeHash) {
              throw StateError('migration_source_changed');
            }
            // Save the verified checksum BEFORE rename. A crash after rename is resumable.
            done['${item.id}'] = {'hash': beforeHash, 'bytes': stat.size};
            record.checkpoints = jsonEncode(done);
            await isar.writeTxn(() async {
              await isar.referenceMigrations.put(record);
            });
            await checkpoint?.call('verified');
            await partial.rename(dest.path);
            await checkpoint?.call('materialized');
          },
        );
        onProgress?.call(++copied, group.files);
      }
      if (_cancelled) throw MigrationInterrupted();
      await checkpoint?.call('beforeCommit');
      await isar.writeTxn(() async {
        final freshItems = (await isar.mediaItems.getAll(
          group.items.map((i) => i.id).toList(),
        )).whereType<MediaItem>().toList();
        final freshCols = (await isar.mediaCollections.getAll(
          group.collections.map((c) => c.id).toList(),
        )).whereType<MediaCollection>().toList();
        final fresh = ReferenceMigrationGroup(freshItems, freshCols);
        if (jsonEncode(await _snapshot(fresh)) != jsonEncode(data['before'])) {
          throw StateError('migration_changed');
        }
        for (final item in fresh.items) {
          final old = item.path;
          item.uid = data['uids']['i${item.id}'] as String;
          item.path = targets[old]!;
          item.sourceType = MediaSourceType.localCopy;
          item.parentPath = targets[item.parentPath] ?? 'library';
          item.isMissing = false;
          item.missingCheckedAt = null;
          if (item.isTrashed) {
            item.trashRootPath = targets[item.trashRootPath];
            if (item.isTrashRoot) {
              item.trashPath = '.trash/${record.key}/${item.path}';
            }
          }
          if (externalPath(item.thumbnailPath ?? '')) item.thumbnailPath = null;
          item.size =
              (done['${item.id}'] as Map?)?['bytes'] as int? ?? item.size;
          await isar.mediaItems.put(item);
          await _storageRef(item.uid!, StorageOwnerType.item, item.path);
        }
        for (final col in fresh.collections) {
          final old = col.path;
          col.uid = data['uids']['c${col.id}'] as String;
          col.path = targets[old]!;
          if (col.type == CollectionType.externalFolder) {
            col.type = CollectionType.folder;
          }
          col.trashRootPath = targets[col.trashRootPath] ?? col.trashRootPath;
          col.coverImagePath =
              targets[col.coverImagePath] ??
              (externalPath(col.coverImagePath ?? '')
                  ? null
                  : col.coverImagePath);
          await isar.mediaCollections.put(col);
          await _storageRef(col.uid!, StorageOwnerType.collection, col.path);
          if (col.type == CollectionType.folder &&
              !fresh.items.any((i) => i.path == col.path)) {
            final folder = MediaItem()
              ..uid = const Uuid().v4()
              ..path = col.path
              ..type = MediaType.folder
              ..parentPath = p.posix.dirname(col.path)
              ..isHidden = col.isHidden
              ..isArchived = col.isArchived
              ..isTrashed = col.isTrashed
              ..trashRootPath = col.trashRootPath
              ..isTrashRoot = col.isTrashed && col.trashRootPath == col.path
              ..trashPath = col.isTrashed && col.trashRootPath == col.path
                  ? '.trash/${record.key}/${col.path}'
                  : null
              ..addedAt = col.createdAt
              ..updatedAt = col.updatedAt;
            await isar.mediaItems.put(folder);
            await _storageRef(folder.uid!, StorageOwnerType.item, folder.path);
          }
        }
        final refs = await isar.storageRefs.where().findAll();
        for (final ref in refs) {
          final destination = targets[ref.locator];
          if (destination == null) continue;
          ref.locator = destination;
          ref.normalizedLocator = destination;
          ref.sourceType = StorageSourceType.local;
          await isar.storageRefs.put(ref);
        }
        record.committed = true;
        await isar.referenceMigrations.put(record);
      });
      await checkpoint?.call('committed');
      await cleanup();
    } finally {
      _running = false;
    }
  }

  Future<void> _storageRef(
    String uid,
    StorageOwnerType type,
    String path,
  ) async {
    final existing = await isar.storageRefs
        .filter()
        .ownerUidEqualTo(uid)
        .ownerTypeEqualTo(type)
        .isPrimaryEqualTo(true)
        .findFirst();
    final value =
        existing ??
        (StorageRef()
          ..uid = const Uuid().v4()
          ..ownerUid = uid
          ..ownerType = type
          ..createdAt = DateTime.now());
    value
      ..sourceType = StorageSourceType.local
      ..locator = path
      ..normalizedLocator = path
      ..updatedAt = DateTime.now();
    await isar.storageRefs.put(value);
  }

  /// Explicit user action. Keep the original bytes and private migration snapshot.
  Future<void> removeReferences(ReferenceMigrationGroup group) =>
      LibraryStorageLock.run(isar, () => _removeReferences(group));

  Future<void> _removeReferences(ReferenceMigrationGroup group) async {
    if (_running) throw StateError('migration_busy');
    _running = true;
    try {
      final record = await _prepare(group);
      final data = _decode(record);
      await isar.writeTxn(() async {
        if (jsonEncode(await _snapshot(group)) != jsonEncode(data['before'])) {
          throw StateError('migration_changed');
        }
        for (final col in group.collections) {
          await col.tags.load();
          for (final tag in col.tags) {
            if (tag.usageCount > 0) tag.usageCount--;
            await isar.tags.put(tag);
          }
        }
        final itemUids = group.items
            .map((i) => i.uid)
            .whereType<String>()
            .toList();
        final colUids = group.collections
            .map((i) => i.uid)
            .whereType<String>()
            .toList();
        if (itemUids.isNotEmpty) {
          await isar.viewingHistorys
              .filter()
              .anyOf(itemUids, (q, uid) => q.itemUidEqualTo(uid))
              .deleteAll();
          await isar.storageRefs
              .filter()
              .ownerTypeEqualTo(StorageOwnerType.item)
              .anyOf(itemUids, (q, uid) => q.ownerUidEqualTo(uid))
              .deleteAll();
        }
        if (colUids.isNotEmpty) {
          await isar.storageRefs
              .filter()
              .ownerTypeEqualTo(StorageOwnerType.collection)
              .anyOf(colUids, (q, uid) => q.ownerUidEqualTo(uid))
              .deleteAll();
        }
        await isar.mediaItems.deleteAll(group.items.map((i) => i.id).toList());
        await isar.mediaCollections.deleteAll(
          group.collections.map((i) => i.id).toList(),
        );
        data['removed'] = true;
        record.snapshot = jsonEncode(data);
        record.committed = true;
        await isar.referenceMigrations.put(record);
      });
      await cleanup();
    } finally {
      _running = false;
    }
  }

  Future<String> exportSnapshot(ReferenceMigrationGroup group) async =>
      const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'metadataOnly': true,
        'data': await _snapshot(group),
      });

  Future<void> reconnect(
    ReferenceMigrationGroup group,
    MediaItem item,
    Uri uri,
  ) async {
    if (_running) throw StateError('migration_busy');
    final record = await _prepare(group);
    if ((jsonDecode(record.checkpoints) as Map).containsKey('${item.id}')) {
      throw StateError('migration_already_copied');
    }
    final data = _decode(record);
    final sources = Map<String, dynamic>.from(data['sources'] as Map? ?? {});
    sources[item.path] = uri.toString();
    data['sources'] = sources;
    record.snapshot = jsonEncode(data);
    await isar.writeTxn(() async {
      await isar.referenceMigrations.put(record);
    });
  }

  static Future<Set<String>> reservedPaths(Isar isar) async {
    final paths = <String>{};
    for (final record in await isar.referenceMigrations.where().findAll()) {
      final snapshot = jsonDecode(record.snapshot) as Map;
      if (snapshot['version'] != 1) throw StateError('migration_version');
      if (!record.committed ||
          snapshot['removed'] == true ||
          snapshot['abandoned'] == true) {
        paths.addAll((snapshot['targets'] as Map).values.cast<String>());
      }
    }
    return paths;
  }

  Future<void> cleanup() async {
    for (final record in await isar.referenceMigrations.where().findAll()) {
      if (!record.committed || !record.cleanupPending) continue;
      final data = _decode(record);
      for (final source in <String>{
        ...(data['targets'] as Map).keys.cast<String>(),
        ...((data['sources'] as Map?)?.values.cast<String>() ?? <String>[]),
      }) {
        final uri = Uri.parse(source);
        await releaseAccess(uri.hasScheme ? uri : Uri.file(source));
      }
      record.cleanupPending = false;
      await isar.writeTxn(() async {
        await isar.referenceMigrations.put(record);
      });
    }
  }
}
