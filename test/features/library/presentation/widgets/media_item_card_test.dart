import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/styles/media_tier_styles.dart';
import 'package:private_shelf/features/library/presentation/widgets/media_item_card.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

import 'dart:io';
import 'dart:ui' as ui;

void main() {
  testWidgets(
    'MediaItemCard displays file name and placeholder when no thumbnail',
    (WidgetTester tester) async {
      final semantics = tester.ensureSemantics();
      final tempDir = Directory.systemTemp.createTempSync(
        'media_item_card_test_',
      );
      final testFile = File('${tempDir.path}/folder/test.jpg');
      testFile.parent.createSync(recursive: true);
      testFile.writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]); // dummy jpg header

      final item = MediaItem()
        ..id = 1
        ..path = 'folder/test.jpg'
        ..originalPath = testFile.path
        ..sourceType = MediaSourceType.localCopy
        ..addedAt = DateTime.now()
        ..updatedAt = DateTime.now()
        ..type = MediaType.file;

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDocumentsPathSyncProvider.overrideWith((ref) => tempDir.path),
            ],
            child: MaterialApp(
              locale: const Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 200,
                    height: 280,
                    child: MediaItemCard(item: item, onTap: () {}),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('test.jpg'), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
        expect(find.byTooltip('管理とその他の操作'), findsNothing);

        final cardSemantics = tester
            .getSemantics(find.byKey(const ValueKey('media-item-card-1')))
            .getSemanticsData();
        expect(cardSemantics.flagsCollection.isButton, isTrue);
        expect(cardSemantics.hasAction(ui.SemanticsAction.tap), isTrue);
        expect(find.byType(IconButton), findsNothing);
      } finally {
        semantics.dispose();
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    },
  );

  testWidgets('MediaItemCard displays tier S on the catalog badge', (
    WidgetTester tester,
  ) async {
    final item = MediaItem()
      ..id = 2
      ..path = 'folder/tier_s.jpg'
      ..originalPath = '/tmp/tier_s.jpg'
      ..sourceType = MediaSourceType.localCopy
      ..addedAt = DateTime.now()
      ..updatedAt = DateTime.now()
      ..type = MediaType.file;
    final collection = MediaCollection()
      ..title = 'tier_s'
      ..isCatalog = true
      ..path = 'folder/tier_s.jpg'
      ..type = CollectionType.file
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now()
      ..tier = MediaTier.s.value;
    item.collection.value = collection;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp')],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 280,
                child: MediaItemCard(item: item),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cardFinder = find.byType(Card);
    expect(cardFinder, findsOneWidget);
    final card = tester.widget<Card>(cardFinder);
    final shape = card.shape as RoundedRectangleBorder;
    final context = tester.element(cardFinder);
    expect(shape.side.width, 1.0);
    expect(shape.side.color, isNot(MediaTier.s.color(context)));

    final tierColor = MediaTier.s.color(context);
    final badgeFinder = find.byWidgetPredicate((widget) {
      if (widget is! Container || widget.decoration is! BoxDecoration) {
        return false;
      }
      final decoration = widget.decoration! as BoxDecoration;
      return decoration.border == Border.all(color: tierColor, width: 0.5) &&
          decoration.color == tierColor.withValues(alpha: 0.45);
    });
    expect(badgeFinder, findsOneWidget);
    expect(find.byTooltip('管理とその他の操作'), findsOneWidget);
    final menuSize = tester.getSize(find.byType(IconButton));
    expect(menuSize.width, greaterThanOrEqualTo(48));
    expect(menuSize.height, greaterThanOrEqualTo(48));
  });

  testWidgets('MediaItemCard uses the catalog alias as the main name', (
    WidgetTester tester,
  ) async {
    final item = MediaItem()
      ..id = 3
      ..path = 'folders/original-name'
      ..originalPath = '/tmp/original-name'
      ..type = MediaType.folder;
    final collection = MediaCollection()
      ..title = 'original-name'
      ..alias = '表示名'
      ..path = item.path
      ..type = CollectionType.folder
      ..isCatalog = true;
    item.collection.value = collection;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp')],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 280,
              child: MediaItemCard(item: item),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('表示名'), findsOneWidget);
    expect(find.text('original-name'), findsOneWidget);
  });
}
