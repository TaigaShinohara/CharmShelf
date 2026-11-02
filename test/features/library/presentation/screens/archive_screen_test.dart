import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/home/presentation/providers/archived_collections_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/application/use_cases/archive_media_item_use_case.dart';
import 'package:private_shelf/features/library/presentation/screens/archive_screen.dart';
import '../../../../helpers/test_helpers.dart';

class _MockArchiveMediaItemUseCase extends Mock
    implements ArchiveMediaItemUseCase {}

void main() {
  late _MockArchiveMediaItemUseCase mockArchiveUseCase;
  late MediaCollection collection;

  setUp(() {
    mockArchiveUseCase = _MockArchiveMediaItemUseCase();
    collection = MediaCollection()
      ..id = 1
      ..path = 'library/album1'
      ..title = 'Test Album'
      ..isArchived = true;

    when(
      () => mockArchiveUseCase.call(
        collection: any(named: 'collection'),
        isArchived: any(named: 'isArchived'),
      ),
    ).thenAnswer((_) async => Result.success(null));
  });

  testWidgets('アーカイブ画面にアーカイブされたコレクションが表示され解除できる', (tester) async {
    await tester.pumpWidget(
      createProviderApp(
        const ArchiveScreen(),
        overrides: [
          archivedCollectionsProvider.overrideWith((ref) async => [collection]),
          archiveMediaItemUseCaseProvider.overrideWith(
            (ref) async => mockArchiveUseCase,
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Test Album'), findsOneWidget);
    expect(find.byIcon(Icons.unarchive_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.unarchive_outlined));
    await tester.pumpAndSettle();

    expect(find.text('「Test Album」のアーカイブを解除しますか？'), findsOneWidget);
    verifyNever(
      () => mockArchiveUseCase.call(collection: collection, isArchived: false),
    );

    await tester.tap(find.text('アーカイブ解除').last);
    await tester.pump(const Duration(milliseconds: 500));

    verify(
      () => mockArchiveUseCase.call(collection: collection, isArchived: false),
    ).called(1);
    await tester.pump(const Duration(seconds: 4));
  });
}
