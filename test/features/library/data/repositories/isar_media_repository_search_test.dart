import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/features/library/application/use_cases/import_media_use_case.dart';
import 'package:private_shelf/features/library/data/repositories/isar_media_repository.dart';
import 'package:private_shelf/features/library/data/services/collection_item_link_service.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';

class _ImportFileService extends Mock implements FileService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late Isar isar;
  late IsarMediaRepository repository;

  setUpAll(() {
    registerFallbackValue(File('unused-import-source'));
  });

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('media_search_repo_');
    isar = await Isar.open(
      [
        MediaCollectionSchema,
        MediaItemSchema,
        TagSchema,
        TagFacetSchema,
        StorageRefSchema,
      ],
      directory: tempDirectory.path,
      name: 'media_search_${DateTime.now().microsecondsSinceEpoch}',
    );
    repository = IsarMediaRepository(isar);
  });

  tearDown(() async {
    if (isar.isOpen) await isar.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('単体追加した写真を付与タグ・表示名・メモで再起動後も検索できる', () async {
    final source = File('${tempDirectory.path}/original.jpg');
    await source.writeAsBytes([1, 2, 3]);
    final files = _ImportFileService();
    when(
      () => files.importFile(any()),
    ).thenAnswer((_) async => Result.success('library/imported.jpg'));
    final imported = await ImportMediaUseCase(
      files,
      Future.value(repository),
    ).invoke(source, isCatalog: true);
    expect(imported.isSuccess, isTrue);
    final itemId = imported.dataOrNull!.id;
    final collection = (await repository.getCollectionByPath(
      'library/imported.jpg',
    )).dataOrNull!;
    final tag = Tag()
      ..key = 'summer2026'
      ..name = 'summer2026';
    await isar.writeTxn(() => isar.tags.put(tag));
    expect(
      (await repository.syncTagsOnCollection(collection, [tag])).isSuccess,
      isTrue,
    );
    collection
      ..alias = 'family vacation'
      ..notes = 'morning lake';
    expect((await repository.saveCollection(collection)).isSuccess, isTrue);

    final databaseName = isar.name;
    await isar.close();
    isar = await Isar.open(
      [
        MediaCollectionSchema,
        MediaItemSchema,
        TagSchema,
        TagFacetSchema,
        StorageRefSchema,
      ],
      directory: tempDirectory.path,
      name: databaseName,
    );
    repository = IsarMediaRepository(isar);
    for (final query in ['summer2026', 'family', 'morning']) {
      for (final target in SearchTarget.values) {
        final result = await repository.getAll(
          filter: MediaFilter(searchQuery: query, searchTarget: target),
        );
        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull!.map((item) => item.id), [itemId]);
      }
    }
    final tagFilter = await repository.getAll(
      filter: MediaFilter(tagIds: [tag.id]),
    );
    expect(tagFilter.dataOrNull!.map((item) => item.id), [itemId]);
    expect(await source.readAsBytes(), [1, 2, 3]);
  });

  test('既存の関連漏れは冪等に修復され、通常検索とページ検索へ反映する', () async {
    final item = MediaItem()
      ..uid = 'legacy-unlinked-file'
      ..path = 'library/legacy.jpg';
    final collection = MediaCollection()
      ..uid = 'legacy-unlinked-collection'
      ..path = item.path
      ..type = CollectionType.file
      ..isCatalog = true
      ..alias = 'old family photo';
    final tag = Tag()
      ..key = 'legacy-tag'
      ..name = 'summer2026';
    await isar.writeTxn(() async {
      await isar.mediaItems.put(item);
      await isar.mediaCollections.put(collection);
      await isar.tags.put(tag);
      collection.tags.add(tag);
      await collection.tags.save();
    });
    final before = await repository.getAll(
      filter: const MediaFilter(searchQuery: 'summer2026'),
    );
    expect(before.dataOrNull, isEmpty);

    final links = CollectionItemLinkService(isar);
    expect(await links.repairMissingLinks(), 1);
    expect(await links.repairMissingLinks(), 0);
    final result = await repository.getAll(
      filter: const MediaFilter(searchQuery: 'summer2026'),
    );
    expect(result.dataOrNull!.map((value) => value.id), [item.id]);
    final page = await repository.getPage(
      filter: const MediaFilter(searchQuery: 'family'),
      offset: 0,
      limit: 1,
    );
    expect(page.dataOrNull!.map((value) => value.id), [item.id]);
  });

  test('追加後に初めて作ったメタデータも同じファイルへ永続的に関連する', () async {
    final item = MediaItem()
      ..path = 'library/loose.jpg'
      ..sourceType = MediaSourceType.localCopy;
    expect((await repository.save(item)).isSuccess, isTrue);
    final collection = MediaCollection()
      ..path = item.path
      ..type = CollectionType.file
      ..notes = 'remember this sunset';
    expect((await repository.saveCollection(collection)).isSuccess, isTrue);
    final result = await repository.getAll(
      filter: const MediaFilter(searchQuery: 'sunset'),
    );
    expect(result.dataOrNull!.map((value) => value.id), [item.id]);
  });

  test('外部参照やランクではなく登録状態だけでカタログ抽出・並び順が決まる', () async {
    final definitions = <MediaCollection>[
      MediaCollection()
        ..uid = 'plain-external-definition'
        ..path = 'content://provider/plain'
        ..type = CollectionType.externalFolder
        ..tier = 5,
      MediaCollection()
        ..uid = 'external-catalog-definition'
        ..path = 'content://provider/catalog'
        ..type = CollectionType.externalFolder
        ..isCatalog = true,
      MediaCollection()
        ..uid = 'ranked-file-definition'
        ..path = 'library/ranked.pdf'
        ..type = CollectionType.file
        ..tier = 5,
    ];
    final items = [
      for (var index = 0; index < definitions.length; index++)
        MediaItem()
          ..uid = 'registration-$index'
          ..path = definitions[index].path
          ..type = index < 2 ? MediaType.folder : MediaType.file
          ..sourceType = index < 2
              ? MediaSourceType.externalReference
              : MediaSourceType.localCopy,
    ];
    await isar.writeTxn(() async {
      await isar.mediaCollections.putAll(definitions);
      await isar.mediaItems.putAll(items);
    });

    for (final limit in <int?>[null, 1]) {
      final all = await repository.getAll(
        filter: MediaFilter(rootOnly: true, limit: limit),
      );
      expect(all.isSuccess, isTrue);
      expect(all.dataOrNull!.first.path, definitions.first.path);
    }
    final catalogs = await repository.getAll(
      filter: const MediaFilter(onlyCatalogs: true),
    );
    expect(catalogs.isSuccess, isTrue);
    expect(catalogs.dataOrNull!.map((item) => item.path), [
      definitions[1].path,
    ]);

    definitions[1].isCatalog = false;
    await isar.writeTxn(() => isar.mediaCollections.put(definitions[1]));
    final afterUnregister = await repository.getAll(
      filter: const MediaFilter(onlyCatalogs: true),
    );
    expect(afterUnregister.isSuccess, isTrue);
    expect(afterUnregister.dataOrNull, isEmpty);

    // A fresh repository/DB connection must read the saved registration state.
    final databaseName = isar.name;
    await isar.close();
    isar = await Isar.open(
      [
        MediaCollectionSchema,
        MediaItemSchema,
        TagSchema,
        TagFacetSchema,
        StorageRefSchema,
      ],
      directory: tempDirectory.path,
      name: databaseName,
    );
    final saved = await isar.mediaCollections.get(definitions[1].id);
    expect(saved!.isCatalog, isFalse);
    expect(saved.type, CollectionType.externalFolder);
  });

  test('デフォルト順では通常フォルダ、カタログ、通常ファイルの順になる', () async {
    final folder = MediaItem()
      ..uid = 'plain-folder'
      ..path = 'library/folder'
      ..type = MediaType.folder
      ..sourceType = MediaSourceType.localCopy;
    final catalog = MediaItem()
      ..uid = 'folder-catalog'
      ..path = 'library/catalog'
      ..type = MediaType.folder
      ..sourceType = MediaSourceType.localCopy;
    final catalogDefinition = MediaCollection()
      ..uid = 'folder-catalog-definition'
      ..path = catalog.path
      ..type = CollectionType.folder
      ..isCatalog = true;
    final fileCatalog = MediaItem()
      ..uid = 'file-catalog'
      ..path = 'library/catalog.pdf'
      ..type = MediaType.file
      ..sourceType = MediaSourceType.localCopy;
    final fileCatalogDefinition = MediaCollection()
      ..uid = 'file-catalog-definition'
      ..path = fileCatalog.path
      ..type = CollectionType.file
      ..isCatalog = true;
    final file = MediaItem()
      ..uid = 'plain-file'
      ..path = 'library/plain.txt'
      ..type = MediaType.file
      ..sourceType = MediaSourceType.localCopy;

    await isar.writeTxn(() async {
      await isar.mediaCollections.putAll([
        catalogDefinition,
        fileCatalogDefinition,
      ]);
      await isar.mediaItems.putAll([folder, catalog, fileCatalog, file]);
    });

    final result = await repository.getAll(
      filter: const MediaFilter(rootOnly: true),
    );

    expect(result.isSuccess, isTrue);
    expect(result.dataOrNull!.map((item) => item.uid), [
      'plain-folder',
      'folder-catalog',
      'file-catalog',
      'plain-file',
    ]);
  });

  test('タグ名で通常ライブラリの項目を検索できる', () async {
    final tag = Tag()
      ..key = 'facet:landscape'
      ..name = '風景写真';
    final collection = MediaCollection()
      ..uid = 'collection-1'
      ..path = 'library/trip'
      ..title = '2026年旅行'
      ..type = CollectionType.folder;
    final item = MediaItem()
      ..uid = 'item-1'
      ..path = 'library/trip/photo.jpg'
      ..parentPath = collection.path
      ..sourceType = MediaSourceType.localCopy;

    await isar.writeTxn(() async {
      await isar.tags.put(tag);
      await isar.mediaCollections.put(collection);
      collection.tags.add(tag);
      await collection.tags.save();
      await isar.mediaItems.put(item);
      item.collection.value = collection;
      await item.collection.save();
    });

    final result = await repository.getAll(
      filter: const MediaFilter(searchQuery: '風景'),
    );

    expect(result.isSuccess, isTrue);
    expect(result.dataOrNull!.map((value) => value.uid), ['item-1']);
  });

  for (final onlyCatalogs in [false, true]) {
    for (final sortOrder in [SortOrder.addedDesc, SortOrder.nameAsc]) {
      test('表示=$onlyCatalogs・順序=$sortOrderでもフォルダ内から全体へ通常/ページ検索できる', () async {
        final items = [
          MediaItem()
            ..uid = 'in-folder'
            ..path = 'library/trip/photo.jpg'
            ..parentPath = 'library/trip'
            ..sourceType = MediaSourceType.localCopy,
          MediaItem()
            ..uid = 'in-folder-second'
            ..path = 'library/trip/photo-second.jpg'
            ..parentPath = 'library/trip'
            ..sourceType = MediaSourceType.localCopy,
          MediaItem()
            ..uid = 'other-folder'
            ..path = 'library/home/photo.jpg'
            ..parentPath = 'library/home'
            ..sourceType = MediaSourceType.localCopy,
          MediaItem()
            ..uid = 'nested'
            ..path = 'library/trip/day/photo.jpg'
            ..parentPath = 'library/trip/day'
            ..sourceType = MediaSourceType.localCopy,
        ];
        for (var index = 0; index < items.length; index++) {
          items[index].addedAt = DateTime(2026, 1, index + 1);
        }
        await isar.writeTxn(() => isar.mediaItems.putAll(items));

        final filter = MediaFilter(
          parentPath: 'library/trip',
          rootOnly: true,
          searchQuery: 'photo',
          searchWithinParent: true,
          onlyCatalogs: onlyCatalogs,
          sortOrder: sortOrder,
          sourceType: MediaSourceType.localCopy,
        );
        await _expectAllAndPages(repository, filter, [
          'in-folder',
          'in-folder-second',
        ]);
        await _expectAllAndPages(
          repository,
          filter.copyWith(searchWithinParent: false),
          ['in-folder', 'in-folder-second', 'other-folder', 'nested'],
        );
      });
    }
  }

  for (final onlyCatalogs in [false, true]) {
    test('表示=$onlyCatalogsでも対象と範囲を別々に拡大し保護条件を保持する', () async {
      final definitions = [
        _searchCatalog('current', 'library/trip'),
        _searchCatalog('outside', 'library/home'),
        _searchCatalog('hidden', 'library/trip', hidden: true),
        _searchCatalog('archived', 'library/trip', archived: true),
        _searchCatalog('trashed', 'library/trip', trashed: true),
        _searchCatalog('external', 'library/trip', external: true),
      ];
      final plainItems = [
        MediaItem()
          ..uid = 'plain-current'
          ..path = 'library/trip/needle-plain.jpg'
          ..parentPath = 'library/trip'
          ..sourceType = MediaSourceType.localCopy,
        MediaItem()
          ..uid = 'plain-outside'
          ..path = 'library/home/needle-plain.jpg'
          ..parentPath = 'library/home'
          ..sourceType = MediaSourceType.localCopy,
      ];
      await isar.writeTxn(() async {
        for (final definition in definitions) {
          await isar.mediaCollections.put(definition.collection);
          await isar.mediaItems.put(definition.item);
          definition.collection.items.add(definition.item);
          await definition.collection.items.save();
        }
        await isar.mediaItems.putAll(plainItems);
      });

      final catalogFilter = MediaFilter(
        parentPath: 'library/trip',
        rootOnly: true,
        searchQuery: 'needle',
        searchWithinParent: true,
        searchTarget: SearchTarget.catalogsOnly,
        onlyCatalogs: onlyCatalogs,
        isHidden: false,
        isArchived: false,
        sourceType: MediaSourceType.localCopy,
      );
      await _expectAllAndPages(repository, catalogFilter, ['current']);
      final filesFilter = catalogFilter.copyWith(
        searchTarget: SearchTarget.filesIncluded,
      );
      await _expectAllAndPages(repository, filesFilter, [
        'current',
        'plain-current',
      ]);
      await _expectAllAndPages(
        repository,
        catalogFilter.copyWith(searchWithinParent: false),
        ['current', 'outside'],
      );
      await _expectAllAndPages(
        repository,
        filesFilter.copyWith(searchWithinParent: false),
        ['current', 'outside', 'plain-current', 'plain-outside'],
      );
    });
  }

  test('語を消すと残った検索範囲は通常カタログ一覧とページ取得に影響しない', () async {
    final definitions = [
      _searchCatalog('current', 'library/trip'),
      _searchCatalog('outside', 'library/home'),
    ];
    await isar.writeTxn(() async {
      await isar.mediaCollections.putAll(
        definitions.map((definition) => definition.collection).toList(),
      );
      await isar.mediaItems.putAll(
        definitions.map((definition) => definition.item).toList(),
      );
    });
    const searching = MediaFilter(
      parentPath: 'library/trip',
      rootOnly: true,
      searchQuery: 'needle',
      searchWithinParent: true,
      searchTarget: SearchTarget.catalogsOnly,
      onlyCatalogs: true,
      sourceType: MediaSourceType.localCopy,
    );
    await _expectAllAndPages(repository, searching, ['current']);
    for (final clearedQuery in [null, '   ']) {
      await _expectAllAndPages(
        repository,
        searching.copyWith(searchQuery: clearedQuery),
        ['current', 'outside'],
      );
    }
  });

  test('語を消すと残った検索範囲は外部コレクション一覧に影響しない', () async {
    final definitions = [
      _searchCatalog('current', '/external/trip', external: true),
      _searchCatalog('outside', '/external/home', external: true),
      _searchCatalog('hidden', '/external/home', external: true, hidden: true),
    ];
    await isar.writeTxn(
      () => isar.mediaCollections.putAll(
        definitions.map((definition) => definition.collection).toList(),
      ),
    );
    const searching = MediaFilter(
      parentPath: '/external/trip',
      searchQuery: 'needle',
      searchWithinParent: true,
      searchTarget: SearchTarget.catalogsOnly,
      onlyCatalogs: true,
      isHidden: false,
      sourceType: MediaSourceType.externalReference,
    );
    final current = await repository.getExternalCollections(filter: searching);
    expect(current.isSuccess, isTrue);
    expect(current.dataOrNull!.map((collection) => collection.uid), [
      'current',
    ]);
    for (final clearedQuery in [null, '   ']) {
      final all = await repository.getExternalCollections(
        filter: searching.copyWith(searchQuery: clearedQuery),
      );
      expect(all.isSuccess, isTrue);
      expect(
        all.dataOrNull!.map((collection) => collection.uid),
        unorderedEquals(['current', 'outside']),
      );
    }
  });

  test('ファイルを含む検索は一致後の順序で件数を制限する', () async {
    final items = List.generate(4, (index) {
      return MediaItem()
        ..uid = 'search-$index'
        ..path = 'library/${index == 3 ? 'other' : 'trip'}-$index.jpg'
        ..sourceType = MediaSourceType.localCopy
        ..addedAt = DateTime(2026).add(Duration(days: index));
    });
    await isar.writeTxn(() => isar.mediaItems.putAll(items));

    final result = await repository.getAll(
      filter: const MediaFilter(searchQuery: 'trip', limit: 2),
    );

    expect(result.isSuccess, isTrue);
    expect(result.dataOrNull!.map((item) => item.uid), [
      'search-2',
      'search-1',
    ]);
  });

  test('タグ名でカタログ一覧を検索できる', () async {
    final tag = Tag()
      ..key = 'facet:favorite'
      ..name = 'あとで読む';
    final collection = MediaCollection()
      ..uid = 'catalog-1'
      ..path = 'library/book.pdf'
      ..title = '技術資料'
      ..type = CollectionType.file
      ..isCatalog = true;
    final item = MediaItem()
      ..uid = 'item-1'
      ..path = collection.path
      ..sourceType = MediaSourceType.localCopy;

    await isar.writeTxn(() async {
      await isar.tags.put(tag);
      await isar.mediaCollections.put(collection);
      collection.tags.add(tag);
      await collection.tags.save();
      await isar.mediaItems.put(item);
    });

    final result = await repository.getAll(
      filter: const MediaFilter(
        onlyCatalogs: true,
        searchQuery: 'あとで',
        searchTarget: SearchTarget.catalogsOnly,
      ),
    );

    expect(result.isSuccess, isTrue);
    expect(result.dataOrNull!.map((value) => value.uid), ['item-1']);
  });

  test('検索対象に応じてカタログのみと配下ファイルを切り替えられる', () async {
    final collection = MediaCollection()
      ..uid = 'catalog-scope'
      ..path = 'library/trip'
      ..title = '沖縄旅行'
      ..type = CollectionType.folder
      ..isCatalog = true;
    final catalogItem = MediaItem()
      ..uid = 'catalog-item'
      ..path = collection.path
      ..parentPath = 'library'
      ..type = MediaType.folder
      ..sourceType = MediaSourceType.localCopy;
    final fileItem = MediaItem()
      ..uid = 'file-item'
      ..path = 'library/trip/photo.jpg'
      ..parentPath = collection.path
      ..type = MediaType.file
      ..sourceType = MediaSourceType.localCopy;

    await isar.writeTxn(() async {
      await isar.mediaCollections.put(collection);
      await isar.mediaItems.putAll([catalogItem, fileItem]);
      catalogItem.collection.value = collection;
      fileItem.collection.value = collection;
      await catalogItem.collection.save();
      await fileItem.collection.save();
    });

    final catalogsOnly = await repository.getAll(
      filter: const MediaFilter(
        searchQuery: '沖縄',
        searchTarget: SearchTarget.catalogsOnly,
      ),
    );
    final filesIncluded = await repository.getAll(
      filter: const MediaFilter(
        searchQuery: '沖縄',
        searchTarget: SearchTarget.filesIncluded,
        onlyCatalogs: true,
      ),
    );

    expect(catalogsOnly.dataOrNull!.map((value) => value.uid), [
      'catalog-item',
    ]);
    expect(filesIncluded.dataOrNull!.map((value) => value.uid).toSet(), {
      'catalog-item',
      'file-item',
    });
  });

  for (final onlyCatalogs in [false, true]) {
    test('未指定検索対象はonlyCatalogs=$onlyCatalogsでも通常ファイルを探し非表示を除く', () async {
      final visible = MediaItem()
        ..uid = 'visible-search'
        ..path = 'library/nested/travel-notes.txt'
        ..parentPath = 'library/nested'
        ..sourceType = MediaSourceType.localCopy;
      final hidden = MediaItem()
        ..uid = 'hidden-search'
        ..path = 'library/nested/travel-private.txt'
        ..parentPath = 'library/nested'
        ..sourceType = MediaSourceType.localCopy
        ..isHidden = true;
      final trashed = MediaItem()
        ..uid = 'trashed-search'
        ..path = 'library/nested/travel-trashed.txt'
        ..parentPath = 'library/nested'
        ..sourceType = MediaSourceType.localCopy
        ..isTrashed = true;
      await isar.writeTxn(
        () => isar.mediaItems.putAll([visible, hidden, trashed]),
      );

      final result = await repository.getAll(
        filter: MediaFilter(
          searchQuery: 'travel',
          onlyCatalogs: onlyCatalogs,
          rootOnly: true,
          isHidden: false,
          sourceType: MediaSourceType.localCopy,
        ),
      );
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull!.map((item) => item.uid), ['visible-search']);

      final catalogs = await repository.getAll(
        filter: MediaFilter(
          searchQuery: 'travel',
          searchTarget: SearchTarget.catalogsOnly,
          onlyCatalogs: onlyCatalogs,
          rootOnly: true,
          isHidden: false,
          sourceType: MediaSourceType.localCopy,
        ),
      );
      expect(catalogs.isSuccess, isTrue);
      expect(catalogs.dataOrNull, isEmpty);
    });
  }

  test('ルート直下の単体ファイルカタログはファイル・フォルダ表示でも取得できる', () async {
    final collection = MediaCollection()
      ..uid = 'single-file-catalog'
      ..path = 'library/book.pdf'
      ..title = '技術資料'
      ..type = CollectionType.file
      ..isCatalog = true;
    final item = MediaItem()
      ..uid = 'single-file-item'
      ..path = collection.path
      ..parentPath = 'library'
      ..type = MediaType.file
      ..sourceType = MediaSourceType.localCopy;

    await isar.writeTxn(() async {
      await isar.mediaCollections.put(collection);
      await isar.mediaItems.put(item);
    });

    final result = await repository.getAll(
      filter: const MediaFilter(
        rootOnly: true,
        sourceType: MediaSourceType.localCopy,
        mediaTypes: [MediaType.file, MediaType.folder],
      ),
    );

    expect(result.isSuccess, isTrue);
    expect(result.dataOrNull!.map((value) => value.uid), ['single-file-item']);
    expect(result.dataOrNull!.single.collection.value?.isCatalog, true);
  });

  test('カタログのみ表示でもタグありとタグなしを絞り込める', () async {
    final tag = Tag()
      ..key = 'status:tagged'
      ..name = 'タグあり';
    final taggedCollection = MediaCollection()
      ..uid = 'tagged-catalog'
      ..path = 'library/tagged'
      ..title = 'タグあり'
      ..type = CollectionType.folder
      ..isCatalog = true;
    final untaggedCollection = MediaCollection()
      ..uid = 'untagged-catalog'
      ..path = 'library/untagged'
      ..title = 'タグなし'
      ..type = CollectionType.folder
      ..isCatalog = true;
    final taggedItem = MediaItem()
      ..uid = 'tagged-item'
      ..path = taggedCollection.path
      ..type = MediaType.folder
      ..sourceType = MediaSourceType.localCopy;
    final untaggedItem = MediaItem()
      ..uid = 'untagged-item'
      ..path = untaggedCollection.path
      ..type = MediaType.folder
      ..sourceType = MediaSourceType.localCopy;

    await isar.writeTxn(() async {
      await isar.tags.put(tag);
      await isar.mediaCollections.putAll([
        taggedCollection,
        untaggedCollection,
      ]);
      taggedCollection.tags.add(tag);
      await taggedCollection.tags.save();
      await isar.mediaItems.putAll([taggedItem, untaggedItem]);
    });

    final tagged = await repository.getAll(
      filter: const MediaFilter(onlyCatalogs: true, hasTags: true),
    );
    final untagged = await repository.getAll(
      filter: const MediaFilter(onlyCatalogs: true, hasTags: false),
    );

    expect(tagged.dataOrNull!.map((item) => item.uid), ['tagged-item']);
    expect(untagged.dataOrNull!.map((item) => item.uid), ['untagged-item']);
  });

  test('外部カタログ一覧へ検索とお気に入りとタグ条件を適用できる', () async {
    final tag = Tag()
      ..key = 'external:travel'
      ..name = '旅行';
    final matching = MediaCollection()
      ..uid = 'external-matching'
      ..path = 'content://external/okinawa'
      ..title = '沖縄アルバム'
      ..type = CollectionType.externalFolder
      ..isFavorite = true
      ..tier = 4;
    final other = MediaCollection()
      ..uid = 'external-other'
      ..path = 'content://external/work'
      ..title = '仕事資料'
      ..type = CollectionType.externalFolder;

    await isar.writeTxn(() async {
      await isar.tags.put(tag);
      await isar.mediaCollections.putAll([matching, other]);
      matching.tags.add(tag);
      await matching.tags.save();
    });

    final result = await repository.getExternalCollections(
      filter: MediaFilter(
        searchQuery: '沖縄',
        isFavorite: true,
        tiers: const [4],
        tagIds: [tag.id],
        hasTags: true,
        mediaTypes: const [MediaType.folder],
      ),
    );

    expect(result.isSuccess, isTrue);
    expect(result.dataOrNull!.map((collection) => collection.uid), [
      'external-matching',
    ]);
  });
}

