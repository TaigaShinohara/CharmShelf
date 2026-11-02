import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';

class MockMediaRepository extends Mock implements MediaRepository {}

void main() {
  late MockMediaRepository mockRepository;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(MediaCollection());
    registerFallbackValue(MediaItem());
  });

  setUp(() {
    mockRepository = MockMediaRepository();
    when(
      () => mockRepository.getExternalCollections(filter: any(named: 'filter')),
    ).thenAnswer((_) async => Result.success(<MediaCollection>[]));
    when(
      () => mockRepository.getAll(filter: any(named: 'filter')),
    ).thenAnswer((_) async => Result.success(<MediaItem>[]));
    when(
      () => mockRepository.watchAll(filter: any(named: 'filter')),
    ).thenAnswer((_) => Stream.value(<MediaItem>[]));
    container = ProviderContainer(
      overrides: [
        mediaRepositoryProvider.overrideWith(
          (ref) => Future.value(mockRepository),
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('CollectionNotifier', () {
    const testPath = '/test/folder';

    test('togglePin でピン留め状態が反転し、updatedAt が更新されること', () async {
      final initialCollection = MediaCollection()
        ..path = testPath
        ..title = 'folder'
        ..isPinned = false
        ..updatedAt = DateTime(2020);

      when(
        () => mockRepository.getCollectionByPath(testPath),
      ).thenAnswer((_) async => Result.success(initialCollection));
      when(
        () => mockRepository.saveCollection(any()),
      ).thenAnswer((_) async => Result.success(null));

      final notifier = container.read(
        collectionNotifierProvider(testPath).notifier,
      );
      await container.read(collectionNotifierProvider(testPath).future);

      await notifier.togglePin();

      final updated = container
          .read(collectionNotifierProvider(testPath))
          .value;
      expect(updated, isNotNull);
      expect(updated!.isPinned, isTrue);
      expect(updated.updatedAt.isAfter(DateTime(2020)), isTrue);
      verify(() => mockRepository.saveCollection(any())).called(1);
    });

    test('toggleFavorite でお気に入り状態が反転し、updatedAt が更新されること', () async {
      final initialCollection = MediaCollection()
        ..path = testPath
        ..title = 'folder'
        ..isFavorite = false
        ..updatedAt = DateTime(2020);

      when(
        () => mockRepository.getCollectionByPath(testPath),
      ).thenAnswer((_) async => Result.success(initialCollection));
      when(
        () => mockRepository.saveCollection(any()),
      ).thenAnswer((_) async => Result.success(null));

      final notifier = container.read(
        collectionNotifierProvider(testPath).notifier,
      );
      await container.read(collectionNotifierProvider(testPath).future);

      await notifier.toggleFavorite();

      final updated = container
          .read(collectionNotifierProvider(testPath))
          .value;
      expect(updated, isNotNull);
      expect(updated!.isFavorite, isTrue);
      expect(updated.updatedAt.isAfter(DateTime(2020)), isTrue);
      verify(() => mockRepository.saveCollection(any())).called(1);
    });

    test('updateAlias で別名が更新され、サニタイズおよびupdatedAtが更新されること', () async {
      final initialCollection = MediaCollection()
        ..path = testPath
        ..title = 'folder'
        ..alias = null
        ..updatedAt = DateTime(2020);

      when(
        () => mockRepository.getCollectionByPath(testPath),
      ).thenAnswer((_) async => Result.success(initialCollection));
      when(
        () => mockRepository.saveCollection(any()),
      ).thenAnswer((_) async => Result.success(null));

      final notifier = container.read(
        collectionNotifierProvider(testPath).notifier,
      );
      await container.read(collectionNotifierProvider(testPath).future);

      await notifier.updateAlias('  新しい別名  ');

      final updated = container
          .read(collectionNotifierProvider(testPath))
          .value;
      expect(updated, isNotNull);
      expect(updated!.alias, '新しい別名');
      expect(updated.updatedAt.isAfter(DateTime(2020)), isTrue);
      verify(() => mockRepository.saveCollection(any())).called(1);
    });

    test('updateNotes でノートが更新され、updatedAtが更新されること', () async {
      final initialCollection = MediaCollection()
        ..path = testPath
        ..title = 'folder'
        ..notes = null
        ..updatedAt = DateTime(2020);

      when(
        () => mockRepository.getCollectionByPath(testPath),
      ).thenAnswer((_) async => Result.success(initialCollection));
      when(
        () => mockRepository.saveCollection(any()),
      ).thenAnswer((_) async => Result.success(null));

      final noteUpdates = <String?>[];
      final subscription = container.listen(
        collectionNotifierProvider(testPath),
        (_, next) {
          if (next.hasValue) noteUpdates.add(next.value?.notes);
        },
      );
      addTearDown(subscription.close);
      final notifier = container.read(
        collectionNotifierProvider(testPath).notifier,
      );
      await container.read(collectionNotifierProvider(testPath).future);

      await notifier.updateNotes('テストノート');

      final updated = container
          .read(collectionNotifierProvider(testPath))
          .value;
      expect(updated, isNotNull);
      expect(updated!.notes, 'テストノート');
      expect(noteUpdates, [null, 'テストノート']);
      expect(updated.updatedAt.isAfter(DateTime(2020)), isTrue);
      verify(() => mockRepository.saveCollection(any())).called(1);
    });

    test('updateTier でティアが更新され、updatedAtが更新されること', () async {
      final initialCollection = MediaCollection()
        ..path = testPath
        ..title = 'folder'
        ..tier = 0
        ..updatedAt = DateTime(2020);

      when(
        () => mockRepository.getCollectionByPath(testPath),
      ).thenAnswer((_) async => Result.success(initialCollection));
      when(
        () => mockRepository.saveCollection(any()),
      ).thenAnswer((_) async => Result.success(null));

      final notifier = container.read(
        collectionNotifierProvider(testPath).notifier,
      );
      await container.read(collectionNotifierProvider(testPath).future);

      await notifier.updateTier(MediaTier.s);

      final updated = container
          .read(collectionNotifierProvider(testPath))
          .value;
      expect(updated, isNotNull);
      expect(updated!.tier, MediaTier.s.value);
      expect(updated.updatedAt.isAfter(DateTime(2020)), isTrue);
      verify(() => mockRepository.saveCollection(any())).called(1);
    });

    test('カタログ化時の自動表紙は直下のアイテムからのみ選ぶ', () async {
      final initialCollection = MediaCollection()
        ..path = testPath
        ..title = 'folder'
        ..type = CollectionType.folder
        ..isCatalog = false;
      final directChild = MediaItem()
        ..path = '$testPath/direct.jpg'
        ..parentPath = testPath
        ..type = MediaType.file;

      when(
        () => mockRepository.getCollectionByPath(testPath),
      ).thenAnswer((_) async => Result.success(initialCollection));
      when(
        () => mockRepository.getByParentPath(testPath),
      ).thenAnswer((_) async => Result.success([directChild]));
      when(
        () => mockRepository.saveCollection(any()),
      ).thenAnswer((_) async => Result.success(null));

      final notifier = container.read(
        collectionNotifierProvider(testPath).notifier,
      );
      await container.read(collectionNotifierProvider(testPath).future);

      await notifier.catalogify();

      final updated = container
          .read(collectionNotifierProvider(testPath))
          .value;
      expect(updated?.coverImagePath, directChild.path);
      verify(() => mockRepository.getByParentPath(testPath)).called(1);
      verifyNever(() => mockRepository.getDescendants(testPath));
    });

    test('カタログ解除は通常フォルダ状態を保存する', () async {
      final collection = MediaCollection()
        ..id = 42
        ..path = testPath
        ..isCatalog = true
        ..isPinned = true
        ..coverImagePath = 'cover.jpg';
      final saved = MediaCollection()
        ..id = collection.id
        ..path = testPath
        ..isCatalog = false
        ..isPinned = false;
      when(
        () => mockRepository.getCollectionByPath(testPath),
      ).thenAnswer((_) async => Result.success(collection));
      when(
        () => mockRepository.decatalogifyCollection(collection.id),
      ).thenAnswer((_) async => Result.success(saved));

      final notifier = container.read(
        collectionNotifierProvider(testPath).notifier,
      );
      await container.read(collectionNotifierProvider(testPath).future);
      await notifier.decatalogify();

      expect(
        container.read(collectionNotifierProvider(testPath)).value,
        same(saved),
      );
      verify(
        () => mockRepository.decatalogifyCollection(collection.id),
      ).called(1);
      verifyNever(() => mockRepository.saveCollection(any()));
      verifyNever(() => mockRepository.syncTagsOnCollection(any(), any()));
      verifyNever(() => mockRepository.deleteCollection(any()));
    });

    test('登録解除失敗は表示中の登録情報とタグを保持し、同じ操作を再試行できる', () async {
      final tag = Tag()
        ..id = 7
        ..name = 'trip'
        ..usageCount = 1;
      final current = MediaCollection()
        ..id = 42
        ..path = testPath
        ..isCatalog = true
        ..isPinned = true
        ..tier = MediaTier.a.value
        ..coverImagePath = 'cover.jpg'
        ..notes = 'keep this note'
        ..alias = 'display name'
        ..isFavorite = true
        ..updatedAt = DateTime(2020);
      current.tags.add(tag);
      when(
        () => mockRepository.getCollectionByPath(testPath),
      ).thenAnswer((_) async => Result.success(current));
      final failure = AppError.database('commit failed');
      when(
        () => mockRepository.decatalogifyCollection(current.id),
      ).thenAnswer((_) async => Result.failure(failure));
      final notifier = container.read(
        collectionNotifierProvider(testPath).notifier,
      );
      await container.read(collectionNotifierProvider(testPath).future);

      await expectLater(notifier.decatalogify(), throwsA(same(failure)));
      expect(
        container.read(collectionNotifierProvider(testPath)).value,
        same(current),
      );
      expect(current.isCatalog, isTrue);
      expect(current.isPinned, isTrue);
      expect(current.tier, MediaTier.a.value);
      expect(current.coverImagePath, 'cover.jpg');
      expect(current.updatedAt, DateTime(2020));
      expect(current.tags.isChanged, isTrue);
      expect(tag.usageCount, 1);
      expect(current.notes, 'keep this note');
      expect(current.alias, 'display name');
      expect(current.isFavorite, isTrue);

      final saved = MediaCollection()
        ..id = current.id
        ..path = current.path;
      when(
        () => mockRepository.decatalogifyCollection(current.id),
      ).thenAnswer((_) async => Result.success(saved));
      await notifier.decatalogify();
      expect(
        container.read(collectionNotifierProvider(testPath)).value,
        same(saved),
      );
      verify(() => mockRepository.decatalogifyCollection(current.id)).called(2);
      verifyNever(() => mockRepository.saveCollection(any()));
      verifyNever(() => mockRepository.syncTagsOnCollection(any(), any()));
    });

    test('saveCollection 失敗時に例外がスローされること', () async {
      final initialCollection = MediaCollection()
        ..path = testPath
        ..title = 'folder'
        ..isFavorite = false;

      when(
        () => mockRepository.getCollectionByPath(testPath),
      ).thenAnswer((_) async => Result.success(initialCollection));
      when(() => mockRepository.saveCollection(any())).thenAnswer(
        (_) async => Result.failure(AppError.database('Failed to save')),
      );

      final notifier = container.read(
        collectionNotifierProvider(testPath).notifier,
      );
      await container.read(collectionNotifierProvider(testPath).future);

      expect(() => notifier.toggleFavorite(), throwsA(isA<AppError>()));
    });
  });
}
