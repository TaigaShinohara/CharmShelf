import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/presentation/providers/media_viewer_view_model.dart';

class _MockMediaRepository extends Mock implements MediaRepository {}

class _FakeMediaCollection extends Fake implements MediaCollection {}

void main() {
  setUpAll(() => registerFallbackValue(_FakeMediaCollection()));

  test('最終閲覧位置はコレクション全体保存ではなく専用の原子的更新を使う', () async {
    final repository = _MockMediaRepository();
    when(
      () => repository.updateCollectionLastViewed(
        'books/work',
        itemId: 42,
        viewedAt: any(named: 'viewedAt'),
      ),
    ).thenAnswer((_) async => Result<bool, AppError>.success(true));
    final container = ProviderContainer(
      overrides: [
        mediaRepositoryProvider.overrideWith((ref) async => repository),
      ],
    );
    addTearDown(container.dispose);
    final item = MediaItem()
      ..id = 42
      ..path = 'books/work/page.png'
      ..parentPath = 'books/work'
      ..type = MediaType.file
      ..sourceType = MediaSourceType.localCopy;

    await container
        .read(mediaViewerViewModelProvider.notifier)
        .saveLastViewedAt(item);

    verify(
      () => repository.updateCollectionLastViewed(
        'books/work',
        itemId: 42,
        viewedAt: any(named: 'viewedAt'),
      ),
    ).called(1);
    verifyNever(() => repository.getCollectionByPath(any()));
    verifyNever(() => repository.saveCollection(any()));
  });

  test('parentPathがlibraryのアイテムはlibraryではなくアイテムパスに対して最終閲覧位置を更新する', () async {
    final repository = _MockMediaRepository();
    when(
      () => repository.updateCollectionLastViewed(
        'library/icon_move.mp4',
        itemId: 10,
        viewedAt: any(named: 'viewedAt'),
      ),
    ).thenAnswer((_) async => Result<bool, AppError>.success(true));

    final container = ProviderContainer(
      overrides: [
        mediaRepositoryProvider.overrideWith((ref) async => repository),
      ],
    );
    addTearDown(container.dispose);

    final item = MediaItem()
      ..id = 10
      ..path = 'library/icon_move.mp4'
      ..parentPath = 'library'
      ..type = MediaType.file
      ..sourceType = MediaSourceType.localCopy;

    await container
        .read(mediaViewerViewModelProvider.notifier)
        .saveLastViewedAt(item);

    verify(
      () => repository.updateCollectionLastViewed(
        'library/icon_move.mp4',
        itemId: 10,
        viewedAt: any(named: 'viewedAt'),
      ),
    ).called(1);
    verifyNever(
      () => repository.updateCollectionLastViewed(
        'library',
        itemId: any(named: 'itemId'),
        viewedAt: any(named: 'viewedAt'),
      ),
    );
  });

  test('debounce中にViewModelが破棄されても最終閲覧位置を保存する', () async {
    final repository = _MockMediaRepository();
    when(
      () => repository.updateCollectionLastViewed(
        'books/work',
        itemId: 99,
        viewedAt: any(named: 'viewedAt'),
      ),
    ).thenAnswer((_) async => Result<bool, AppError>.success(true));
    final container = ProviderContainer(
      overrides: [
        mediaRepositoryProvider.overrideWith((ref) async => repository),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      mediaViewerViewModelProvider,
      (_, _) {},
      fireImmediately: true,
    );
    final item = MediaItem()
      ..id = 99
      ..path = 'books/work/page-99.png'
      ..parentPath = 'books/work'
      ..type = MediaType.file
      ..sourceType = MediaSourceType.localCopy;

    container
        .read(mediaViewerViewModelProvider.notifier)
        .updateLastViewedAt(item);
    subscription.close();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    verify(
      () => repository.updateCollectionLastViewed(
        'books/work',
        itemId: 99,
        viewedAt: any(named: 'viewedAt'),
      ),
    ).called(1);
  });

  test('保存中に新しい閲覧位置へ移動して破棄されても最新位置まで保存する', () async {
    final repository = _MockMediaRepository();
    final firstSave = Completer<Result<bool, AppError>>();
    var saveCount = 0;
    when(
      () => repository.updateCollectionLastViewed(
        'books/work',
        itemId: any(named: 'itemId'),
        viewedAt: any(named: 'viewedAt'),
      ),
    ).thenAnswer((_) {
      saveCount++;
      if (saveCount == 1) return firstSave.future;
      return Future.value(Result<bool, AppError>.success(true));
    });
    final container = ProviderContainer(
      overrides: [
        mediaRepositoryProvider.overrideWith((ref) async => repository),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      mediaViewerViewModelProvider,
      (_, _) {},
      fireImmediately: true,
    );
    final firstItem = MediaItem()
      ..id = 100
      ..path = 'books/work/page-100.png'
      ..parentPath = 'books/work'
      ..type = MediaType.file
      ..sourceType = MediaSourceType.localCopy;
    final latestItem = MediaItem()
      ..id = 101
      ..path = 'books/work/page-101.png'
      ..parentPath = 'books/work'
      ..type = MediaType.file
      ..sourceType = MediaSourceType.localCopy;
    final viewModel = container.read(mediaViewerViewModelProvider.notifier);

    viewModel.updateLastViewedAt(firstItem);
    await Future<void>.delayed(const Duration(milliseconds: 850));
    verify(
      () => repository.updateCollectionLastViewed(
        'books/work',
        itemId: 100,
        viewedAt: any(named: 'viewedAt'),
      ),
    ).called(1);

    viewModel.updateLastViewedAt(latestItem);
    subscription.close();
    firstSave.complete(Result<bool, AppError>.success(true));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    verify(
      () => repository.updateCollectionLastViewed(
        'books/work',
        itemId: 101,
        viewedAt: any(named: 'viewedAt'),
      ),
    ).called(1);
  });
}