Future<void> _expectAllAndPages(
  IsarMediaRepository repository,
  MediaFilter filter,
  List<String> expectedUids,
) async {
  final all = await repository.getAll(filter: filter);
  expect(all.isSuccess, isTrue, reason: all.errorOrNull?.toString());
  final allUids = all.dataOrNull!.map((item) => item.uid).toList();
  expect(allUids, unorderedEquals(expectedUids));
  for (final offset in [0, 2, 4]) {
    final page = await repository.getPage(
      filter: filter,
      offset: offset,
      limit: 2,
    );
    expect(page.isSuccess, isTrue, reason: page.errorOrNull?.toString());
    expect(
      page.dataOrNull!.map((item) => item.uid),
      allUids.skip(offset).take(2),
      reason: 'offset=$offset',
    );
  }
}

({MediaCollection collection, MediaItem item}) _searchCatalog(
  String uid,
  String parentPath, {
  bool hidden = false,
  bool archived = false,
  bool trashed = false,
  bool external = false,
}) {
  final path = '$parentPath/needle-$uid';
  return (
    collection: MediaCollection()
      ..uid = uid
      ..path = path
      ..title = 'needle $uid'
      ..type = external ? CollectionType.externalFolder : CollectionType.folder
      ..isCatalog = true
      ..isHidden = hidden
      ..isArchived = archived
      ..isTrashed = trashed,
    item: MediaItem()
      ..uid = uid
      ..path = path
      ..parentPath = parentPath
      ..type = MediaType.folder
      ..sourceType = external
          ? MediaSourceType.externalReference
          : MediaSourceType.localCopy
      ..isHidden = hidden
      ..isArchived = archived
      ..isTrashed = trashed,
  );
}
