import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:isar/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/features/library/data/services/tag_preset_service.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';

class MockIsar extends Mock implements Isar {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TagPresetService service;
  late MockIsar mockIsar;

  setUp(() {
    mockIsar = MockIsar();
    service = TagPresetService(mockIsar);
  });

  group('TagPresetService - Simplified Text Parsing', () {
    test('should parse basic facet and tags', () {
      const text = '''
[Genre]
Fairy Tale
  Grimm
[Mood]
Happy
''';
      final result = service.parseSimplifiedText(text);

      expect(result.facets.map((f) => f.name), containsAll(['Genre', 'Mood']));
      expect(
        result.tags
            .map(
              (t) => (name: t.name, facet: t.facetName, parent: t.parentName),
            )
            .toList(),
        containsAll([
          (name: 'Fairy Tale', facet: 'Genre', parent: null),
          (name: 'Grimm', facet: 'Genre', parent: 'Fairy Tale'),
          (name: 'Happy', facet: 'Mood', parent: null),
        ]),
      );
    });

    test('should handle deep nesting', () {
      const text = '''
[Facet]
A
  B
    C
      D
''';
      final result = service.parseSimplifiedText(text);

      expect(
        result.tags.map((t) => (t.name, t.facetName, t.parentName)).toList(),
        [
          ('A', 'Facet', null),
          ('B', 'Facet', 'A'),
          ('C', 'Facet', 'B'),
          ('D', 'Facet', 'C'),
        ],
      );
    });

    test('should use "未分類" if no facet is specified', () {
      const text = 'TagWithoutFacet';
      final result = service.parseSimplifiedText(text);

      expect(result.facets, isNotEmpty);
      expect(result.facets[0].name, '未分類');
      expect(result.tags, hasLength(1));
      expect(result.tags[0].name, 'TagWithoutFacet');
      expect(result.tags[0].facetName, '未分類');
      expect(result.tags[0].parentName, isNull);
    });
  });

  group('TagPresetService - Validation', () {
    test('過長なタグ名を永続化前に拒否する', () {
      final text = '[Facet]\n${'a' * 513}';
      expect(() => service.parseSimplifiedText(text), throwsA(isA<AppError>()));
    });

    test('should detect missing facet', () {
      const text = 'TagWithoutFacet';
      final errors = service.validateSimplifiedText(text);

      expect(errors, hasLength(1));
      expect(errors.first.code, TagPresetValidationCode.missingFacetHeader);
    });

    test('should detect empty facet name', () {
      const text = '[]\nTag';
      final errors = service.validateSimplifiedText(text);

      expect(errors, hasLength(1));
      expect(errors.first.code, TagPresetValidationCode.emptyFacetName);
    });

    test('should be valid for correct format', () {
      const text = '[Facet]\nTag\n  SubTag';
      final errors = service.validateSimplifiedText(text);

      expect(errors, isEmpty);
    });
  });

