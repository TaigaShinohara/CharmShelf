import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';

/// Keeps the owning side of MediaItem.collection in sync with path-based
/// metadata. Updating the backlink in memory does not persist an Isar link.
class CollectionItemLinkService {
  CollectionItemLinkService(this._isar)
    : _migrationKey =
          'collection_item_links_v1:${_isar.directory}/${_isar.name}';

  final Isar _isar;
  final String _migrationKey;

  /// The complete legacy scan runs once per database/version, before the
  /// database is exposed to readers. A failed transaction or completion write
  /// leaves the migration retryable; the repair itself is idempotent.
  Future<int> migrateOnce(SharedPreferences preferences) async {
    if (preferences.getBool(_migrationKey) == true) return 0;
    final repaired = await repairMissingLinks();
    if (!await preferences.setBool(_migrationKey, true)) {
      // SharedPreferences changes its memory cache even if persistence fails.
      await preferences.reload();
      throw StateError('Could not persist collection link migration state');
    }
    return repaired;
  }

  /// Only repairs relationships that can be inferred without guessing:
  /// an unowned item, or a plain parent-folder link superseded by metadata
  /// belonging to the item itself. Custom and multiply-owned links survive.
  Future<int> repairMissingLinks() => _isar.writeTxn(() async {
    final collections = await _isar.mediaCollections.where().findAll();
    final items = await _isar.mediaItems.where().findAll();
    for (final collection in collections) {
      await collection.items.load();
    }
    final repairs = planRepairs(collections, items);
    for (final repair in repairs) {
      await applyRepair(repair);
    }
    return repairs.length;
  });

  /// Called inside the same write transaction as an item save.
  Future<void> linkItemInTransaction(MediaItem item) async {
    if (item.path.isEmpty) return;
    final exact = await _isar.mediaCollections
        .filter()
        .pathEqualTo(item.path)
        .findFirst();
    final parent = item.parentPath?.isNotEmpty == true
        ? await _isar.mediaCollections
              .filter()
              .pathEqualTo(item.parentPath!)
              .findFirst()
        : null;
    final target = _preferredCollection(item, exact, parent);
    if (target == null) return;
    final owners = await _isar.mediaCollections
        .filter()
        .items((query) => query.idEqualTo(item.id))
        .findAll();
    final repair = _repairFor(item, target, owners);
    if (repair != null) await applyRepair(repair);
  }

  /// A collection can be created after its file was imported, for example
  /// when the first tag or memo is added. Connect both its own item and loose
  /// direct children; existing specific/custom owners are not overwritten.
  Future<void> linkCollectionInTransaction(MediaCollection collection) async {
    if (collection.path.isEmpty) return;
    final items = await _isar.mediaItems
        .filter()
        .group(
          (query) => query
              .pathEqualTo(collection.path)
              .or()
              .group(
                (query) =>
                    query.parentPathEqualTo(collection.path).collectionIsNull(),
              ),
        )
        .findAll();
    for (final item in items) {
      await linkItemInTransaction(item);
    }
  }

  static List<CollectionItemLinkRepair> planRepairs(
    List<MediaCollection> collections,
    List<MediaItem> items,
  ) {
    final byPath = <String, MediaCollection>{
      for (final collection in collections)
        if (collection.path.isNotEmpty) collection.path: collection,
    };
    final ownersByItem = <int, List<MediaCollection>>{};
    for (final collection in collections) {
      for (final item in collection.items) {
        ownersByItem.putIfAbsent(item.id, () => []).add(collection);
      }
    }
    final repairs = <CollectionItemLinkRepair>[];
    for (final item in items) {
      final target = _preferredCollection(
        item,
        byPath[item.path],
        byPath[item.parentPath],
      );
      if (target == null) continue;
      final repair = _repairFor(item, target, ownersByItem[item.id] ?? []);
      if (repair != null) repairs.add(repair);
    }
    return repairs;
  }

  static MediaCollection? _preferredCollection(
    MediaItem item,
    MediaCollection? exact,
    MediaCollection? parent,
  ) {
    bool compatible(MediaCollection collection) =>
        collection.isTrashed == item.isTrashed &&
        (collection.type == CollectionType.externalFolder) ==
            (item.sourceType == MediaSourceType.externalReference);
    if (exact != null && compatible(exact)) return exact;
    if (parent != null &&
        parent.type != CollectionType.file &&
        compatible(parent)) {
      return parent;
    }
    return null;
  }

  static CollectionItemLinkRepair? _repairFor(
    MediaItem item,
    MediaCollection target,
    List<MediaCollection> owners,
  ) {
    if (owners.isEmpty) {
      return CollectionItemLinkRepair(item: item, target: target);
    }
    if (owners.length == 1 &&
        owners.single.id != target.id &&
        target.path == item.path &&
        owners.single.path == item.parentPath &&
        owners.single.type != CollectionType.file) {
      return CollectionItemLinkRepair(
        item: item,
        target: target,
        previousParent: owners.single,
      );
    }
    return null;
  }

  Future<void> applyRepair(CollectionItemLinkRepair repair) async {
    await repair.previousParent?.items.update(unlink: [repair.item]);
    await repair.target.items.update(link: [repair.item]);
    repair.item.collection.value = repair.target;
  }
}

class CollectionItemLinkRepair {
  const CollectionItemLinkRepair({
    required this.item,
    required this.target,
    this.previousParent,
  });

  final MediaItem item;
  final MediaCollection target;
  final MediaCollection? previousParent;
}
