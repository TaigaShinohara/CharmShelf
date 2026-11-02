import 'package:private_shelf/shared/widgets/icon/catalogize_icon.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/presentation/widgets/collection_card.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

class MockMediaRepository extends Mock implements MediaRepository {}

void main() {
  late MockMediaRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(MediaCollection());
    registerFallbackValue(MediaItem());
  });

  setUp(() {
    mockRepository = MockMediaRepository();
    when(
      () => mockRepository.getCollectionByPath(any()),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => mockRepository.getByPath(any()),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => mockRepository.getByParentPath(any()),
    ).thenAnswer((_) async => Result.success([]));
    when(
      () => mockRepository.getById(any()),
    ).thenAnswer((_) async => Result.success(null));
  });

  testWidgets('CollectionCard displays title correctly', (
    WidgetTester tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final collection = MediaCollection()
      ..title = 'Test Collection'
      ..path = 'folder/test'
      ..type = CollectionType.folder
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
          mediaRepositoryProvider.overrideWith(
            (ref) => Future.value(mockRepository),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: CollectionCard(collection: collection, onTap: () {}),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Test Collection'), findsOneWidget);
    expect(find.byTooltip('管理とその他の操作'), findsOneWidget);
    final menuSize = tester.getSize(find.byType(IconButton));
    expect(menuSize.width, greaterThanOrEqualTo(48));
    expect(menuSize.height, greaterThanOrEqualTo(48));
    final primarySemantics = tester
        .getSemantics(
          find.byKey(const ValueKey('collection-card-primary-folder/test')),
        )
        .getSemanticsData();
    expect(primarySemantics.attributedLabel.string, 'Test Collection');
    expect(primarySemantics.flagsCollection.isButton, isTrue);
    expect(primarySemantics.hasAction(ui.SemanticsAction.tap), isTrue);
    semantics.dispose();
  });

  testWidgets(
    'CollectionCard renders placeholder icon when no cover is available',
    (WidgetTester tester) async {
      final collection = MediaCollection()
        ..title = 'Empty Collection'
        ..path = 'folder/empty'
        ..type = CollectionType.folder
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
            mediaRepositoryProvider.overrideWith(
              (ref) => Future.value(mockRepository),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: CollectionCard(collection: collection, onTap: () {}),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CatalogizeIcon), findsOneWidget);
    },
  );
}
