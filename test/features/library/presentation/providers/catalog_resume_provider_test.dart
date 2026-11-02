import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/data/repositories/isar_media_repository.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/presentation/providers/catalog_resume_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/secret_mode_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';

class _Repository extends Mock implements MediaRepository {}

// Test doubles inject relation read failures; production uses real Isar links.
// ignore: subtype_of_sealed_class
class _CollectionLink extends Mock implements IsarLink<MediaCollection> {}

// ignore: subtype_of_sealed_class
class _Tags extends Mock implements IsarLinks<Tag> {}

class _CollectionWithTags extends MediaCollection {
  _CollectionWithTags(this.testTags);

  final IsarLinks<Tag> testTags;

  @override
  IsarLinks<Tag> get tags => testTags;
}

class _ItemWithLink extends MediaItem {
  _ItemWithLink(this.testLink);

  final IsarLink<MediaCollection> testLink;

  @override
  IsarLink<MediaCollection> get collection => testLink;
}

class _Secret extends SecretMode {
  _Secret({this.initial = false, this.pending});

  final bool initial;
  final Completer<bool>? pending;

  @override
  FutureOr<bool> build() {
    return pending?.future ?? initial;
  }

  void replace(AsyncValue<bool> value) => state = value;
}

final _modeProvider = StateProvider((ref) => AppMode.internal);
const _request = (
  collectionId: 10,
  collectionPath: 'library/series',
  itemId: 20,
);

class _Fixture {
  _Fixture() {
    collectionsById[catalog.id] = catalog;
    collectionsByPath[catalog.path] = catalog;
    itemsById[item.id] = item;
    itemsByPath[folder.path] = folder;
    when(() => repository.getCollectionById(any())).thenAnswer(
      (invocation) async => Result.success(
        collectionsById[invocation.positionalArguments.first as int],
      ),
    );
    when(() => repository.getById(any())).thenAnswer(
      (invocation) async => Result.success(
        itemsById[invocation.positionalArguments.first as int],
      ),
    );
    when(() => repository.getByPath(any(), includeTrashed: true)).thenAnswer(
      (invocation) async => Result.success(
        itemsByPath[invocation.positionalArguments.first as String],
      ),
    );
    when(() => repository.getCollectionByPath(any())).thenAnswer(
      (invocation) async => Result.success(
        collectionsByPath[invocation.positionalArguments.first as String],
      ),
    );
    when(
      () => repository.watchLibraryChanges(filter: any(named: 'filter')),
    ).thenAnswer((_) => const Stream.empty());
  }

  final repository = _Repository();
  final catalog = MediaCollection()
    ..id = 10
    ..path = _request.collectionPath
    ..isCatalog = true
    ..lastViewedItemId = _request.itemId
    ..lastViewedAt = DateTime(2026, 10, 2, 12)
    ..updatedAt = DateTime(2026, 10, 3);
  final item = MediaItem()
    ..id = 20
    ..path = 'library/series/chapter.pdf'
    ..parentPath = _request.collectionPath;
  final folder = MediaItem()
    ..id = 30
    ..path = _request.collectionPath
    ..type = MediaType.folder
    ..parentPath = 'library';
  final itemsById = <int, MediaItem>{};
  final itemsByPath = <String, MediaItem>{};
  final collectionsById = <int, MediaCollection>{};
  final collectionsByPath = <String, MediaCollection>{};

  Future<CatalogResumeTarget?> resolve({bool includeHidden = false}) =>
      resolveCatalogResumeTarget(
        repository,
        _request,
        includeHidden: includeHidden,
      );

  CatalogResumeRequest topLevel({
    required bool fileCatalog,
    required String? parentPath,
  }) {
    if (fileCatalog) {
      item.path = 'library/chapter.pdf';
      catalog
        ..type = CollectionType.file
        ..path = item.path;
      item.parentPath = parentPath;
      collectionsByPath
        ..clear()
        ..[catalog.path] = catalog;
    } else {
      folder.parentPath = parentPath;
    }
    return (
      collectionId: catalog.id,
      collectionPath: catalog.path,
      itemId: item.id,
    );
  }

