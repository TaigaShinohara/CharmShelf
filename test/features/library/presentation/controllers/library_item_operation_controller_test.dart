import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/presentation/controllers/library_item_operation_controller.dart';

class _MockMediaRepository extends Mock implements MediaRepository {}

class _FakeMediaCollection extends Fake implements MediaCollection {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeMediaCollection());
  });

  test('表紙設定で別パスの上位カタログを更新しない', () async {
    final repository = _MockMediaRepository();
    final ancestor = MediaCollection()
      ..path = 'library/parent'
      ..title = 'parent'
      ..coverImagePath = 'thumbnails/original.jpg';
    final item = MediaItem()
      ..path = 'library/parent/child/selected.jpg'
      ..parentPath = 'library/parent/child'
      ..thumbnailPath = 'thumbnails/selected.jpg'
      ..type = MediaType.file
      ..sourceType = MediaSourceType.localCopy;

    when(
      () => repository.getCollectionByPath(item.parentPath!),
    ).thenAnswer((_) async => Result.success(ancestor));
    final savedCollections = <MediaCollection>[];
    when(() => repository.saveCollection(captureAny())).thenAnswer((
      invocation,
    ) async {
      savedCollections.add(
        invocation.positionalArguments.first as MediaCollection,
      );
      return Result.success(null);
    });
    final container = ProviderContainer(
      overrides: [
        mediaRepositoryProvider.overrideWith((ref) async => repository),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(libraryItemOperationControllerProvider.notifier)
        .setAsFolderCover(item);

    expect(savedCollections, hasLength(1));
    expect(savedCollections.single.path, item.parentPath);
    expect(savedCollections.single.coverImagePath, item.thumbnailPath);
    expect(ancestor.coverImagePath, 'thumbnails/original.jpg');
  });
}
