import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/presentation/providers/secret_mode_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_facet_view_model.dart';
import 'package:private_shelf/features/library/presentation/widgets/action_sheet/components/action_sheet_header.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/tag/app_tag.dart';

class _FakeSecretMode extends SecretMode {
  final bool initialValue;
  _FakeSecretMode(this.initialValue);

  @override
  FutureOr<bool> build() => initialValue;
}

class _FakeTagFacetListViewModel extends TagFacetListViewModel {
  final List<TagFacet> initialFacets;
  _FakeTagFacetListViewModel(this.initialFacets);

  @override
  Stream<List<TagFacet>> build() => Stream.value(initialFacets);
}

void main() {
  group('ActionSheetHeader', () {
    testWidgets('コレクションにタグが付与されている場合、タグが表示されること', (tester) async {
      final tag1 = Tag()
        ..id = 1
        ..name = 'お気に入り'
        ..key = '1::お気に入り';
      final tag2 = Tag()
        ..id = 2
        ..name = 'イラスト'
        ..key = '1::イラスト';

      final collection = MediaCollection()
        ..title = 'テストカタログ'
        ..path = 'folder/test'
        ..isCatalog = true
        ..type = CollectionType.folder
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
            secretModeProvider.overrideWith(() => _FakeSecretMode(false)),
            tagFacetListViewModelProvider.overrideWith(
              () => _FakeTagFacetListViewModel([]),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ActionSheetHeader(
                  collection: collection,
                  tags: [tag1, tag2],
                  title: 'テストカタログ',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('テストカタログ'), findsOneWidget);
      expect(find.text('お気に入り'), findsOneWidget);
      expect(find.text('イラスト'), findsOneWidget);
      expect(find.byType(AppTag), findsNWidgets(2));
      final first = tester.getRect(find.byType(AppTag).first);
      final second = tester.getRect(find.byType(AppTag).last);
      expect(second.top, first.top);
      expect(second.left - first.right, closeTo(6, .01));
    });

    testWidgets('非表示タグはシークレットモードOFFのときに表示されないこと', (tester) async {
      final tag1 = Tag()
        ..id = 1
        ..name = '通常タグ'
        ..key = '1::通常タグ';
      final tagHidden = Tag()
        ..id = 2
        ..name = '秘密タグ'
        ..key = '1::秘密タグ'
        ..isHidden = true;

      final collection = MediaCollection()
        ..title = 'テストカタログ'
        ..path = 'folder/test'
        ..isCatalog = true
        ..type = CollectionType.folder
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
            secretModeProvider.overrideWith(() => _FakeSecretMode(false)),
            tagFacetListViewModelProvider.overrideWith(
              () => _FakeTagFacetListViewModel([]),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ActionSheetHeader(
                  collection: collection,
                  tags: [tag1, tagHidden],
                  title: 'テストカタログ',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('通常タグ'), findsOneWidget);
      expect(find.text('秘密タグ'), findsNothing);
      expect(find.byType(AppTag), findsNWidgets(1));
    });

    testWidgets('シークレットモードONのときは非表示タグも表示されること', (tester) async {
      final tag1 = Tag()
        ..id = 1
        ..name = '通常タグ'
        ..key = '1::通常タグ';
      final tagHidden = Tag()
        ..id = 2
        ..name = '秘密タグ'
        ..key = '1::秘密タグ'
        ..isHidden = true;

      final collection = MediaCollection()
        ..title = 'テストカタログ'
        ..path = 'folder/test'
        ..isCatalog = true
        ..type = CollectionType.folder
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
            secretModeProvider.overrideWith(() => _FakeSecretMode(true)),
            tagFacetListViewModelProvider.overrideWith(
              () => _FakeTagFacetListViewModel([]),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ActionSheetHeader(
                  collection: collection,
                  tags: [tag1, tagHidden],
                  title: 'テストカタログ',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('通常タグ'), findsOneWidget);
      expect(find.text('秘密タグ'), findsOneWidget);
      expect(find.byType(AppTag), findsNWidgets(2));
    });

    testWidgets('タグが空の場合はAppTagが表示されないこと', (tester) async {
      final collection = MediaCollection()
        ..title = 'テストカタログ'
        ..path = 'folder/test'
        ..isCatalog = true
        ..type = CollectionType.folder
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
            secretModeProvider.overrideWith(() => _FakeSecretMode(false)),
            tagFacetListViewModelProvider.overrideWith(
              () => _FakeTagFacetListViewModel([]),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ActionSheetHeader(
                  collection: collection,
                  tags: const [],
                  title: 'テストカタログ',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('テストカタログ'), findsOneWidget);
      expect(find.byType(AppTag), findsNothing);
    });
  });
}
