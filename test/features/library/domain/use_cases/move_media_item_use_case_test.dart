import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/operation_journal_service.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/application/use_cases/move_media_item_use_case.dart';

class MockMediaRepository extends Mock implements MediaRepository {}

class MockFileService extends Mock implements FileService {}

class MockOperationJournal extends Mock implements OperationJournalService {}

class FakeOperationJournalEntry extends Fake implements OperationJournalEntry {}

class MockPathProviderPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFileService mockFileService;
  late MockMediaRepository mockMediaRepository;
  late MoveMediaItemUseCase useCase;
  late MockPathProviderPlatform mockPathProvider;

  setUp(() async {
    mockFileService = MockFileService();
    mockMediaRepository = MockMediaRepository();
    useCase = MoveMediaItemUseCase(
      Future.value(mockMediaRepository),
      mockFileService,
    );
    mockPathProvider = MockPathProviderPlatform();

    PathProviderPlatform.instance = mockPathProvider;
    when(
      () => mockPathProvider.getApplicationDocumentsPath(),
    ).thenAnswer((_) async => '/tmp');

    // 物理移動はデフォルト成功
    when(
      () => mockFileService.moveEntity(any(), any()),
    ).thenAnswer((_) async => Result.success(null));

    // カバー画像更新はデフォルト成功
    when(
      () => mockMediaRepository.updateCoverImagePath(any(), any()),
    ).thenAnswer((_) async => Result.success(null));

    registerFallbackValue(MediaItem());
    registerFallbackValue(MediaCollection());
    registerFallbackValue(FakeOperationJournalEntry());
  });

  group('MoveMediaItemUseCase.invoke', () {
    final folderItem = MediaItem()
      ..id = 1
      ..path = 'folder_a'
      ..sourceType = MediaSourceType.localCopy
      ..type = MediaType.folder;

    test('正常系: フォルダ移動時に物理移動、DB更新、Collection更新が順に行われること', () async {
      // Setup
      final collection = MediaCollection()
        ..id = 10
        ..path = 'folder_a';

      when(
        () => mockMediaRepository.save(any()),
      ).thenAnswer((_) async => Result.success(null));
      when(
        () => mockMediaRepository.getCollectionByPath('library/folder_a'),
      ).thenAnswer((_) async => Result.success(collection));
      when(
        () => mockMediaRepository.saveCollection(any()),
      ).thenAnswer((_) async => Result.success(null));
      when(
        () => mockMediaRepository.updatePathsForMovedDirectory(
          'library/folder_a',
          'library/new_parent/folder_a',
        ),
      ).thenAnswer((_) async => Result.success(null));

      // Execute
      final result = await useCase.invoke(folderItem, 'new_parent');

      // Verify
      expect(result.isSuccess, true);

      // 1. 物理移動が呼ばれたか
      verify(
        () => mockFileService.moveEntity(
          'library/folder_a',
          'library/new_parent/folder_a',
        ),
      ).called(1);

      // 2. DB更新が呼ばれたか
      verify(() => mockMediaRepository.save(any())).called(1);

      // 3. Collectionの保存を確認
      final capturedCollection =
          verify(
                () => mockMediaRepository.saveCollection(captureAny()),
              ).captured.first
              as MediaCollection;
      expect(capturedCollection.path, 'library/new_parent/folder_a');

      // 4. 子アイテムの更新
      verify(
        () => mockMediaRepository.updatePathsForMovedDirectory(
          'library/folder_a',
          'library/new_parent/folder_a',
        ),
      ).called(1);
    });

    test('正常系: フォルダの名前変更時に物理移動とCollectionのtitle更新が行われること', () async {
      // Setup
      // folderItem.path は 'library/folder_a' ではなく 'folder_a' を基準にテスト
      final renameTargetItem = MediaItem()
        ..id = 1
        ..path = 'folder_a'
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.folder;

      final collection = MediaCollection()
        ..id = 10
        ..path = 'library/folder_a'
        ..title = 'Old Name';

      when(
        () => mockMediaRepository.save(any()),
      ).thenAnswer((_) async => Result.success(null));
      when(
        () => mockMediaRepository.getCollectionByPath('library/folder_a'),
      ).thenAnswer((_) async => Result.success(collection));
      when(
        () => mockMediaRepository.saveCollection(any()),
      ).thenAnswer((_) async => Result.success(null));
      when(
        () => mockMediaRepository.updatePathsForMovedDirectory(any(), any()),
      ).thenAnswer((_) async => Result.success(null));

      // Execute
      final result = await useCase.invoke(
        renameTargetItem,
        null,
        newName: 'New Name',
      );

      // Verify
      expect(result.isSuccess, true);

      // 1. 物理移動が呼ばれたか (library/New Name)
      verify(
        () =>
            mockFileService.moveEntity('library/folder_a', 'library/New Name'),
      ).called(1);

      // 2. Collectionの保存とtitle更新を確認
      final capturedCollection =
          verify(
                () => mockMediaRepository.saveCollection(captureAny()),
              ).captured.first
              as MediaCollection;
      expect(capturedCollection.path, 'library/New Name');
      expect(capturedCollection.title, 'New Name');
    });

    test('ロールバック: DB更新失敗時に物理ファイルが旧パスに書き戻されること', () async {
      // Setup
      final localFolderItem = MediaItem()
        ..id = 1
        ..path = 'folder_a'
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.folder;

      // DB保存のみ失敗させる
      when(() => mockMediaRepository.save(any())).thenAnswer(
        (_) async => Result.failure(AppError.database('Save failed')),
      );

      // Execute
      final result = await useCase.invoke(localFolderItem, 'new_parent');

      // Verify
      expect(result.isFailure, true);

      // 1. 物理移動が1回目（移動）と2回目（ロールバック）で呼ばれたか
      verifyInOrder([
        () => mockFileService.moveEntity(
          'library/folder_a',
          'library/new_parent/folder_a',
        ),
        () => mockFileService.moveEntity(
          'library/new_parent/folder_a',
          'library/folder_a',
        ),
      ]);

      // 2. DBレコードが書き戻されたか (saveが再試行されたか)
      // 1回目(失敗) + 2回目(ロールバック用) = 2回
      verify(() => mockMediaRepository.save(any())).called(2);
    });

    test('重大障害: DB失敗後に物理ロールバックも失敗したことを明示する', () async {
      final item = MediaItem()
        ..id = 3
        ..path = 'library/a.jpg'
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.file;
      var moveCalls = 0;
      when(() => mockFileService.moveEntity(any(), any())).thenAnswer((
        _,
      ) async {
        moveCalls++;
        return moveCalls == 1
            ? Result.success(null)
            : Result.failure(AppError.file('rollback denied'));
      });
      when(() => mockMediaRepository.save(any())).thenAnswer(
        (_) async => Result.failure(AppError.database('save failed')),
      );

      final result = await useCase.invoke(item, 'library/target');

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull?.category, ErrorCategory.file);
      expect(result.errorOrNull?.message, contains('rollback also failed'));
    });

    test('バリデーション: フォルダを自身の子フォルダに移動しようとした場合にエラーになること', () async {
      // Setup
      final folderItem = MediaItem()
        ..id = 1
        ..path = 'folder_a'
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.folder;

      // Execute: folder_a を folder_a/sub に移動しようとする
      final result = await useCase.invoke(folderItem, 'folder_a/sub');

      // Verify
      expect(result.isFailure, true);
      expect(
        result.errorOrNull?.message,
        contains('Cannot move a folder into itself'),
      );

      // 物理移動やDB更新が呼ばれていないこと
      verifyNever(() => mockFileService.moveEntity(any(), any()));
      verifyNever(() => mockMediaRepository.save(any()));
    });

    test('バリデーション: 表記が異なる正規化後の子パスも拒否する', () async {
      final folder = MediaItem()
        ..id = 1
        ..path = 'folder_a'
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.folder;

      final result = await useCase.invoke(
        folder,
        'library/other/../folder_a/sub',
      );

      expect(result.errorOrNull?.category, ErrorCategory.validation);
      verifyNever(() => mockFileService.moveEntity(any(), any()));
      verifyNever(() => mockMediaRepository.save(any()));
    });

    test('バリデーション: 外部参照のDBパスだけを変更する操作を拒否する', () async {
      final item = MediaItem()
        ..id = 9
        ..path = 'content://provider/document/9'
        ..sourceType = MediaSourceType.externalReference
        ..type = MediaType.file;

      final result = await useCase.invoke(item, 'library/target');

      expect(result.errorOrNull?.category, ErrorCategory.validation);
      verifyNever(() => mockFileService.moveEntity(any(), any()));
      verifyNever(() => mockMediaRepository.save(any()));
    });

    test('ファイル移動時: 対応するCollectionがある場合は更新処理が呼ばれること', () async {
      // Setup
      final fileItem = MediaItem()
        ..id = 2
        ..path = 'image.jpg'
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.file;

      final collection = MediaCollection()
        ..id = 20
        ..path = 'image.jpg'
        ..title = 'Image Catalog';

      when(
        () => mockMediaRepository.save(any()),
      ).thenAnswer((_) async => Result.success(null));
      when(
        () => mockMediaRepository.getCollectionByPath('library/image.jpg'),
      ).thenAnswer((_) async => Result.success(collection));
      when(
        () => mockMediaRepository.saveCollection(any()),
      ).thenAnswer((_) async => Result.success(null));

      // Execute
      final result = await useCase.invoke(
        fileItem,
        'new_parent',
        newName: 'new_image.jpg',
      );

      // Verify
      expect(result.isSuccess, true);
      verify(
        () => mockFileService.moveEntity(
          'library/image.jpg',
          'library/new_parent/new_image.jpg',
        ),
      ).called(1);

      // Collectionの更新を確認
      final capturedCollection =
          verify(
                () => mockMediaRepository.saveCollection(captureAny()),
              ).captured.first
              as MediaCollection;
      expect(capturedCollection.path, 'library/new_parent/new_image.jpg');
      expect(capturedCollection.title, 'new_image.jpg');
    });

    test('子孫パス更新失敗時はCollectionのパスとタイトルも復元する', () async {
      final item = MediaItem()
        ..id = 30
        ..path = 'library/folder'
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.folder;
      final collection = MediaCollection()
        ..id = 31
        ..path = 'library/folder'
        ..title = 'Original'
        ..updatedAt = DateTime(2025);

      when(
        () => mockMediaRepository.save(any()),
      ).thenAnswer((_) async => Result.success(null));
      when(
        () => mockMediaRepository.getCollectionByPath('library/folder'),
      ).thenAnswer((_) async => Result.success(collection));
      when(
        () => mockMediaRepository.saveCollection(any()),
      ).thenAnswer((_) async => Result.success(null));
      when(
        () => mockMediaRepository.updatePathsForMovedDirectory(any(), any()),
      ).thenAnswer(
        (_) async => Result.failure(AppError.database('descendant failure')),
      );

      final result = await useCase.invoke(item, null, newName: 'Renamed');

      expect(result.isFailure, isTrue);
      expect(collection.path, 'library/folder');
      expect(collection.title, 'Original');
      verifyInOrder([
        () => mockFileService.moveEntity('library/folder', 'library/Renamed'),
        () => mockFileService.moveEntity('library/Renamed', 'library/folder'),
      ]);
      verify(() => mockMediaRepository.saveCollection(collection)).called(2);
    });

    test('正常完了時は移動ジャーナルをplanned・staged・committedへ進めて削除する', () async {
      final journal = MockOperationJournal();
      final journaledUseCase = MoveMediaItemUseCase(
        Future.value(mockMediaRepository),
        mockFileService,
        journal,
      );
      final item = MediaItem()
        ..id = 40
        ..path = 'library/folder'
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.folder;
      when(() => journal.write(any())).thenAnswer((_) async {});
      when(() => journal.remove(any())).thenAnswer((_) async {});
      when(
        () => mockMediaRepository.save(any()),
      ).thenAnswer((_) async => Result.success(null));
      when(
        () => mockMediaRepository.getCollectionByPath(any()),
      ).thenAnswer((_) async => Result.success(null));
      when(
        () => mockMediaRepository.updatePathsForMovedDirectory(any(), any()),
      ).thenAnswer((_) async => Result.success(null));

      final result = await journaledUseCase.invoke(item, 'library/target');

      expect(result.isSuccess, isTrue);
      final entries = verify(
        () => journal.write(captureAny()),
      ).captured.cast<OperationJournalEntry>().toList();
      expect(entries.map((entry) => entry.stage), [
        OperationStage.planned,
        OperationStage.staged,
        OperationStage.committed,
      ]);
      expect(entries.first.kind, OperationKind.move);
      expect(entries.first.payload['oldPath'], 'library/folder');
      expect(entries.first.payload['newPath'], 'library/target/folder');
      verify(() => journal.remove(entries.first.id)).called(1);
    });

    test('単一ファイル移動時にupdateCoverImagePathが呼ばれること', () async {
      final fileItem = MediaItem()
        ..id = 50
        ..path = 'library/sample.jpg'
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.file;

      when(
        () => mockMediaRepository.save(any()),
      ).thenAnswer((_) async => Result.success(null));
      when(
        () => mockMediaRepository.getCollectionByPath(any()),
      ).thenAnswer((_) async => Result.success(null));
      when(
        () => mockMediaRepository.updateCoverImagePath(
          'library/sample.jpg',
          'library/dest/sample.jpg',
        ),
      ).thenAnswer((_) async => Result.success(null));

      final result = await useCase.invoke(fileItem, 'library/dest');

      expect(result.isSuccess, isTrue);
      verify(
        () => mockMediaRepository.updateCoverImagePath(
          'library/sample.jpg',
          'library/dest/sample.jpg',
        ),
      ).called(1);
    });

    test('不正なファイル名（禁則文字やシステム予約名）の場合はバリデーションエラーを返すこと', () async {
      final fileItem = MediaItem()
        ..id = 51
        ..path = 'library/sample.jpg'
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.file;

      final resultInvalidChar = await useCase.invoke(
        fileItem,
        null,
        newName: 'invalid:name.jpg',
      );
      expect(resultInvalidChar.isFailure, isTrue);

      final resultReserved = await useCase.invoke(
        fileItem,
        null,
        newName: 'CON',
      );
      expect(resultReserved.isFailure, isTrue);
    });

    test('正常系: フォルダ移動・リネーム時に自身のcoverImagePathが移動先パスに追従して更新されること', () async {
      final folderItem = MediaItem()
        ..id = 60
        ..path = 'library/Welcome_DocBook'
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.folder;

      final collection = MediaCollection()
        ..id = 60
        ..path = 'library/Welcome_DocBook'
        ..title = 'Welcome_DocBook'
        ..coverImagePath = 'library/Welcome_DocBook/icon.png';

      when(
        () => mockFileService.moveEntity(any(), any()),
      ).thenAnswer((_) async => Result.success(null));
      when(
        () => mockMediaRepository.save(any()),
      ).thenAnswer((_) async => Result.success(null));
      when(
        () =>
            mockMediaRepository.getCollectionByPath('library/Welcome_DocBook'),
      ).thenAnswer((_) async => Result.success(collection));
      when(
        () => mockMediaRepository.saveCollection(any()),
      ).thenAnswer((_) async => Result.success(null));
      when(
        () => mockMediaRepository.updatePathsForMovedDirectory(any(), any()),
      ).thenAnswer((_) async => Result.success(null));

      final result = await useCase.invoke(
        folderItem,
        'library',
        newName: 'Welcome_DocBook123',
      );

      expect(result.isSuccess, isTrue);
      final capturedCollection =
          verify(
                () => mockMediaRepository.saveCollection(captureAny()),
              ).captured.first
              as MediaCollection;
      expect(capturedCollection.path, 'library/Welcome_DocBook123');
      expect(capturedCollection.title, 'Welcome_DocBook123');
      expect(
        capturedCollection.coverImagePath,
        'library/Welcome_DocBook123/icon.png',
      );
    });
  });
}
