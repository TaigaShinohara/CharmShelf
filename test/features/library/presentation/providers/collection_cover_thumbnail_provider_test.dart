import 'dart:io';
import 'dart:async';
import 'package:private_shelf/features/library/presentation/providers/collection_cover_revision_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_cover_thumbnail_provider.dart';

class MockMediaRepository extends Mock implements MediaRepository {}

void main() {
  late MockMediaRepository mockRepository;
  late Directory tempDir;
  late ProviderContainer container;
  late StreamController<int> revisions;

  setUpAll(() {
    registerFallbackValue(MediaCollection());
    registerFallbackValue(MediaItem());
  });

  setUp(() async {
    mockRepository = MockMediaRepository();
    tempDir = await Directory.systemTemp.createTemp('collection_cover_test');

    revisions = StreamController<int>.broadcast();
    container = ProviderContainer(
      overrides: [
        collectionCoverRevisionProvider.overrideWith(
          (ref, path) => revisions.stream,
        ),
        mediaRepositoryProvider.overrideWith(
          (ref) => Future.value(mockRepository),
        ),
        appDocumentsPathSyncProvider.overrideWith((ref) => tempDir.path),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await revisions.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('collectionCoverThumbnailProvider', () {
    test('表紙なしも再表示で再利用し、変更通知で再探索する', () async {
      final collection = MediaCollection()..path = 'empty';
      when(
        () => mockRepository.getByPath('empty'),
      ).thenAnswer((_) async => Result.success(null));
      when(
        () => mockRepository.getCoverCandidates('empty'),
      ).thenAnswer((_) async => Result.success([]));
      final provider = collectionCoverThumbnailProvider(collection);
      final first = container.listen(provider, (_, _) {});
      expect(await container.read(provider.future), isNull);
      first.close();
      await container.pump();
      final second = container.listen(provider, (_, _) {});
      addTearDown(second.close);
      expect(await container.read(provider.future), isNull);
      verify(() => mockRepository.getCoverCandidates('empty')).called(1);
      revisions.add(1);
      await container.pump();
      expect(await container.read(provider.future), isNull);
      verify(() => mockRepository.getCoverCandidates('empty')).called(1);
    });

    test('一時的な取得エラーを表紙なしとして保持しない', () async {
      final collection = MediaCollection()..path = 'retry';
      when(
        () => mockRepository.getByPath('retry'),
      ).thenThrow(StateError('temporary'));
      final provider = collectionCoverThumbnailProvider(collection);
      final first = container.listen(provider, (_, _) {});
      await expectLater(container.read(provider.future), throwsStateError);
      first.close();
      await container.pump();
      when(
        () => mockRepository.getByPath('retry'),
      ).thenAnswer((_) async => Result.success(null));
      when(
        () => mockRepository.getCoverCandidates('retry'),
      ).thenAnswer((_) async => Result.success([]));
      final second = container.listen(provider, (_, _) {});
      addTearDown(second.close);
      expect(await container.read(provider.future), isNull);
    });

    test('再表示では探索を再利用し、配下変更時にだけ再探索する', () async {
      final file = File('${tempDir.path}/first.jpg');
      await file.writeAsString('image');
      final item = MediaItem()..path = 'first.jpg';
      final collection = MediaCollection()..path = 'catalog';
      when(
        () => mockRepository.getByPath('catalog'),
      ).thenAnswer((_) async => Result.success(null));
      when(
        () => mockRepository.getCoverCandidates('catalog'),
      ).thenAnswer((_) async => Result.success([item]));
      final provider = collectionCoverThumbnailProvider(collection);
      final listener = container.listen(provider, (_, _) {});
      await container.read(provider.future);
      listener.close();
      await container.pump();
      final again = container.listen(provider, (_, _) {});
      addTearDown(again.close);
      await container.read(provider.future);
      verify(() => mockRepository.getCoverCandidates('catalog')).called(1);
      revisions.add(1);
      await container.pump();
      await container.read(provider.future);
      verify(() => mockRepository.getCoverCandidates('catalog')).called(1);
    });

    test('coverImagePathが存在する場合はそのパスを返すこと', () async {
      final coverFile = File('${tempDir.path}/covers/test.jpg');
      await coverFile.parent.create(recursive: true);
      await coverFile.writeAsString('fake image bytes');

      final collection = MediaCollection()
        ..path = 'folder/test'
        ..coverImagePath = 'covers/test.jpg';

      final result = await container.read(
        collectionCoverThumbnailProvider(collection).future,
      );

      expect(result, isA<FileCoverData>());
      expect((result! as FileCoverData).relativePath, 'covers/test.jpg');
    });

    test('coverImagePathがnullで単体ファイルカタログの場合、そのアイテムのサムネイル/画像パスを返すこと', () async {
      final thumbFile = File('${tempDir.path}/.thumbnails/movie_thumb.jpg');
      await thumbFile.parent.create(recursive: true);
      await thumbFile.writeAsString('fake thumb bytes');

      final item = MediaItem()
        ..id = 10
        ..path = 'library/video.mp4'
        ..type = MediaType.file
        ..sourceType = MediaSourceType.localCopy
        ..thumbnailPath = '.thumbnails/movie_thumb.jpg';

      when(
        () => mockRepository.getByPath('library/video.mp4'),
      ).thenAnswer((_) async => Result.success(item));

      final collection = MediaCollection()
        ..path = 'library/video.mp4'
        ..type = CollectionType.file;

      final result = await container.read(
        collectionCoverThumbnailProvider(collection).future,
      );

      expect(result, isA<FileCoverData>());
      expect(
        (result! as FileCoverData).relativePath,
        '.thumbnails/movie_thumb.jpg',
      );
    });

    test(
      'coverImagePathがnullのフォルダカタログの場合、配下アイテムを自然順ソートして先頭の画像にフォールバックすること',
      () async {
        final imgFile1 = File('${tempDir.path}/folder/test/01_first.jpg');
        await imgFile1.parent.create(recursive: true);
        await imgFile1.writeAsString('fake photo bytes 1');

        final imgFile2 = File('${tempDir.path}/folder/test/02_second.jpg');
        await imgFile2.parent.create(recursive: true);
        await imgFile2.writeAsString('fake photo bytes 2');

        final childItem2 = MediaItem()
          ..id = 102
          ..path = 'folder/test/02_second.jpg'
          ..sourceType = MediaSourceType.localCopy
          ..type = MediaType.file;

        final childItem1 = MediaItem()
          ..id = 101
          ..path = 'folder/test/01_first.jpg'
          ..sourceType = MediaSourceType.localCopy
          ..type = MediaType.file;

        when(
          () => mockRepository.getByPath('folder/test'),
        ).thenAnswer((_) async => Result.success(null));
        // 配下アイテムが順不同（02が先）で返ってきた場合でもソートされること
        when(
          () => mockRepository.getCoverCandidates('folder/test'),
        ).thenAnswer((_) async => Result.success([childItem2, childItem1]));

        final collection = MediaCollection()
          ..path = 'folder/test'
          ..type = CollectionType.folder;

        final result = await container.read(
          collectionCoverThumbnailProvider(collection).future,
        );

        expect(result, isA<FileCoverData>());
        expect(
          (result! as FileCoverData).relativePath,
          'folder/test/01_first.jpg',
        );
      },
    );

    test('配下アイテムがない場合はnullを返すこと', () async {
      when(
        () => mockRepository.getByPath('folder/empty'),
      ).thenAnswer((_) async => Result.success(null));
      when(
        () => mockRepository.getCoverCandidates('folder/empty'),
      ).thenAnswer((_) async => Result.success([]));

      final collection = MediaCollection()
        ..path = 'folder/empty'
        ..type = CollectionType.folder;

      final result = await container.read(
        collectionCoverThumbnailProvider(collection).future,
      );

      expect(result, isNull);
    });

    test('リレーションに子孫の画像が残っていても上位カタログの表紙にしない', () async {
      final descendantFile = File(
        '${tempDir.path}/folder/parent/child/cover.jpg',
      );
      await descendantFile.parent.create(recursive: true);
      await descendantFile.writeAsString('fake descendant image');

      final descendant = MediaItem()
        ..id = 201
        ..path = 'folder/parent/child/cover.jpg'
        ..parentPath = 'folder/parent/child'
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.file;
      final collection = MediaCollection()
        ..path = 'folder/parent'
        ..type = CollectionType.folder;
      collection.items.add(descendant);

      when(
        () => mockRepository.getByPath(collection.path),
      ).thenAnswer((_) async => Result.success(null));
      when(
        () => mockRepository.getCoverCandidates(collection.path),
      ).thenAnswer((_) async => Result.success([]));

      final result = await container.read(
        collectionCoverThumbnailProvider(collection).future,
      );

      expect(result, isNull);
    });
  });
}
