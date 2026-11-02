import 'dart:ui' as ui;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/presentation/widgets/facet_form_sheet.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_facet_view_model.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/sheets/sheet_handle.dart';

import '../../../../helpers/test_helpers.dart';

class _FacetSave {
  final gate = Completer<void>();
  int calls = 0;
}

class _DelayedFacets extends TagFacetListViewModel {
  _DelayedFacets(this.save);
  final _FacetSave save;
  @override
  Stream<List<TagFacet>> build() => Stream.value([]);
  @override
  Future<void> addFacet(String name, {int? colorValue, int? sortOrder}) async {
    save.calls++;
    await save.gate.future;
    throw AppError.validation('Save failed');
  }
}

void main() {
  testWidgets('分類色は48dpの名前付きボタンとして選択状態を公開する', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      createProviderApp(const Scaffold(body: FacetFormSheet())),
    );
    await tester.pumpAndSettle();

    final firstColor = find.byKey(const ValueKey('facet-color-0'));
    expect(firstColor, findsOneWidget);
    expect(find.bySemanticsLabel('カラー 1'), findsOneWidget);
    final size = tester.getSize(firstColor);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));

    await tester.tap(firstColor);
    await tester.pumpAndSettle();

    final data = tester.getSemantics(firstColor).getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isSelected, ui.Tristate.isTrue);
    expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
    semantics.dispose();
  });

  testWidgets('分類シートを閉じても名前と選択色が次回に復元される', (tester) async {
    await tester.pumpWidget(
      createProviderApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showFacetFormSheet(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'my-trips');
    await tester.tap(find.byKey(const ValueKey('facet-color-1')));
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(FacetFormSheet), findsNothing);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'my-trips',
    );
    final selected = tester
        .getSemantics(find.byKey(const ValueKey('facet-color-1')))
        .getSemanticsData();
    expect(selected.flagsCollection.isSelected, ui.Tristate.isTrue);
  });
  testWidgets('分類保存中は閉じる経路と二重作成を防ぎ、失敗後は入力を保持して閉じられる', (tester) async {
    final save = _FacetSave();
    await tester.pumpWidget(
      createProviderApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showFacetFormSheet(context),
            child: const Text('open'),
          ),
        ),
        overrides: [
          tagFacetListViewModelProvider.overrideWith(
            () => _DelayedFacets(save),
          ),
        ],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'slow-category');
    final action = tester
        .widget<FilledButton>(find.byType(FilledButton))
        .onPressed!;
    action();
    action();
    await tester.pump();
    expect(save.calls, 1);
    final form = find.byType(FacetFormSheet);
    final l10n = AppLocalizations.of(tester.element(form))!;
    final close = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == l10n.tooltipClose,
    );
    expect(tester.widget<IconButton>(close).onPressed, isNull);
    await tester.tap(close);
    Navigator.of(tester.element(form)).pop();
    await tester.tapAt(const Offset(5, 5));
    await tester.binding.handlePopRoute();
    await tester.dragFrom(
      tester.getCenter(find.byType(SheetHandle)),
      const Offset(0, 600),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(form, findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'slow-category',
    );
    save.gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('facet-form-save-error')), findsOneWidget);
    expect(tester.widget<IconButton>(close).onPressed, isNotNull);
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(form, findsNothing);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'slow-category',
    );
    expect(tester.takeException(), isNull);
  });
}
