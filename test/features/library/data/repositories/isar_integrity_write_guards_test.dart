import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import 'package:private_shelf/features/library/data/repositories/isar_media_repository.dart';
import 'package:private_shelf/features/library/data/repositories/isar_tag_facet_repository.dart';
import 'package:private_shelf/features/library/data/repositories/isar_tag_repository.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late Isar isar;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'integrity_write_guards_',
    );
    isar = await Isar.open(
      [
        MediaCollectionSchema,
        MediaItemSchema,
        TagSchema,
        TagFacetSchema,
        StorageRefSchema,
      ],
      directory: tempDirectory.path,
      name: 'write_guards_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    if (isar.isOpen) await isar.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('タグと子孫の保存に失敗した場合は対象タグもロールバックする', () async {
    final repository = IsarTagRepository(isar);
    final root = Tag()
      ..key = 'facet::root'
      ..name = 'root'
      ..createdAt = DateTime(2026);
    final child = Tag()
      ..key = 'facet::child'
      ..name = 'child'
      ..createdAt = DateTime(2026);
    final conflict = Tag()
      ..key = 'facet::conflict'
      ..name = 'conflict'
      ..createdAt = DateTime(2026);
    await isar.writeTxn(() async {
      await isar.tags.putAll([root, child, conflict]);
    });

    root.name = 'changed';
    child.key = conflict.key;
    final result = await repository.saveTree(root, [child]);

    expect(result.isFailure, isTrue);
    expect((await isar.tags.get(root.id))!.name, 'root');
    expect((await isar.tags.get(child.id))!.key, 'facet::child');
  });

  test('Facet移管に失敗した場合はタグ更新とFacet削除をロールバックする', () async {
    final repository = IsarTagFacetRepository(isar);
    final source = TagFacet()
      ..name = '移動元'
      ..createdAt = DateTime(2026);
    final replacement = TagFacet()
      ..name = '移動先'
      ..createdAt = DateTime(2026);
    await isar.writeTxn(() async {
      await isar.tagFacets.putAll([source, replacement]);
      await isar.tags.putAll([
        Tag()
          ..key = Tag.buildKey(source.id, '同名')
          ..name = '同名'
          ..facetId = source.id
          ..createdAt = DateTime(2026),
        Tag()
          ..key = Tag.buildKey(replacement.id, '同名')
          ..name = '同名'
          ..facetId = replacement.id
          ..createdAt = DateTime(2026),
      ]);
    });

    final result = await repository.deleteAndReassignTags(
      source.id,
      replacement,
    );

    expect(result.isFailure, isTrue);
    expect(await isar.tagFacets.get(source.id), isNotNull);
    final sourceTags = await isar.tags
        .filter()
        .facetIdEqualTo(source.id)
        .findAll();
    expect(sourceTags, hasLength(1));
  });

  test('最終閲覧位置は対象Collectionに所属するItemだけを受け付ける', () async {
    final repository = IsarMediaRepository(isar);
    final member = MediaItem()
      ..uid = 'member'
      ..path = 'library/member.jpg';
    final foreign = MediaItem()
      ..uid = 'foreign'
      ..path = 'library/foreign.jpg';
    final collection = MediaCollection()
      ..uid = 'collection'
      ..path = 'library/collection'
      ..title = 'collection';
    await isar.writeTxn(() async {
      await isar.mediaItems.putAll([member, foreign]);
      await isar.mediaCollections.put(collection);
      collection.items.add(member);
      await collection.items.save();
    });

    final rejected = await repository.updateCollectionLastViewed(
      collection.path,
      itemId: foreign.id,
      viewedAt: DateTime(2026),
    );
    final accepted = await repository.updateCollectionLastViewed(
      collection.path,
      itemId: member.id,
      viewedAt: DateTime(2026, 1, 2),
    );

    expect(rejected.dataOrNull, isFalse);
    expect(accepted.dataOrNull, isTrue);
    expect(
      (await isar.mediaCollections.get(collection.id))!.lastViewedItemId,
      member.id,
    );
  });
}
