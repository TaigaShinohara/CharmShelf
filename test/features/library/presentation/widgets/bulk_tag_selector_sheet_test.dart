import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_facet_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_view_model.dart';
import 'package:private_shelf/features/library/presentation/widgets/bulk_tag_selector_sheet.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

void main() {
  testWidgets('BulkTagSelectorSheet がエラーなく正常に描画され、タグ一覧が表示される', (tester) async {
    final testFacets = <TagFacet>[
      TagFacet()
        ..id = 1
        ..name = 'コンテンツタイプ'
        ..sortOrder = 0
        ..colorValue = 0xFFFF9800
        ..createdAt = DateTime(2026, 1, 1),
      TagFacet()
        ..id = 2
        ..name = 'ジャンル'
        ..sortOrder = 1
        ..colorValue = 0xFF2196F3
        ..createdAt = DateTime(2026, 1, 1),
    ];

    final testTags = <Tag>[
      Tag()
        ..id = 1
        ..name = 'アニメ'
        ..facetId = 1
        ..usageCount = 8
        ..createdAt = DateTime(2026, 1, 1),
      Tag()
        ..id = 2
        ..name = 'SF'
        ..facetId = 2
        ..usageCount = 14
        ..createdAt = DateTime(2026, 1, 2),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visibleTagListProvider.overrideWithValue(AsyncValue.data(testTags)),
          tagFacetListViewModelProvider.overrideWith(
            () => _FakeTagFacetListViewModel(testFacets),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ja'),
          home: Scaffold(
            body: BulkTagSelectorSheet(
              selectedCount: 3,
              onApply: (tags) async {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('アニメ'), findsOneWidget);
    expect(find.text('SF'), findsOneWidget);
    expect(find.text('コンテンツタイプ'), findsWidgets);
    expect(find.text('ジャンル'), findsWidgets);

    final quickAdd = find.byKey(const ValueKey('bulk-tag-facet-quick-add-1'));
    expect(quickAdd, findsOneWidget);
    expect(tester.getSize(quickAdd).height, greaterThanOrEqualTo(48));

    await tester.tap(find.text('アニメ'));
    await tester.pumpAndSettle();

    final selectedSection = find.byKey(
      const ValueKey('bulk-tag-selected-section'),
    );
    expect(selectedSection, findsOneWidget);
    expect(find.text('1個選択中'), findsOneWidget);
    expect(find.text('適用 (1個選択中)'), findsOneWidget);

    final fixedSectionY = tester.getTopLeft(selectedSection).dy;
    await tester.drag(find.text('SF'), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(selectedSection).dy, fixedSectionY);
    expect(find.text('適用 (1個選択中)'), findsOneWidget);
  });
}

class _FakeTagFacetListViewModel extends TagFacetListViewModel {
  final List<TagFacet> initialFacets;
  _FakeTagFacetListViewModel(this.initialFacets);

  @override
  Stream<List<TagFacet>> build() => Stream.value(initialFacets);
}
