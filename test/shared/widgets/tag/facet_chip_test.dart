import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/shared/widgets/tag/facet_chip.dart';

void main() {
  const previewFont = String.fromEnvironment('UX_QA_FONT');
  setUpAll(() async {
    if (previewFont.isEmpty) return;
    final loader = FontLoader('FacetPreview');
    loader.addFont(File(previewFont).readAsBytes().then(ByteData.sublistView));
    await loader.load();
  });

  testWidgets('FacetChip はラベルとカウントを正常にレンダリングする', (tester) async {
    final semantics = tester.ensureSemantics();
    var selected = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: [
              FacetChip(
                label: 'コンテンツタイプ',
                count: 12,
                color: Colors.orange,
                isSelected: false,
                onSelected: (val) => selected = val,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('コンテンツタイプ'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    final semanticFinder = find.bySemanticsLabel('コンテンツタイプ, 12');
    expect(semanticFinder, findsOneWidget);
    expect(
      tester.getSize(find.byType(FilterChip)).height,
      greaterThanOrEqualTo(48),
    );
    final data = tester.getSemantics(semanticFinder).getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isEnabled, ui.Tristate.isTrue);
    expect(data.flagsCollection.isSelected, ui.Tristate.isFalse);
    expect(data.hasAction(ui.SemanticsAction.tap), isTrue);

    await tester.tap(find.text('コンテンツタイプ'));
    expect(selected, isTrue);
    semantics.dispose();
  });

  testWidgets('FacetChip は isSelected: true で選択スタイルを適用する', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: [
              FacetChip(label: 'ジャンル', isSelected: true, showDot: false),
            ],
          ),
        ),
      ),
    );

    expect(find.text('ジャンル'), findsOneWidget);
    final data = tester
        .getSemantics(find.bySemanticsLabel('ジャンル'))
        .getSemanticsData();
    expect(data.flagsCollection.isButton, isFalse);
    expect(data.flagsCollection.isEnabled, ui.Tristate.isFalse);
    expect(data.flagsCollection.isSelected, ui.Tristate.isTrue);
    expect(data.hasAction(ui.SemanticsAction.tap), isFalse);
    semantics.dispose();
  });

  for (final name in [
    '旅先で見つけた写真と好きな作品の分類',
    'Travel photographs and favorite artworks',
  ]) {
    testWidgets('$name 有限幅200%で点・件数・折返し境界でも全文が収まる', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        for (final width in [224.0, 248.0, 280.0]) {
          for (final selectedState in [false, true]) {
            for (final showDot in [false, true]) {
              for (final count in <int?>[null, 124]) {
                bool? selected;
                await tester.pumpWidget(
                  MaterialApp(
                    key: ValueKey('$width-$selectedState-$showDot-$count'),
                    theme: ThemeData(
                      fontFamily: previewFont.isEmpty ? null : 'FacetPreview',
                    ),
                    home: MediaQuery(
                      data: const MediaQueryData(
                        textScaler: TextScaler.linear(2),
                      ),
                      child: Scaffold(
                        body: SizedBox(
                          width: width,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FacetChip(
                                label: name,
                                isSelected: selectedState,
                                showDot: showDot,
                                count: count,
                                onSelected: (value) => selected = value,
                              ),
                              const FacetChip(label: 'Next', showDot: false),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                final chip = find.ancestor(
                  of: find.text(name),
                  matching: find.byType(FilterChip),
                );
                final bounds = tester.getRect(chip);
                expect(bounds.width, lessThanOrEqualTo(width));
                expect(bounds.height, greaterThanOrEqualTo(48));
                _expectFullTextInside(tester, name, bounds, wrapped: true);
                if (count != null) {
                  _expectFullTextInside(tester, '$count', bounds);
                }
                final next = tester.getRect(
                  find.ancestor(
                    of: find.text('Next'),
                    matching: find.byType(FilterChip),
                  ),
                );
                expect(next.top, greaterThanOrEqualTo(bounds.bottom));
                final label = count == null ? name : '$name, $count';
                final data = tester
                    .getSemantics(find.bySemanticsLabel(label))
                    .getSemanticsData();
                expect(data.flagsCollection.isEnabled, ui.Tristate.isTrue);
                expect(
                  data.flagsCollection.isSelected,
                  selectedState ? ui.Tristate.isTrue : ui.Tristate.isFalse,
                );
                expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
                await tester.tap(chip);
                expect(selected, !selectedState);
                expect(tester.takeException(), isNull);
              }
            }
          }
        }
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('$name 水平無限幅200%で自然幅と選択操作を保つ', (tester) async {
      for (final showDot in [false, true]) {
        for (final count in <int?>[null, 124]) {
          var selected = false;
          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey('$showDot-$count'),
              theme: ThemeData(
                fontFamily: previewFont.isEmpty ? null : 'FacetPreview',
              ),
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: Scaffold(
                  body: SizedBox(
                    width: 280,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FacetChip(
                            label: name,
                            showDot: showDot,
                            count: count,
                            onSelected: (value) => selected = value,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final chip = find.byType(FilterChip);
          final bounds = tester.getRect(chip);
          expect(bounds.width, greaterThan(280));
          _expectFullTextInside(tester, name, bounds, wrapped: false);
          if (count != null) _expectFullTextInside(tester, '$count', bounds);
          // The visible left part of a chip wider than the viewport is usable.
          await tester.tapAt(const Offset(30, 24));
          expect(selected, isTrue);
          expect(tester.takeException(), isNull);
        }
      }
    });
  }
}

void _expectFullTextInside(
  WidgetTester tester,
  String text,
  Rect bounds, {
  bool? wrapped,
}) {
  final finder = find.text(text);
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final painter = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
    locale: paragraph.locale,
    strutStyle: paragraph.strutStyle,
    textWidthBasis: paragraph.textWidthBasis,
    textHeightBehavior: paragraph.textHeightBehavior,
  )..layout(maxWidth: paragraph.size.width);
  try {
    expect(paragraph.size.height, greaterThanOrEqualTo(painter.height - 0.01));
    final rect = tester.getRect(finder);
    expect(rect.left, greaterThanOrEqualTo(bounds.left - 0.01));
    expect(rect.right, lessThanOrEqualTo(bounds.right + 0.01));
    expect(rect.top, greaterThanOrEqualTo(bounds.top - 0.01));
    expect(rect.bottom, lessThanOrEqualTo(bounds.bottom + 0.01));
    if (wrapped != null) {
      expect(
        painter.computeLineMetrics().length,
        wrapped ? greaterThan(1) : equals(1),
      );
    }
  } finally {
    painter.dispose();
  }
}
