import 'dart:async';

import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../domain/models/collection.dart';
import '../../domain/models/media_item.dart';
import '../../domain/models/recently_opened_file.dart';
import '../../domain/models/viewing_history.dart';

class ViewingHistoryRepository {
  ViewingHistoryRepository(this._isar);

  final Isar _isar;
  static const maximumEntries = 50;

  Future<void> record(MediaItem item, {DateTime? openedAt}) async {
    if (item.isImportPreview || item.sourceType != MediaSourceType.localCopy) {
      return;
    }
    if (item.id <= 0 || item.type != MediaType.file || item.isMissing) return;
    await _isar.writeTxn(() async {
      final stored = await _isar.mediaItems.get(item.id);
      if (stored == null ||
          stored.path != item.path ||
          (item.uid?.isNotEmpty == true && stored.uid != item.uid) ||
          stored.sourceType != item.sourceType ||
          stored.isTrashed ||
          stored.isArchived ||
          stored.isMissing ||
          stored.type != MediaType.file) {
        return;
      }
      if (stored.uid == null || stored.uid!.isEmpty) {
        stored.uid = const Uuid().v4();
        await _isar.mediaItems.put(stored);
      }
      final existing = await _isar.viewingHistorys
          .filter()
          .itemUidEqualTo(stored.uid!)
          .findFirst();
      final viewedAt = openedAt ?? DateTime.now();
      if (existing != null && existing.openedAt.isAfter(viewedAt)) return;
      final entry = (existing ?? ViewingHistory())
        ..itemUid = stored.uid!
        ..openedAt = viewedAt;
      await _isar.viewingHistorys.put(entry);
      final expired = await _isar.viewingHistorys
          .where()
          .sortByOpenedAtDesc()
          .offset(maximumEntries)
          .idProperty()
          .findAll();
      await _isar.viewingHistorys.deleteAll(expired);
    });
  }

  /// Re-evaluated on display and immediately before opening, including parents.
  Future<MediaItem?> resolve(
    String uid, {
    required MediaSourceType sourceType,
    required bool includeHidden,
  }) async {
    return (await _resolveEntry(
      uid,
      sourceType: sourceType,
      includeHidden: includeHidden,
    ))?.item;
  }

  Future<RecentlyOpenedFile?> _resolveEntry(
    String uid, {
    required MediaSourceType sourceType,
    required bool includeHidden,
  }) async {
    final item = await _isar.mediaItems.filter().uidEqualTo(uid).findFirst();
    if (item == null ||
        item.sourceType != sourceType ||
        item.type != MediaType.file ||
        item.isTrashed ||
        item.isArchived ||
        item.isMissing ||
        (!includeHidden && item.isHidden)) {
      return null;
    }
    await item.collection.load();
    final linked = item.collection.value;
    if (linked != null && !_visible(linked, includeHidden)) return null;
    var catalog = linked?.isCatalog == true ? linked : null;
    var path = item.path;
    final visited = <String>{};
    while (path.isNotEmpty && path != '.' && visited.add(path)) {
      final collection = await _isar.mediaCollections
          .filter()
          .pathEqualTo(path)
          .findFirst();
      if (collection != null && !_visible(collection, includeHidden)) {
        return null;
      }
      if (catalog == null && collection?.isCatalog == true) {
        catalog = collection;
      }
      final parentItem = await _isar.mediaItems
          .filter()
          .pathEqualTo(path)
          .findFirst();
      if (parentItem != null &&
          (parentItem.isTrashed ||
              parentItem.isArchived ||
              parentItem.isMissing ||
              (!includeHidden && parentItem.isHidden))) {
        return null;
      }
      final logicalParent = parentItem?.parentPath;
      final next = logicalParent?.isNotEmpty == true
          ? logicalParent!
          : p.dirname(path);
      if (next == path) break;
      path = next;
    }
    return RecentlyOpenedFile(item: item, catalog: catalog);
  }

  bool _visible(MediaCollection collection, bool includeHidden) =>
      !collection.isTrashed &&
      !collection.isArchived &&
      (includeHidden || !collection.isHidden);

  Future<MediaItem?> latest({
    required MediaSourceType sourceType,
    required bool includeHidden,
  }) async {
    final items = await recent(
      sourceType: sourceType,
      includeHidden: includeHidden,
      limit: 1,
    );
    return items.isEmpty ? null : items.first.item;
  }

  Future<List<RecentlyOpenedFile>> recent({
    required MediaSourceType sourceType,
    required bool includeHidden,
    int limit = 3,
  }) async {
    if (limit <= 0) return [];
    final entries = await _isar.viewingHistorys
        .where()
        .sortByOpenedAtDesc()
        .limit(maximumEntries)
        .findAll();
    final items = <RecentlyOpenedFile>[];
    for (final entry in entries) {
      final item = await _resolveEntry(
        entry.itemUid,
        sourceType: sourceType,
        includeHidden: includeHidden,
      );
      if (item != null) items.add(item);
      if (items.length >= limit) break;
    }
    return items;
  }

  Stream<MediaItem?> watchLatest({
    required MediaSourceType sourceType,
    required bool includeHidden,
  }) {
    return watchRecent(
      sourceType: sourceType,
      includeHidden: includeHidden,
      limit: 1,
    ).map((items) => items.isEmpty ? null : items.first.item);
  }

  Stream<List<RecentlyOpenedFile>> watchRecent({
    required MediaSourceType sourceType,
    required bool includeHidden,
    int limit = 3,
  }) {
    late StreamController<List<RecentlyOpenedFile>> controller;
    final subscriptions = <StreamSubscription<void>>[];
    var generation = 0;
    Future<void> emit() async {
      final request = ++generation;
      try {
        final item = await recent(
          limit: limit,
          sourceType: sourceType,
          includeHidden: includeHidden,
        );
        if (!controller.isClosed && generation == request) controller.add(item);
      } catch (error, stack) {
        if (!controller.isClosed && generation == request) {
          controller.addError(error, stack);
        }
      }
    }

    controller = StreamController<List<RecentlyOpenedFile>>(
      onListen: () {
        for (final stream in [
          _isar.viewingHistorys.watchLazy(),
          _isar.mediaItems.watchLazy(),
          _isar.mediaCollections.watchLazy(),
        ]) {
          subscriptions.add(stream.listen((_) => unawaited(emit())));
        }
        unawaited(emit());
      },
      onCancel: () async {
        generation++;
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        unawaited(controller.close());
      },
    );
    return controller.stream;
  }
}
