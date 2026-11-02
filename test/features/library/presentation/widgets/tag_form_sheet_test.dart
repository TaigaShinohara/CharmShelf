import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_facet_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_view_model.dart';
import 'package:private_shelf/features/library/presentation/widgets/tag_form_sheet.dart';

import '../../../../helpers/test_helpers.dart';

class _Facets extends TagFacetListViewModel {
  @override
  Stream<List<TagFacet>> build() => Stream.value([]);
}

class _SavedTags {
  bool failSave = false;
  final names = <String>[];
}

class _Tags extends TagListViewModel {
  _Tags(this.saved);
  final _SavedTags saved;

  @override
  Stream<List<Tag>> build() => Stream.value([]);

  @override
  Future<Tag> addTag(
    String name, {
    int? facetId,
    int? parentId,
    int? level,
    int? colorValue,
    bool isHidden = false,
  }) async {
    if (saved.failSave) throw AppError.validation('Save failed');
    saved.names.add(name);
    return Tag()
      ..id = saved.names.length
      ..name = name;
  }
}

void main() {
  testWidgets('閉じても入力を復元し、保存失敗は保持、成功した下書きだけ消す', (tester) async {
    final tags = _SavedTags();
    await tester.pumpWidget(
      createProviderApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showTagFormSheet(context),
            child: const Text('open'),
          ),
        ),
        overrides: [
          tagFacetListViewModelProvider.overrideWith(() => _Facets()),
          tagListViewModelProvider.overrideWith(() => _Tags(tags)),
        ],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'draft-trip');
    // The scrim used to discard this input silently.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(TagFormSheet), findsNothing);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'draft-trip',
    );
    tags.failSave = true;
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.byType(TagFormSheet), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'draft-trip',
    );
    expect(tags.names, isEmpty);

    tags.failSave = false;
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(tags.names, ['draft-trip']);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
  });

  testWidgets('空のフォームは確認なしで閉じ、検索語は再入力せず引き継ぐ', (tester) async {
    await tester.pumpWidget(
      createProviderApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showTagFormSheet(context, initialName: 'Summer2026'),
            child: const Text('open'),
          ),
        ),
        overrides: [
          tagFacetListViewModelProvider.overrideWith(() => _Facets()),
        ],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Summer2026',
    );
    await tester.enterText(find.byType(TextField), '');
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(TagFormSheet), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets('別の検索語からの作成は以前の語の下書きと混ざらない', (tester) async {
    var initialName = 'query-a';
    await tester.pumpWidget(
      createProviderApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showTagFormSheet(context, initialName: initialName),
            child: const Text('open'),
          ),
        ),
        overrides: [
          tagFacetListViewModelProvider.overrideWith(() => _Facets()),
        ],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'draft-for-a');
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    initialName = 'query-b';
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'query-b',
    );
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    initialName = 'query-a';
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'draft-for-a',
    );
  });
}
