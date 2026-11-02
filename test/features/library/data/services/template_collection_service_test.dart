import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/private_storage_service.dart';
import 'package:private_shelf/features/library/data/services/template_collection_service.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final locale in [
    (
      code: 'ja',
      facet: 'コンテンツタイプ',
      otherFacet: 'ジャンル',
      current: '音声カタログ',
      legacy: '音声チェイン',
    ),
    (
      code: 'en',
      facet: 'Content type',
      otherFacet: 'Genre',
      current: 'Audio catalog',
      legacy: 'Audio chain',
    ),
  ]) {
    group('Welcome catalog charms (${locale.code})', () {
      late Directory directory;
      late Isar isar;
      late TemplateCollectionService templates;

      setUp(() async {
        directory = await Directory.systemTemp.createTemp('chain_templates_');
        PrivateStorageService.resetForTesting();
        SharedPreferences.setMockInitialValues({'app_locale': locale.code});
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (_) async => directory.path,
            );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler(
              'flutter/assets',
              (_) async => ByteData.sublistView(
                Uint8List.fromList(utf8.encode('sample asset')),
              ),
            );
        isar = await Isar.open(
          [MediaCollectionSchema, MediaItemSchema, TagSchema, TagFacetSchema],
          directory: directory.path,
          name: 'chain_templates_${DateTime.now().microsecondsSinceEpoch}',
        );
        templates = TemplateCollectionService(isar, FileService());
      });

      tearDown(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              null,
            );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', null);
        PrivateStorageService.resetForTesting();
        await isar.close(deleteFromDisk: true);
        if (directory.existsSync()) await directory.delete(recursive: true);
      });

      Future<Tag> createCharm(String name, {String? facetName}) async {
        final category = facetName ?? locale.facet;
        var facet = await isar.tagFacets
            .filter()
            .nameEqualTo(category)
            .findFirst();
        return isar.writeTxn(() async {
          if (facet == null) {
            facet = TagFacet()
              ..name = category
              ..createdAt = DateTime.utc(2024, 1, 1);
            await isar.tagFacets.put(facet!);
          }
          final tag = Tag()
            ..name = name
            ..facetId = facet!.id
            ..key = Tag.buildKey(facet!.id, name)
            ..colorValue = 0xFF123456
            ..isHidden = true
            ..usageCount = 5
            ..createdAt = DateTime.utc(2024, 2, 3);
          await isar.tags.put(tag);
          return tag;
        });
      }

      Future<List<int>> audioCharmIds() async {
        final audio = await isar.mediaCollections
            .filter()
            .pathEqualTo('library/digital_shelf_life.mp3')
            .findFirst();
        expect(audio, isNotNull);
        await audio!.tags.load();
        return audio.tags.map((tag) => tag.id).toList();
      }

      test(
        'new charm is attached once and repeated creation keeps one assignment',
        () async {
          final current = await createCharm(locale.current);
          final before = _tagSnapshot((await isar.tags.get(current.id))!);

          expect((await templates.createWelcomeCollection()).isSuccess, isTrue);
          expect(await audioCharmIds(), [current.id]);
          expect((await templates.createWelcomeCollection()).isSuccess, isTrue);
          expect(await audioCharmIds(), [current.id]);
          expect(await isar.tags.count(), 1);
          expect(_tagSnapshot((await isar.tags.get(current.id))!), before);
        },
      );

      test(
        'legacy charm remains unchanged and is used without creating a new charm',
        () async {
          final legacy = await createCharm(locale.legacy);
          final before = _tagSnapshot((await isar.tags.get(legacy.id))!);
          final saved = MediaCollection()
            ..path = 'library/my-records'
            ..title = 'My saved records'
            ..notes = 'Keep my own names and content'
            ..isCatalog = true;
          await isar.writeTxn(() async {
            await isar.mediaCollections.put(saved);
            saved.tags.add(legacy);
            await saved.tags.save();
          });

          expect((await templates.createWelcomeCollection()).isSuccess, isTrue);
          expect(await audioCharmIds(), [legacy.id]);
          expect(await isar.tags.count(), 1);
          expect(_tagSnapshot((await isar.tags.get(legacy.id))!), before);
          final preserved = (await isar.mediaCollections.get(saved.id))!;
          expect(preserved.title, 'My saved records');
          expect(preserved.notes, 'Keep my own names and content');
          await preserved.tags.load();
          expect(preserved.tags.map((tag) => tag.id), [legacy.id]);
        },
      );

      test(
        'when both names exist the current name wins with one assignment',
        () async {
          final legacy = await createCharm(locale.legacy);
          final current = await createCharm(locale.current);
          final before = [
            _tagSnapshot((await isar.tags.get(legacy.id))!),
            _tagSnapshot((await isar.tags.get(current.id))!),
          ];

          expect((await templates.createWelcomeCollection()).isSuccess, isTrue);
          expect(await audioCharmIds(), [current.id]);
          expect(await isar.tags.count(), 2);
          expect([
            _tagSnapshot((await isar.tags.get(legacy.id))!),
            _tagSnapshot((await isar.tags.get(current.id))!),
          ], before);
        },
      );

      test('same legacy name in another category is not assigned', () async {
        final unrelated = await createCharm(
          locale.legacy,
          facetName: locale.otherFacet,
        );
        final current = await createCharm(locale.current);
        final before = _tagSnapshot((await isar.tags.get(unrelated.id))!);

        expect((await templates.createWelcomeCollection()).isSuccess, isTrue);
        expect(await audioCharmIds(), [current.id]);
        expect(_tagSnapshot((await isar.tags.get(unrelated.id))!), before);
      });
    });
  }
}

List<Object?> _tagSnapshot(Tag tag) => [
  tag.id,
  tag.key,
  tag.name,
  tag.facetId,
  tag.parentId,
  tag.level,
  [...tag.ancestorIds],
  tag.colorValue,
  tag.usageCount,
  tag.isHidden,
  tag.createdAt.microsecondsSinceEpoch,
];