  ProviderContainer container({_Secret? secret}) => ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      mediaRepositoryProvider.overrideWith((ref) async => repository),
      secretModeProvider.overrideWith(() => secret ?? _Secret()),
      appModeProvider.overrideWith((ref) => ref.watch(_modeProvider)),
    ],
  );

  void expectOnlyReads() {
    verifyNever(() => repository.save(any()));
    verifyNever(() => repository.saveAll(any()));
    verifyNever(() => repository.saveCollection(any()));
    verifyNever(
      () => repository.updateCollectionLastViewed(
        any(),
        itemId: any(named: 'itemId'),
        viewedAt: any(named: 'viewedAt'),
      ),
    );
    verifyNever(() => repository.getByUid(any()));
    verifyNever(() => repository.getCollectionByUid(any()));
  }
}

Future<void> _settle() async {
  for (var index = 0; index < 3; index++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(const MediaFilter());
    registerFallbackValue(MediaItem());
    registerFallbackValue(<MediaItem>[]);
    registerFallbackValue(MediaCollection());
    registerFallbackValue(DateTime(2000));
  });

  group('resolveCatalogResumeTarget', () {
    late _Fixture fixture;
    setUp(() => fixture = _Fixture());
    tearDown(() => fixture.expectOnlyReads());

    test('returns the exact file and fresh catalog viewing time', () async {
      final target = await fixture.resolve();
      expect(target?.item, same(fixture.item));
      expect(target?.lastViewedAt, DateTime(2026, 10, 2, 12));
      expect(target?.lastViewedAt, isNot(fixture.catalog.updatedAt));
    });

    test(
      'ordinary folder metadata and virtual library may be absent',
      () async {
        fixture.folder.parentPath = 'library/parent';
        fixture.itemsByPath['library/parent'] = MediaItem()
          ..path = 'library/parent'
          ..type = MediaType.folder
          ..parentPath = 'library';
        expect(await fixture.resolve(), isNotNull);
      },
    );

    // RT-I-M01: CreateFolderUseCase stores top-level parentPath as null.
    for (final fileCatalog in [false, true]) {
      for (final parentPath in <String?>[null, '']) {
        final graph = '${fileCatalog ? 'file' : 'folder'} parent=$parentPath';
        test('$graph permits a virtual root without metadata', () async {
          final request = fixture.topLevel(
            fileCatalog: fileCatalog,
            parentPath: parentPath,
          );
          expect(
            await resolveCatalogResumeTarget(
              fixture.repository,
              request,
              includeHidden: false,
            ),
            isNotNull,
          );
          verify(
            () => fixture.repository.getByPath('library', includeTrashed: true),
          ).called(1);
        });

        for (final guard in [
          'item-hidden',
          'item-archived',
          'item-trashed',
          'item-missing',
          'item-external',
          'item-file',
          'collection-hidden',
          'collection-archived',
          'collection-trashed',
          'collection-external',
        ]) {
          test('$graph checks existing virtual root $guard', () async {
            final request = fixture.topLevel(
              fileCatalog: fileCatalog,
              parentPath: parentPath,
            );
            final root = MediaItem()
              ..path = 'library'
              ..type = MediaType.folder;
            final metadata = MediaCollection()..path = 'library';
            switch (guard) {
              case 'item-hidden':
                root.isHidden = true;
              case 'item-archived':
                root.isArchived = true;
              case 'item-trashed':
                root.isTrashed = true;
              case 'item-missing':
                root.isMissing = true;
              case 'item-external':
                root.sourceType = MediaSourceType.externalReference;
              case 'item-file':
                root.type = MediaType.file;
              case 'collection-hidden':
                metadata.isHidden = true;
              case 'collection-archived':
                metadata.isArchived = true;
              case 'collection-trashed':
                metadata.isTrashed = true;
              case 'collection-external':
                metadata.type = CollectionType.externalFolder;
            }
            if (guard.startsWith('item-')) {
              fixture.itemsByPath[root.path] = root;
            } else {
              fixture.collectionsByPath[metadata.path] = metadata;
            }
            expect(
              await resolveCatalogResumeTarget(
                fixture.repository,
                request,
                includeHidden: false,
              ),
              isNull,
            );
            expect(
              await resolveCatalogResumeTarget(
                fixture.repository,
                request,
                includeHidden: true,
              ),
              guard.endsWith('hidden') ? isNotNull : isNull,
            );
          });
        }
      }
    }

    test(
      'legacy null UIDs and an absent viewing time need no UID lookup',
      () async {
        fixture.catalog.lastViewedAt = null;
        expect(fixture.catalog.uid, isNull);
        expect(fixture.item.uid, isNull);
        final target = await fixture.resolve();
        expect(target?.item, same(fixture.item));
        expect(target?.lastViewedAt, isNull);
        expect(fixture.catalog.uid, isNull);
        expect(fixture.item.uid, isNull);
      },
    );

    test(
      'a missing backlink is normal; a different backlink need not match the request',
      () async {
        final target = await fixture.resolve();
        expect(target?.item.collection.value, isNull);
        final linked = MediaCollection()
          ..path = 'library/another-catalog'
          ..isCatalog = true
          ..splitSpreadView = true;
        fixture.item.collection.value = linked;
        expect((await fixture.resolve())?.item.collection.value, same(linked));
      },
    );

    for (final flag in ['hidden', 'archived', 'trashed', 'external']) {
      test('hydrated backlink $flag retains collection protection', () async {
        final linked = MediaCollection()..path = 'library/linked';
        switch (flag) {
          case 'hidden':
            linked.isHidden = true;
          case 'archived':
            linked.isArchived = true;
          case 'trashed':
            linked.isTrashed = true;
          case 'external':
            linked.type = CollectionType.externalFolder;
        }
        fixture.item.collection.value = linked;
        expect(await fixture.resolve(), isNull);
        expect(
          await fixture.resolve(includeHidden: true),
          flag == 'hidden' ? isNotNull : isNull,
        );
      });
    }

    test('attached backlink load failures propagate', () async {
      final link = _CollectionLink();
      when(() => link.isAttached).thenReturn(true);
      when(() => link.isLoaded).thenReturn(false);
      final error = StateError('backlink read failed');
      when(() => link.load()).thenThrow(error);
      fixture.itemsById[fixture.item.id] = _ItemWithLink(link)
        ..id = fixture.item.id
        ..path = fixture.item.path
        ..parentPath = fixture.item.parentPath;
      await expectLater(fixture.resolve(), throwsA(same(error)));
      verify(() => link.load()).called(1);
    });

    test('attached linked collection tag read failures propagate', () async {
      final tags = _Tags();
      when(() => tags.isAttached).thenReturn(true);
      when(() => tags.isLoaded).thenReturn(false);
      final error = StateError('linked tag read failed');
      when(() => tags.load()).thenThrow(error);
      fixture.item.collection.value = _CollectionWithTags(tags)
        ..path = fixture.item.path;
      await expectLater(fixture.resolve(), throwsA(same(error)));
      verify(() => tags.load()).called(1);
    });

    test('a file catalog requires the exact file path', () async {
      fixture.catalog
        ..type = CollectionType.file
        ..path = fixture.item.path;
      fixture.collectionsByPath
        ..clear()
        ..[fixture.catalog.path] = fixture.catalog;
      final request = (
        collectionId: fixture.catalog.id,
        collectionPath: fixture.catalog.path,
        itemId: fixture.item.id,
      );
      expect(
        await resolveCatalogResumeTarget(
          fixture.repository,
          request,
          includeHidden: false,
        ),
        isNotNull,
      );
      fixture.item.path = 'library/series/other.pdf';
      expect(
        await resolveCatalogResumeTarget(
          fixture.repository,
          request,
          includeHidden: false,
        ),
        isNull,
      );
    });

    final catalogUnavailable = <String, void Function(_Fixture)>{
      'absent': (f) => f.collectionsById.clear(),
      'different ID': (f) => f.catalog.id = 11,
      'moved path': (f) => f.catalog.path = 'library/moved',
      'unregistered': (f) => f.catalog.isCatalog = false,
      'different last item': (f) => f.catalog.lastViewedItemId = 21,
      'no last item': (f) => f.catalog.lastViewedItemId = null,
      'external': (f) => f.catalog.type = CollectionType.externalFolder,
      'hidden': (f) => f.catalog.isHidden = true,
      'archived': (f) => f.catalog.isArchived = true,
      'trashed': (f) => f.catalog.isTrashed = true,
    };
    for (final entry in catalogUnavailable.entries) {
      test('catalog ${entry.key} is unavailable', () async {
        entry.value(fixture);
        expect(await fixture.resolve(), isNull);
        verifyNever(() => fixture.repository.getById(any()));
      });
    }

    final itemUnavailable = <String, void Function(_Fixture)>{
      'absent': (f) => f.itemsById.clear(),
      'different ID': (f) => f.item.id = 21,
      'empty path': (f) => f.item.path = '',
      'moved parent': (f) => f.item.parentPath = 'library/other',
      'folder': (f) => f.item.type = MediaType.folder,
      'external': (f) => f.item.sourceType = MediaSourceType.externalReference,
      'import preview': (f) => f.item.isImportPreview = true,
      'missing': (f) => f.item.isMissing = true,
      'hidden': (f) => f.item.isHidden = true,
      'archived': (f) => f.item.isArchived = true,
      'trashed': (f) => f.item.isTrashed = true,
    };
    for (final entry in itemUnavailable.entries) {
      test('file ${entry.key} is unavailable', () async {
        entry.value(fixture);
        expect(await fixture.resolve(), isNull);
      });
    }

    final ancestorUnavailable = <String, void Function(_Fixture)>{
      'absent': (f) => f.itemsByPath.clear(),
      'different path': (f) => f.folder.path = 'library/other',
      'file type': (f) => f.folder.type = MediaType.file,
      'external': (f) =>
          f.folder.sourceType = MediaSourceType.externalReference,
      'missing': (f) => f.folder.isMissing = true,
      'hidden': (f) => f.folder.isHidden = true,
      'archived': (f) => f.folder.isArchived = true,
      'trashed': (f) => f.folder.isTrashed = true,
      'cycle': (f) => f.folder.parentPath = f.folder.path,
      'cycle through target file': (f) => f.folder.parentPath = f.item.path,
    };
    for (final entry in ancestorUnavailable.entries) {
      test('ancestor ${entry.key} is unavailable', () async {
        entry.value(fixture);
        expect(await fixture.resolve(), isNull);
      });
    }

    for (final path in ['library', 'library/series/chapter.pdf']) {
      for (final flag in ['hidden', 'archived', 'trashed', 'external']) {
        test('$path collection $flag prevents resuming', () async {
          final metadata = MediaCollection()..path = path;
          switch (flag) {
            case 'hidden':
              metadata.isHidden = true;
            case 'archived':
              metadata.isArchived = true;
            case 'trashed':
              metadata.isTrashed = true;
            case 'external':
              metadata.type = CollectionType.externalFolder;
          }
          fixture.collectionsByPath[path] = metadata;
          expect(await fixture.resolve(), isNull);
        });
      }
    }

    for (final flag in ['hidden', 'archived', 'trashed', 'missing', 'file']) {
      test('existing virtual root item $flag prevents resuming', () async {
        final root = MediaItem()
          ..path = 'library'
          ..type = MediaType.folder;
        switch (flag) {
          case 'hidden':
            root.isHidden = true;
          case 'archived':
            root.isArchived = true;
          case 'trashed':
            root.isTrashed = true;
          case 'missing':
            root.isMissing = true;
          case 'file':
            root.type = MediaType.file;
        }
        fixture.itemsByPath[root.path] = root;
        expect(await fixture.resolve(), isNull);
      });
    }

    test(
      'secret permits hidden files, ancestors and collection metadata',
      () async {
        fixture.catalog.isHidden = true;
        fixture.item.isHidden = true;
        fixture.folder.isHidden = true;
        fixture.collectionsByPath['library'] = MediaCollection()
          ..path = 'library'
          ..isHidden = true;
        fixture.collectionsByPath[fixture.item.path] = MediaCollection()
          ..path = fixture.item.path
          ..isHidden = true;
        expect(await fixture.resolve(includeHidden: true), isNotNull);
        fixture.folder.isMissing = true;
        expect(await fixture.resolve(includeHidden: true), isNull);
      },
    );

    for (final read in ['catalog', 'item', 'parent', 'metadata']) {
      test(
        '$read read failure propagates instead of becoming absence',
        () async {
          final error = AppError.database('$read read failed');
          switch (read) {
            case 'catalog':
              when(
                () => fixture.repository.getCollectionById(any()),
              ).thenAnswer((_) async => Result.failure(error));
            case 'item':
              when(
                () => fixture.repository.getById(any()),
              ).thenAnswer((_) async => Result.failure(error));
            case 'parent':
              when(
                () => fixture.repository.getByPath(any(), includeTrashed: true),
              ).thenAnswer((_) async => Result.failure(error));
            case 'metadata':
              when(
                () => fixture.repository.getCollectionByPath(any()),
              ).thenAnswer((_) async => Result.failure(error));
          }
          await expectLater(fixture.resolve(), throwsA(same(error)));
        },
      );
    }
  });

  group('catalogResumeTargetProvider', () {
    late _Fixture fixture;
    late ProviderContainer container;
    final provider = catalogResumeTargetProvider(_request);
    setUp(() => fixture = _Fixture());

    void keepAlive({_Secret? secret}) {
      container = fixture.container(secret: secret);
      addTearDown(container.dispose);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
    }

    test(
      'watches all hidden/archive states and resolves changes afresh',
      () async {
        final changes = StreamController<void>.broadcast();
        addTearDown(changes.close);
        when(
          () => fixture.repository.watchLibraryChanges(
            filter: any(named: 'filter'),
          ),
        ).thenAnswer((invocation) {
          final filter = invocation.namedArguments[#filter] as MediaFilter;
          expect(filter.isHidden, isNull);
          expect(filter.isArchived, isNull);
          expect(filter.parentPath, isNull);
          expect(filter.sourceType, isNull);
          return changes.stream;
        });
        keepAlive();
        expect(await container.read(provider.future), isNotNull);
        fixture.folder.isArchived = true;
        changes.add(null);
        await _settle();
        expect(await container.read(provider.future), isNull);
        fixture.folder.isArchived = false;
        changes.add(null);
        await _settle();
        expect(await container.read(provider.future), isNotNull);
      },
    );

    test('read failure surfaces and explicit retry can recover', () async {
      final error = AppError.database('initial read failed');
      when(
        () => fixture.repository.getById(any()),
      ).thenAnswer((_) async => Result.failure(error));
      keepAlive();
      await expectLater(container.read(provider.future), throwsA(same(error)));
      expect(container.read(provider).error, same(error));
      when(
        () => fixture.repository.getById(any()),
      ).thenAnswer((_) async => Result.success(fixture.item));
      container.invalidate(provider);
      expect(await container.read(provider.future), isNotNull);
    });

    test(
      'RT-I-V03 watch error stays after final read wins but before data publication',
      () async {
        final changes = StreamController<void>.broadcast(sync: true);
        addTearDown(changes.close);
        final rootRead = Completer<Result<MediaCollection?, AppError>>.sync();
        when(
          () => fixture.repository.watchLibraryChanges(
            filter: any(named: 'filter'),
          ),
        ).thenAnswer((_) => changes.stream);
        when(
          () => fixture.repository.getCollectionByPath('library'),
        ).thenAnswer((_) => rootRead.future);
        keepAlive();
        final states = <AsyncValue<CatalogResumeTarget?>>[];
        final observer = container.listen(
          provider,
          (_, value) => states.add(value),
        );
        addTearDown(observer.close);
        // Observe both possible outcomes of the initial future; the final
        // published state must retain the watch error in either ordering.
        final initial = container
            .read(provider.future)
            .then<void>((_) {}, onError: (Object _, StackTrace _) {});
        await _settle();
        verify(
          () => fixture.repository.getCollectionByPath('library'),
        ).called(1);
        final error = StateError('watch failed at publication boundary');
        rootRead.complete(Result.success(null));
        scheduleMicrotask(() => changes.addError(error, StackTrace.current));
        await initial;
        await _settle();
        expect(states.any((value) => value.hasError), isTrue);
        expect(container.read(provider).hasError, isTrue);
        expect(container.read(provider).error, same(error));
        changes.add(null);
        await _settle();
        expect(container.read(provider).error, same(error));
      },
    );

    test(
      'watch error defeats a delayed read and remains until retry',
      () async {
        final changes = StreamController<void>.broadcast();
        addTearDown(changes.close);
        final pending = Completer<Result<MediaItem?, AppError>>();
        when(
          () => fixture.repository.watchLibraryChanges(
            filter: any(named: 'filter'),
          ),
        ).thenAnswer((_) => changes.stream);
        when(
          () => fixture.repository.getById(any()),
        ).thenAnswer((_) => pending.future);
        keepAlive();
        final initial = container.read(provider.future);
        final error = StateError('watch failed');
        final initialError = expectLater(initial, throwsA(same(error)));
        await _settle();
        changes.addError(error, StackTrace.current);
        await initialError;
        expect(container.read(provider).error, same(error));
        pending.complete(Result.success(fixture.item));
        changes.add(null);
        await _settle();
        expect(container.read(provider).error, same(error));
        verify(() => fixture.repository.getById(any())).called(1);
        when(
          () => fixture.repository.getById(any()),
        ).thenAnswer((_) async => Result.success(fixture.item));
        container.invalidate(provider);
        expect(await container.read(provider.future), isNotNull);
      },
    );

    test('watch error after successful resolution replaces old data', () async {
      final changes = StreamController<void>.broadcast();
      addTearDown(changes.close);
      when(
        () => fixture.repository.watchLibraryChanges(
          filter: any(named: 'filter'),
        ),
      ).thenAnswer((_) => changes.stream);
      keepAlive();
      expect(await container.read(provider.future), isNotNull);
      final error = StateError('late watch failure');
      changes.addError(error, StackTrace.current);
      await _settle();
      expect(container.read(provider).hasError, isTrue);
      expect(container.read(provider).error, same(error));
      changes.add(null);
      await _settle();
      expect(container.read(provider).error, same(error));
    });

    test(
      'secret loading/error hide targets until a known current value',
      () async {
        final pending = Completer<bool>();
        final secret = _Secret(pending: pending);
        fixture.item.isHidden = true;
        keepAlive(secret: secret);
        expect(await container.read(provider.future), isNull);
        verifyNever(() => fixture.repository.getById(any()));
        pending.complete(true);
        await _settle();
        expect(await container.read(provider.future), isNotNull);
        secret.replace(
          AsyncError(StateError('secret unavailable'), StackTrace.current),
        );
        expect(await container.read(provider.future), isNull);
        secret.replace(const AsyncData(false));
        expect(await container.read(provider.future), isNull);
      },
    );

    test(
      'secret refresh with old true value conservatively hides the file',
      () async {
        final secret = _Secret(initial: true);
        fixture.item.isHidden = true;
        keepAlive(secret: secret);
        expect(await container.read(provider.future), isNotNull);
        secret.replace(
          // Preserve the stale-data refresh fixture, not just empty loading.
          // ignore: invalid_use_of_internal_member
          const AsyncLoading<bool>().copyWithPrevious(const AsyncData(true)),
        );
        expect(await container.read(provider.future), isNull);
      },
    );

    test(
      'mode change discards a delayed read, including return to internal',
      () async {
        final pending = Completer<Result<MediaItem?, AppError>>();
        when(
          () => fixture.repository.getById(any()),
        ).thenAnswer((_) => pending.future);
        keepAlive();
        await _settle();
        container.read(_modeProvider.notifier).state = AppMode.external;
        expect(await container.read(provider.future), isNull);
        pending.complete(Result.success(fixture.item));
        await _settle();
        expect(container.read(provider).value, isNull);
        when(
          () => fixture.repository.getById(any()),
        ).thenAnswer((_) async => Result.success(fixture.item));
        container.read(_modeProvider.notifier).state = AppMode.internal;
        expect(await container.read(provider.future), isNotNull);
      },
    );

    test('secret change discards a delayed hidden target', () async {
      final pending = Completer<Result<MediaItem?, AppError>>();
      final secret = _Secret(initial: true);
      fixture.item.isHidden = true;
      when(
        () => fixture.repository.getById(any()),
      ).thenAnswer((_) => pending.future);
      keepAlive(secret: secret);
      await _settle();
      secret.replace(const AsyncData(false));
      pending.complete(Result.success(fixture.item));
      await _settle();
      expect(await container.read(provider.future), isNull);
    });

    test('dispose cancels subscription and ignores delayed results', () async {
      var canceled = false;
      final changes = StreamController<void>.broadcast(
        onCancel: () => canceled = true,
      );
      addTearDown(changes.close);
      final pending = Completer<Result<MediaItem?, AppError>>();
      when(
        () => fixture.repository.watchLibraryChanges(
          filter: any(named: 'filter'),
        ),
      ).thenAnswer((_) => changes.stream);
      when(
        () => fixture.repository.getById(any()),
      ).thenAnswer((_) => pending.future);
      keepAlive();
      await _settle();
      container.dispose();
      expect(canceled, isTrue);
      pending.complete(Result.success(fixture.item));
      changes.addError(StateError('after disposal'));
      await _settle();
      fixture.expectOnlyReads();
    });
  });

  group('real Isar catalog resume graph', () {
    late Directory directory;
    late Isar isar;
    late IsarMediaRepository repository;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('catalog_resume_');
      isar = await Isar.open(
        [
          MediaItemSchema,
          MediaCollectionSchema,
          TagSchema,
          TagFacetSchema,
          StorageRefSchema,
        ],
        directory: directory.path,
        name: 'catalog_resume_${DateTime.now().microsecondsSinceEpoch}',
      );
      repository = IsarMediaRepository(isar);
    });
    tearDown(() async {
      if (isar.isOpen) await isar.close();
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    test(
      'hydrates the file catalog backlink, split preference and tags for the viewer',
      () async {
        final folder = MediaItem()
          ..uid = 'hydrated-parent'
          ..path = 'library/series'
          ..type = MediaType.folder
          ..parentPath = null;
        final item = MediaItem()
          ..uid = 'hydrated-image'
          ..path = 'library/series/image.jpg'
          ..parentPath = folder.path;
        final catalog = MediaCollection()
          ..uid = 'hydrated-file-catalog'
          ..path = item.path
          ..type = CollectionType.file
          ..isCatalog = true
          ..splitSpreadView = true
          ..lastViewedAt = DateTime(2026, 10, 2);
        final tag = Tag()
          ..key = 'hydrated::favorite'
          ..name = 'Favorite scenes';
        await isar.writeTxn(() async {
          await isar.mediaItems.putAll([folder, item]);
          catalog.lastViewedItemId = item.id;
          await isar.mediaCollections.put(catalog);
          await isar.tags.put(tag);
          catalog.items.add(item);
          await catalog.items.save();
          catalog.tags.add(tag);
          await catalog.tags.save();
        });
        final target = await resolveCatalogResumeTarget(repository, (
          collectionId: catalog.id,
          collectionPath: catalog.path,
          itemId: item.id,
        ), includeHidden: false);
        expect(target, isNotNull);
        expect(target!.item.collection.isLoaded, isTrue);
        final linked = target.item.collection.value;
        expect(linked?.id, catalog.id);
        expect(linked?.path, item.path);
        expect(linked?.splitSpreadView, isTrue);
        expect(linked?.tags.isLoaded, isTrue);
        expect(linked?.tags.map((tag) => tag.name), ['Favorite scenes']);
        expect(
          (await isar.mediaCollections.get(catalog.id))?.lastViewedAt,
          DateTime(2026, 10, 2),
        );
      },
    );

    test(
      'normal folder without parent metadata resolves a legacy target and catalog',
      () async {
        final parent = MediaItem()
          ..uid = 'plain-parent'
          ..path = 'library/plain'
          ..parentPath = null
          ..type = MediaType.folder;
        final folder = MediaItem()
          ..uid = 'series-folder'
          ..path = 'library/plain/series'
          ..parentPath = parent.path
          ..type = MediaType.folder;
        final item = MediaItem()
          ..path = 'library/plain/series/chapter.pdf'
          ..parentPath = folder.path;
        final catalog = MediaCollection()
          ..path = folder.path
          ..isCatalog = true
          ..lastViewedAt = DateTime(2026, 10, 2);
        await isar.writeTxn(() async {
          await isar.mediaItems.putAll([parent, folder, item]);
          catalog.lastViewedItemId = item.id;
          await isar.mediaCollections.put(catalog);
        });
        // A unique nullable UID index replaces another null-UID item, so only
        // the target is a legacy null-UID row in this persisted fixture.
        expect(await isar.mediaItems.count(), 3);
        final request = (
          collectionId: catalog.id,
          collectionPath: catalog.path,
          itemId: item.id,
        );
        final target = await resolveCatalogResumeTarget(
          repository,
          request,
          includeHidden: false,
        );
        expect(target?.item.id, item.id);
        expect(target?.lastViewedAt, DateTime(2026, 10, 2));
        expect(await isar.mediaCollections.count(), 1);
        expect((await isar.mediaCollections.get(catalog.id))?.uid, isNull);
        expect((await isar.mediaItems.get(item.id))?.uid, isNull);
      },
    );

    for (final fileCatalog in [false, true]) {
      for (final guard in [
        'none',
        'item-hidden',
        'item-trashed',
        'collection-hidden',
      ]) {
        test(
          'top-level ${fileCatalog ? 'file' : 'folder'} with null parent checks root $guard',
          () async {
            final folder = MediaItem()
              ..uid = 'top-level-folder'
              ..path = 'library/series'
              ..type = MediaType.folder
              ..parentPath = null;
            final item = MediaItem()
              ..path = fileCatalog
                  ? 'library/chapter.pdf'
                  : '${folder.path}/chapter.pdf'
              ..parentPath = fileCatalog ? null : folder.path;
            final catalog = MediaCollection()
              ..path = fileCatalog ? item.path : folder.path
              ..type = fileCatalog ? CollectionType.file : CollectionType.folder
              ..isCatalog = true;
            final root = MediaItem()
              ..uid = 'top-level-virtual-root'
              ..path = 'library'
              ..type = MediaType.folder
              ..isHidden = guard == 'item-hidden'
              ..isTrashed = guard == 'item-trashed';
            final rootMetadata = MediaCollection()
              ..uid = 'top-level-root-metadata'
              ..path = 'library'
              ..isHidden = guard == 'collection-hidden';
            await isar.writeTxn(() async {
              await isar.mediaItems.putAll([
                if (!fileCatalog) folder,
                if (guard.startsWith('item-')) root,
                item,
              ]);
              if (guard.startsWith('collection-')) {
                await isar.mediaCollections.put(rootMetadata);
              }
              catalog.lastViewedItemId = item.id;
              await isar.mediaCollections.put(catalog);
            });
            expect(
              await isar.mediaItems.count(),
              1 + (fileCatalog ? 0 : 1) + (guard.startsWith('item-') ? 1 : 0),
            );
            final request = (
              collectionId: catalog.id,
              collectionPath: catalog.path,
              itemId: item.id,
            );
            expect(
              await resolveCatalogResumeTarget(
                repository,
                request,
                includeHidden: false,
              ),
              guard == 'none' ? isNotNull : isNull,
            );
            expect(
              await resolveCatalogResumeTarget(
                repository,
                request,
                includeHidden: true,
              ),
              guard == 'item-trashed' ? isNull : isNotNull,
            );
          },
        );
      }
    }

    for (final trashed in [false, true]) {
      test(
        'existing virtual library root ${trashed ? 'trash' : 'hidden'} protection blocks the real graph',
        () async {
          final root = MediaItem()
            ..uid = 'virtual-library-root'
            ..path = 'library'
            ..type = MediaType.folder
            ..isHidden = !trashed
            ..isTrashed = trashed;
          final item = MediaItem()
            ..path = 'library/chapter.pdf'
            ..parentPath = 'library';
          final catalog = MediaCollection()
            ..path = item.path
            ..type = CollectionType.file
            ..isCatalog = true;
          await isar.writeTxn(() async {
            await isar.mediaItems.putAll([root, item]);
            catalog.lastViewedItemId = item.id;
            await isar.mediaCollections.put(catalog);
          });
          expect(await isar.mediaItems.count(), 2);
          expect((await isar.mediaItems.get(root.id))?.isTrashed, trashed);
          final request = (
            collectionId: catalog.id,
            collectionPath: catalog.path,
            itemId: item.id,
          );
          expect(
            await resolveCatalogResumeTarget(
              repository,
              request,
              includeHidden: false,
            ),
            isNull,
          );
          expect(
            await resolveCatalogResumeTarget(
              repository,
              request,
              includeHidden: true,
            ),
            trashed ? isNull : isNotNull,
          );
        },
      );
    }
  });
}
