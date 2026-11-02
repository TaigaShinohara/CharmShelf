import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/application/use_cases/empty_trash_use_case.dart';
import 'package:private_shelf/features/library/application/use_cases/permanently_delete_trashed_media_use_case.dart';
import 'package:private_shelf/features/library/application/use_cases/restore_trashed_media_use_case.dart';
import 'package:private_shelf/features/library/presentation/providers/trash_provider.dart';
import 'package:private_shelf/features/library/presentation/screens/trash_screen.dart';
import 'package:private_shelf/features/library/presentation/widgets/media_list_tile.dart';
import '../../../../helpers/test_helpers.dart';

class _MockMediaRepository extends Mock implements MediaRepository {}

class _MockPermanentDelete extends Mock
    implements PermanentlyDeleteTrashedMediaUseCase {}

class _MockRestore extends Mock implements RestoreTrashedMediaUseCase {}

void main() {
  late _MockMediaRepository repository;
  late _MockPermanentDelete delete;
  late _MockRestore restore;
  late MediaItem root;

  setUp(() {
    repository = _MockMediaRepository();
    delete = _MockPermanentDelete();
    restore = _MockRestore();
    root = MediaItem()
      ..id = 1
      ..path = 'library/a.jpg'
      ..isTrashed = true
      ..isTrashRoot = true
      ..trashPath = '.trash/delete-1/a.jpg';

    when(
      () => repository.getTrashedRoots(),
    ).thenAnswer((_) async => Result.success([root]));
    when(
      () => repository.getTrashedItems(any()),
    ).thenAnswer((_) async => Result.success([root]));
    when(
      () => repository.getTrashedCollections(any()),
    ).thenAnswer((_) async => Result.success(const <MediaCollection>[]));
    when(
      () => restore.invoke(root, newName: null, newParentPath: null),
    ).thenAnswer((_) async => Result.success(null));
  });

  testWidgets('空のゴミ箱からライブラリに戻れる', (tester) async {
    await tester.pumpWidget(
      createProviderApp(
        const TrashScreen(),
        overrides: [trashedMediaRootsProvider.overrideWith((ref) async => [])],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('ごみ箱は空です'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'ライブラリ'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });

  testWidgets('ゴミ箱から元に戻す前に確認を表示する', (tester) async {
    await tester.pumpWidget(
      createProviderApp(
        const TrashScreen(),
        overrides: [
          trashedMediaRootsProvider.overrideWith((ref) async => [root]),
          mediaRepositoryProvider.overrideWith((ref) async => repository),
          restoreTrashedMediaUseCaseProvider.overrideWithValue(restore),
          appDocumentsPathSyncProvider.overrideWithValue('/tmp'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.restore_outlined), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsNothing);

    await tester.tap(find.byIcon(Icons.restore_outlined));
    await tester.pumpAndSettle();

    expect(find.text('「a.jpg」をゴミ箱から元に戻しますか？'), findsOneWidget);
    verifyNever(() => restore.invoke(root, newName: null, newParentPath: null));

    await tester.tap(find.text('元に戻す').last);
    await tester.pumpAndSettle();

    verify(
      () => restore.invoke(root, newName: null, newParentPath: null),
    ).called(1);
  });

  testWidgets('完全削除の確認に件数と不可逆性を表示する', (tester) async {
    await tester.pumpWidget(
      createProviderApp(
        const TrashScreen(),
        overrides: [
          trashedMediaRootsProvider.overrideWith((ref) async => [root]),
          mediaRepositoryProvider.overrideWith((ref) async => repository),
          emptyTrashUseCaseProvider.overrideWithValue(
            EmptyTrashUseCase(Future.value(repository), delete),
          ),
          appDocumentsPathSyncProvider.overrideWithValue('/tmp'),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('a.jpg'), findsOneWidget);
    expect(find.byType(MediaListTile), findsOneWidget);

    tester.widget<MediaListTile>(find.byType(MediaListTile)).onTap!();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_forever));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('1件の項目を完全に削除しますか？この操作は取り消せません。'),
      findsOneWidget,
    );
    expect(find.text('a.jpg'), findsAtLeastNWidgets(1));
  });

  testWidgets('ごみ箱を空にする部分失敗では失敗した項目名を個別表示する', (tester) async {
    when(() => delete.invoke(root)).thenAnswer(
      (_) async => Result.failure(
        AppError.file('purge failed').withAdditionalData({
          'failedItems': [
            {'path': root.path, 'displayName': 'a.jpg', 'type': 'file'},
          ],
        }),
      ),
    );

    await tester.pumpWidget(
      createProviderApp(
        const TrashScreen(),
        overrides: [
          trashedMediaRootsProvider.overrideWith((ref) async => [root]),
          mediaRepositoryProvider.overrideWith((ref) async => repository),
          emptyTrashUseCaseProvider.overrideWithValue(
            EmptyTrashUseCase(Future.value(repository), delete),
          ),
          appDocumentsPathSyncProvider.overrideWithValue('/tmp'),
        ],
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('ごみ箱を空にする'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ごみ箱を空にする').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('一部の項目は削除できませんでした'), findsOneWidget);
    expect(find.text('削除できなかった項目:'), findsOneWidget);
    expect(find.text('• a.jpg'), findsOneWidget);
  });
}