  test('English locale creates English facets and tags only', () async {
    final tempDir = Directory.systemTemp.createTempSync(
      'tag_preset_locale_test_',
    );
    final isar = await Isar.open(
      [TagSchema, TagFacetSchema],
      directory: tempDir.path,
      name: 'tag_preset_locale_test',
    );
    try {
      await TagPresetService(isar).createStandardPresets(localeCode: 'en-US');

      final facets = await isar.tagFacets.where().findAll();
      final tags = await isar.tags.where().findAll();
      expect(facets.map((facet) => facet.name), contains('Content type'));
      expect(facets.map((facet) => facet.name), isNot(contains('コンテンツタイプ')));
      expect(tags.map((tag) => tag.name), contains('Illustration'));
      expect(tags.map((tag) => tag.name), isNot(contains('イラスト')));
    } finally {
      await isar.close(deleteFromDisk: true);
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });

  for (final locale in [
    (
      code: 'ja',
      typeFacet: 'コンテンツタイプ',
      defaultFacet: '未分類',
      otherFacet: 'ジャンル',
      audio: '音声カタログ',
      oldAudio: '音声チェイン',
      collection: 'カタログ集',
      oldCollection: 'チェイン集',
    ),
    (
      code: 'en',
      typeFacet: 'Content type',
      defaultFacet: 'Uncategorized',
      otherFacet: 'Genre',
      audio: 'Audio catalog',
      oldAudio: 'Audio chain',
      collection: 'Catalog collection',
      oldCollection: 'Chain collection',
    ),
  ]) {
    group('Catalog presets (${locale.code})', () {
      late Directory directory;
      late Isar isar;
      late TagPresetService presets;

      setUp(() async {
        directory = await Directory.systemTemp.createTemp('chain_presets_');
        isar = await Isar.open(
          [TagSchema, TagFacetSchema, MediaCollectionSchema, MediaItemSchema],
          directory: directory.path,
          name: 'chain_presets_${DateTime.now().microsecondsSinceEpoch}',
        );
        presets = TagPresetService(isar);
      });

      tearDown(() async {
        await isar.close(deleteFromDisk: true);
        await directory.delete(recursive: true);
      });

      Future<TagFacet> facet(String name) async =>
          (await isar.tagFacets.filter().nameEqualTo(name).findFirst())!;

      Future<Tag?> charm(String facetName, String name) async => isar.tags
          .filter()
          .keyEqualTo(Tag.buildKey((await facet(facetName)).id, name))
          .findFirst();

      test(
        'fresh presets use catalog names and repeated creation is idempotent',
        () async {
          expect(
            await presets.createStandardPresets(localeCode: locale.code),
            greaterThan(0),
          );
          final audio = (await charm(locale.typeFacet, locale.audio))!;
          final collection = (await charm(
            locale.defaultFacet,
            locale.collection,
          ))!;
          expect(await charm(locale.typeFacet, locale.oldAudio), isNull);
          expect(
            await charm(locale.defaultFacet, locale.oldCollection),
            isNull,
          );
          expect(
            await presets.createStandardPresets(localeCode: locale.code),
            0,
          );
          expect((await charm(locale.typeFacet, locale.audio))!.id, audio.id);
          expect(
            (await charm(locale.defaultFacet, locale.collection))!.id,
            collection.id,
          );
        },
      );

      test(
        'a user-created current name keeps every value and assignment',
        () async {
          await presets.createDefaultFacets(localeCode: locale.code);
          final typeFacet = await facet(locale.typeFacet);
          final defaultFacet = await facet(locale.defaultFacet);
          final parent = Tag()
            ..name = 'My own audio'
            ..facetId = typeFacet.id
            ..key = Tag.buildKey(typeFacet.id, 'My own audio')
            ..createdAt = DateTime.utc(2024, 1, 1);
          final audio = Tag()
            ..name = locale.audio
            ..facetId = typeFacet.id
            ..key = Tag.buildKey(typeFacet.id, locale.audio)
            ..colorValue = 0xFF123456
            ..usageCount = 7
            ..isHidden = true
            ..createdAt = DateTime.utc(2024, 2, 3);
          final collection = Tag()
            ..name = locale.collection
            ..facetId = defaultFacet.id
            ..key = Tag.buildKey(defaultFacet.id, locale.collection)
            ..colorValue = 0xFF654321
            ..usageCount = 3
            ..createdAt = DateTime.utc(2024, 4, 5);
          final assigned = MediaCollection()
            ..path = 'library/my-own-chain'
            ..title = 'My own collection'
            ..isCatalog = true;
          await isar.writeTxn(() async {
            await isar.tags.put(parent);
            audio
              ..parentId = parent.id
              ..level = 101
              ..ancestorIds = [parent.id];
            await isar.tags.putAll([audio, collection]);
            await isar.mediaCollections.put(assigned);
            assigned.tags.addAll([audio, collection]);
            await assigned.tags.save();
          });
          final before = [
            _tagSnapshot((await isar.tags.get(audio.id))!),
            _tagSnapshot((await isar.tags.get(collection.id))!),
          ];

          await presets.createStandardPresets(localeCode: locale.code);
          expect(
            await presets.createStandardPresets(localeCode: locale.code),
            0,
          );
          expect([
            _tagSnapshot((await isar.tags.get(audio.id))!),
            _tagSnapshot((await isar.tags.get(collection.id))!),
          ], before);
          final preserved = (await isar.mediaCollections.get(assigned.id))!;
          await preserved.tags.load();
          expect(
            preserved.tags.map((tag) => tag.id),
            unorderedEquals([audio.id, collection.id]),
          );
          expect(await charm(locale.typeFacet, locale.oldAudio), isNull);
          expect(
            await charm(locale.defaultFacet, locale.oldCollection),
            isNull,
          );
        },
      );

      test(
        'legacy names keep every value and assignment without duplicates',
        () async {
          await presets.createStandardPresets(localeCode: locale.code);
          final audio = (await charm(locale.typeFacet, locale.audio))!;
          final collection = (await charm(
            locale.defaultFacet,
            locale.collection,
          ))!;
          final parent = Tag()
            ..facetId = audio.facetId
            ..name = 'My audio'
            ..key = Tag.buildKey(audio.facetId!, 'My audio')
            ..createdAt = DateTime.utc(2024, 1, 1);
          final assigned = MediaCollection()
            ..path = 'library/my-files'
            ..title = 'My saved files'
            ..isCatalog = true;
          await isar.writeTxn(() async {
            await isar.tags.put(parent);
            audio
              ..name = locale.oldAudio
              ..key = Tag.buildKey(audio.facetId!, locale.oldAudio)
              ..parentId = parent.id
              ..level = 101
              ..ancestorIds = [parent.id]
              ..colorValue = 0xFF123456
              ..usageCount = 7
              ..isHidden = true
              ..createdAt = DateTime.utc(2024, 2, 3);
            collection
              ..name = locale.oldCollection
              ..key = Tag.buildKey(collection.facetId!, locale.oldCollection)
              ..colorValue = 0xFF654321
              ..usageCount = 3
              ..createdAt = DateTime.utc(2024, 4, 5);
            await isar.tags.putAll([audio, collection]);
            await isar.mediaCollections.put(assigned);
            assigned.tags.addAll([audio, collection]);
            await assigned.tags.save();
          });
          final before = [
            _tagSnapshot((await isar.tags.get(audio.id))!),
            _tagSnapshot((await isar.tags.get(collection.id))!),
          ];
          final countBefore = await isar.tags.count();

          expect(
            await presets.createStandardPresets(localeCode: locale.code),
            0,
          );
          expect(
            await presets.createStandardPresets(localeCode: locale.code),
            0,
          );
          final savedAudio = (await isar.tags.get(audio.id))!;
          final savedCollection = (await isar.tags.get(collection.id))!;
          expect([
            _tagSnapshot(savedAudio),
            _tagSnapshot(savedCollection),
          ], before);
          expect(await isar.tags.count(), countBefore);
          expect(await charm(locale.typeFacet, locale.audio), isNull);
          expect(await charm(locale.defaultFacet, locale.collection), isNull);
          final savedAssignment = (await isar.mediaCollections.get(
            assigned.id,
          ))!;
          await savedAssignment.tags.load();
          expect(
            savedAssignment.tags.map((tag) => tag.id),
            unorderedEquals([audio.id, collection.id]),
          );
        },
      );

      test(
        'when both names exist neither creates another charm nor changes either saved charm',
        () async {
          await presets.createStandardPresets(localeCode: locale.code);
          final typeFacet = await facet(locale.typeFacet);
          final defaultFacet = await facet(locale.defaultFacet);
          final current = (await charm(locale.typeFacet, locale.audio))!
            ..colorValue = 0xFFABCDEF
            ..usageCount = 9
            ..isHidden = true;
          final currentCollection = (await charm(
            locale.defaultFacet,
            locale.collection,
          ))!..colorValue = 0xFFFEDCBA;
          final legacy = Tag()
            ..name = locale.oldAudio
            ..facetId = typeFacet.id
            ..key = Tag.buildKey(typeFacet.id, locale.oldAudio)
            ..colorValue = 0xFF123456
            ..createdAt = DateTime.utc(2024, 1, 2);
          final legacyCollection = Tag()
            ..name = locale.oldCollection
            ..facetId = defaultFacet.id
            ..key = Tag.buildKey(defaultFacet.id, locale.oldCollection)
            ..colorValue = 0xFF654321
            ..createdAt = DateTime.utc(2024, 2, 3);
          final assigned = MediaCollection()
            ..path = 'library/both-names'
            ..title = 'Keep both names'
            ..isCatalog = true;
          await isar.writeTxn(() async {
            await isar.tags.putAll([legacy, legacyCollection]);
            // Set the hierarchy after the legacy parent's ID is assigned.
            current
              ..parentId = legacy.id
              ..level = 101
              ..ancestorIds = [legacy.id];
            await isar.tags.putAll([current, currentCollection]);
            await isar.mediaCollections.put(assigned);
            assigned.tags.addAll([
              legacy,
              legacyCollection,
              current,
              currentCollection,
            ]);
            await assigned.tags.save();
          });
          final before = [
            _tagSnapshot((await isar.tags.get(legacy.id))!),
            _tagSnapshot((await isar.tags.get(legacyCollection.id))!),
            _tagSnapshot((await isar.tags.get(current.id))!),
            _tagSnapshot((await isar.tags.get(currentCollection.id))!),
          ];
          final countBefore = await isar.tags.count();

          expect(
            await presets.createStandardPresets(localeCode: locale.code),
            0,
          );
          expect(await isar.tags.count(), countBefore);
          expect([
            _tagSnapshot((await isar.tags.get(legacy.id))!),
            _tagSnapshot((await isar.tags.get(legacyCollection.id))!),
            _tagSnapshot((await isar.tags.get(current.id))!),
            _tagSnapshot((await isar.tags.get(currentCollection.id))!),
          ], before);
          final preserved = (await isar.mediaCollections.get(assigned.id))!;
          await preserved.tags.load();
          expect(
            preserved.tags.map((tag) => tag.id),
            unorderedEquals([
              legacy.id,
              legacyCollection.id,
              current.id,
              currentCollection.id,
            ]),
          );
          expect(await charm(locale.typeFacet, locale.audio), isNotNull);
          expect(
            await charm(locale.defaultFacet, locale.collection),
            isNotNull,
          );
        },
      );

      test(
        'a legacy name in another category does not suppress the new preset',
        () async {
          await presets.createDefaultFacets(localeCode: locale.code);
          final otherFacet = await facet(locale.otherFacet);
          final legacy = Tag()
            ..name = locale.oldAudio
            ..facetId = otherFacet.id
            ..key = Tag.buildKey(otherFacet.id, locale.oldAudio)
            ..colorValue = 0xFF123456
            ..createdAt = DateTime.utc(2024, 1, 2);
          final legacyCollection = Tag()
            ..name = locale.oldCollection
            ..facetId = otherFacet.id
            ..key = Tag.buildKey(otherFacet.id, locale.oldCollection)
            ..colorValue = 0xFF654321
            ..createdAt = DateTime.utc(2024, 2, 3);
          await isar.writeTxn(
            () async => isar.tags.putAll([legacy, legacyCollection]),
          );
          final before = [
            _tagSnapshot((await isar.tags.get(legacy.id))!),
            _tagSnapshot((await isar.tags.get(legacyCollection.id))!),
          ];

          await presets.createStandardPresets(localeCode: locale.code);
          expect(await charm(locale.typeFacet, locale.audio), isNotNull);
          expect(
            await charm(locale.defaultFacet, locale.collection),
            isNotNull,
          );
          expect([
            _tagSnapshot((await isar.tags.get(legacy.id))!),
            _tagSnapshot((await isar.tags.get(legacyCollection.id))!),
          ], before);
        },
      );
    });
  }

  group('TagPresetService - Charm exchange file', () {
    test(
      'exports a versioned file and round-trips hierarchy and settings',
      () async {
        final sourceDir = Directory.systemTemp.createTempSync(
          'tag_preset_export_source_',
        );
        final targetDir = Directory.systemTemp.createTempSync(
          'tag_preset_export_target_',
        );
        final source = await Isar.open(
          [TagSchema, TagFacetSchema],
          directory: sourceDir.path,
          name: 'tag_preset_export_source',
        );
        final target = await Isar.open(
          [TagSchema, TagFacetSchema],
          directory: targetDir.path,
          name: 'tag_preset_export_target',
        );
        try {
          late TagFacet facet;
          late Tag parent;
          late Tag child;
          await source.writeTxn(() async {
            facet = TagFacet()
              ..name = 'ジャンル'
              ..colorValue = 0xFF2196F3
              ..sortOrder = 3
              ..createdAt = DateTime.utc(2026, 1, 1);
            await source.tagFacets.put(facet);
            parent = Tag()
              ..key = Tag.buildKey(facet.id, '童話')
              ..name = '童話'
              ..facetId = facet.id
              ..level = 100
              ..colorValue = 0xFFFF9800
              ..isHidden = true
              ..createdAt = DateTime.utc(2026, 1, 2);
            await source.tags.put(parent);
            child = Tag()
              ..key = Tag.buildKey(facet.id, 'グリム')
              ..name = 'グリム'
              ..facetId = facet.id
              ..parentId = parent.id
              ..ancestorIds = [parent.id]
              ..level = 101
              ..createdAt = DateTime.utc(2026, 1, 3);
            await source.tags.put(child);
          });

          final exported = await TagPresetService(source)
              .exportPresetsAsJsonString(
                exportedAt: DateTime(2026, 9, 23, 14, 30),
              );
          final document =
              jsonDecode(exported.jsonString) as Map<String, dynamic>;
          expect(document['format'], TagPresetService.exchangeFormat);
          expect(document['version'], TagPresetService.exchangeVersion);
          expect(exported.fileName, 'tagshelf-charms-20260923-1430.json');
          expect(exported.facetCount, 1);
          expect(exported.tagCount, 2);
          expect(exported.jsonString, isNot(contains('facetId')));
          expect(exported.jsonString, isNot(contains('parentId')));
          expect(exported.jsonString, isNot(contains('usageCount')));

          final targetService = TagPresetService(target);
          final result = await targetService.importPresetsFromJsonString(
            exported.jsonString,
          );
          expect(result.createdFacetCount, 1);
          expect(result.createdTagCount, 2);
          expect(result.updatedCount, 0);

          final importedFacet = await target.tagFacets.where().findFirst();
          expect(importedFacet!.name, 'ジャンル');
          expect(importedFacet.colorValue, 0xFF2196F3);
          expect(importedFacet.sortOrder, 3);
          final importedTags = await target.tags.where().findAll();
          final importedParent = importedTags.singleWhere(
            (tag) => tag.name == '童話',
          );
          final importedChild = importedTags.singleWhere(
            (tag) => tag.name == 'グリム',
          );
          expect(importedParent.colorValue, 0xFFFF9800);
          expect(importedParent.isHidden, isTrue);
          expect(importedChild.parentId, importedParent.id);
          expect(importedChild.ancestorIds, [importedParent.id]);
          expect(importedChild.level, 101);

          await target.writeTxn(() async {
            importedFacet.colorValue = 0xFF000000;
            importedParent
              ..colorValue = null
              ..isHidden = false;
            importedChild
              ..colorValue = 0xFF00FF00
              ..isHidden = true;
            await target.tagFacets.put(importedFacet);
            await target.tags.put(importedParent);
            await target.tags.put(importedChild);
          });
          final keepResult = await targetService.importPresetsFromJsonString(
            exported.jsonString,
          );
          expect(keepResult.updatedCount, 0);
          expect(keepResult.skippedFacetCount, 1);
          expect(keepResult.skippedTagCount, 2);
          expect(
            (await target.tagFacets.get(importedFacet.id))!.colorValue,
            0xFF000000,
          );

          final overwriteResult = await targetService
              .importPresetsFromJsonString(
                exported.jsonString,
                conflictPolicy: TagPresetConflictPolicy.overwrite,
              );
          expect(overwriteResult.updatedFacetCount, 1);
          expect(overwriteResult.updatedTagCount, 2);
          expect(
            (await target.tagFacets.get(importedFacet.id))!.colorValue,
            0xFF2196F3,
          );
          final overwrittenParent = await target.tags.get(importedParent.id);
          expect(overwrittenParent!.colorValue, 0xFFFF9800);
          expect(overwrittenParent.isHidden, isTrue);
          final overwrittenChild = await target.tags.get(importedChild.id);
          expect(overwrittenChild!.colorValue, isNull);
          expect(overwrittenChild.isHidden, isFalse);

          late TagFacet otherFacet;
          await source.writeTxn(() async {
            otherFacet = TagFacet()
              ..name = '状態'
              ..sortOrder = 4
              ..createdAt = DateTime.utc(2026, 1, 4);
            await source.tagFacets.put(otherFacet);
            final otherTag = Tag()
              ..key = Tag.buildKey(otherFacet.id, '未読')
              ..name = '未読'
              ..facetId = otherFacet.id
              ..level = 100
              ..createdAt = DateTime.utc(2026, 1, 5);
            await source.tags.put(otherTag);
          });
          final selectedExport = await TagPresetService(
            source,
          ).exportPresetsAsJsonString(facetId: facet.id);
          expect(selectedExport.facetCount, 1);
          expect(selectedExport.tagCount, 2);
          expect(selectedExport.jsonString, contains('ジャンル'));
          expect(selectedExport.jsonString, isNot(contains('状態')));
          expect(selectedExport.jsonString, isNot(contains('未読')));
        } finally {
          await source.close(deleteFromDisk: true);
          await target.close(deleteFromDisk: true);
          if (sourceDir.existsSync()) sourceDir.deleteSync(recursive: true);
          if (targetDir.existsSync()) targetDir.deleteSync(recursive: true);
        }
      },
    );

    test('rejects missing parents before writing any records', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'tag_preset_invalid_parent_',
      );
      final isar = await Isar.open(
        [TagSchema, TagFacetSchema],
        directory: tempDir.path,
        name: 'tag_preset_invalid_parent',
      );
      try {
        final invalid = jsonEncode({
          'format': TagPresetService.exchangeFormat,
          'version': TagPresetService.exchangeVersion,
          'categories': [
            {'name': 'Genre', 'color': null, 'sortOrder': 0},
          ],
          'charms': [
            {
              'category': 'Genre',
              'name': 'Child',
              'parent': 'Missing',
              'level': 101,
              'color': null,
              'hidden': false,
            },
          ],
        });

        await expectLater(
          TagPresetService(isar).importPresetsFromJsonString(invalid),
          throwsA(isA<AppError>()),
        );
        expect(await isar.tagFacets.count(), 0);
        expect(await isar.tags.count(), 0);
      } finally {
        await isar.close(deleteFromDisk: true);
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      }
    });

    test('rejects circular hierarchy before writing any records', () async {
      final tempDir = Directory.systemTemp.createTempSync('tag_preset_cycle_');
      final isar = await Isar.open(
        [TagSchema, TagFacetSchema],
        directory: tempDir.path,
        name: 'tag_preset_cycle',
      );
      try {
        final invalid = jsonEncode({
          'format': TagPresetService.exchangeFormat,
          'version': TagPresetService.exchangeVersion,
          'categories': [
            {'name': 'Genre', 'color': null, 'sortOrder': 0},
          ],
          'charms': [
            {
              'category': 'Genre',
              'name': 'A',
              'parent': 'B',
              'level': 100,
              'color': null,
              'hidden': false,
            },
            {
              'category': 'Genre',
              'name': 'B',
              'parent': 'A',
              'level': 101,
              'color': null,
              'hidden': false,
            },
          ],
        });

        await expectLater(
          TagPresetService(isar).importPresetsFromJsonString(invalid),
          throwsA(isA<AppError>()),
        );
        expect(await isar.tagFacets.count(), 0);
        expect(await isar.tags.count(), 0);
      } finally {
        await isar.close(deleteFromDisk: true);
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      }
    });
  });
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
