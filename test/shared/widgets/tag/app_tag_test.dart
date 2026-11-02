import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/tag/app_tag.dart';

void main() {
  testWidgets('AppTagWrap は左詰めで、横幅を超えたチャームを次の行へ送る', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              child: AppTagWrap(
                key: ValueKey('app-tag-wrap'),
                spacing: 4,
                runSpacing: 4,
                children: [
                  AppTag(label: 'チャームA', size: AppTagSize.large),
                  AppTag(label: 'チャームB', size: AppTagSize.large),
                  AppTag(label: 'チャームC', size: AppTagSize.large),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final wrapRect = tester.getRect(find.byKey(const ValueKey('app-tag-wrap')));
    final tagRects = ['チャームA', 'チャームB', 'チャームC']
        .map((label) => tester.getRect(find.widgetWithText(AppTag, label)))
        .toList();
    final secondRowRect = tagRects.firstWhere(
      (rect) => rect.top > tagRects.first.top + 1,
    );

    expect(wrapRect.width, 120);
    expect(tagRects.first.left, closeTo(wrapRect.left, 0.01));
    expect(secondRowRect.left, closeTo(wrapRect.left, 0.01));
    expect(tester.takeException(), isNull);
  });

  for (final interactive in [false, true]) {
    testWidgets('チャーム本体が左詰めで横並び・折り返しする interactive=$interactive', (
      tester,
    ) async {
      var tapped = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 110,
                child: AppTagWrap(
                  key: const ValueKey('layout'),
                  spacing: 4,
                  runSpacing: 6,
                  children: [
                    for (final label in ['A', 'B', 'C', 'D', 'E'])
                      AppTag(
                        label: label,
                        onTap: interactive ? () => tapped = label : null,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final tags = find.byType(AppTag);
      final outer = [for (var i = 0; i < 5; i++) tester.getRect(tags.at(i))];
      final visual = [
        for (var i = 0; i < 5; i++)
          tester.getRect(
            find.descendant(
              of: tags.at(i),
              matching: find.byType(AnimatedContainer),
            ),
          ),
      ];
      final left = tester.getRect(find.byKey(const ValueKey('layout'))).left;
      expect(outer[1].top, outer[0].top, reason: '短いチャームは同じ行に並ぶ');
      expect(visual[0].left, left, reason: '外枠だけでなく本体も左詰め');
      for (var i = 0; i < 5; i++) {
        expect(visual[i].left, outer[i].left);
        expect(outer[i].width, lessThan(110));
        if (interactive) {
          expect(outer[i].width, greaterThanOrEqualTo(48));
          expect(outer[i].height, greaterThanOrEqualTo(48));
        } else {
          expect(outer[i].size, visual[i].size);
        }
        if (i > 0) expect(outer[i].overlaps(outer[i - 1]), isFalse);
      }
      final nextRow = outer.firstWhere((r) => r.top > outer.first.top);
      expect(nextRow.left, left);
      expect(nextRow.top - outer.first.bottom, closeTo(6, .01));
      if (interactive) {
        await tester.tapAt(Offset(outer[1].right - 2, outer[1].center.dy));
        expect(tapped, 'B');
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('長い名前とアクションが狭い幅でも収まり個別に操作できる scale=$scale', (tester) async {
      var taps = 0;
      var actions = 0;
      var longPresses = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 160,
                  child: AppTagWrap(
                    children: [
                      AppTag(
                        label: '旅行の写真と動画をまとめた長いチャーム',
                        maxLines: null,
                        size: AppTagSize.large,
                        count: '12',
                        onTap: () => taps++,
                        onLongPress: () => longPresses++,
                        actionType: AppTagActionType.minus,
                        onAction: () => actions++,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final tag = tester.getRect(find.byType(AppTag));
      expect(tag.width, lessThanOrEqualTo(160));
      final text = find.text('旅行の写真と動画をまとめた長いチャーム');
      expect(tester.getRect(text).height, greaterThan(20));
      await tester.tap(text);
      expect(taps, 1);
      await tester.tap(find.byIcon(Icons.close));
      expect(actions, 1);
      expect(taps, 1, reason: 'アクションはラベル側のタップを発火しない');
      await tester.longPress(text);
      expect(longPresses, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('AppTag はラベルとアクションをセマンティクスへ公開する', (tester) async {
    final semantics = tester.ensureSemantics();

    var tapped = false;
    var actionTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ja'),
        home: Scaffold(
          body: Center(
            child: AppTag(
              label: '公開タグ',
              count: '3',
              onTap: () => tapped = true,
              actionType: AppTagActionType.minus,
              onAction: () => actionTapped = true,
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('公開タグ, 3'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('app-tag-action-公開タグ'))),
      const Size(48, 48),
    );

    final data = tester
        .getSemantics(find.bySemanticsLabel('公開タグ, 3'))
        .getSemanticsData();
    final customActionLabels = data.customSemanticsActionIds!
        .map(CustomSemanticsAction.getAction)
        .map((action) => action?.label);
    expect(customActionLabels, contains('公開タグ を削除'));

    await tester.tap(find.text('公開タグ'));
    expect(tapped, isTrue);

    await tester.tap(find.byIcon(Icons.close));
    expect(actionTapped, isTrue);

    semantics.dispose();
  });

  testWidgets('AppTag は長押し操作とヒントをセマンティクスへ公開する', (tester) async {
    final semantics = tester.ensureSemantics();
    var longPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ja'),
        home: Scaffold(
          body: AppTag(
            label: '長押しタグ',
            onTap: () {},
            onLongPress: () => longPressed = true,
            longPressHint: '長押しタグ のその他の操作',
          ),
        ),
      ),
    );

    final data = tester
        .getSemantics(find.bySemanticsLabel('長押しタグ'))
        .getSemanticsData();
    expect(data.hint, '長押しタグ のその他の操作');
    expect(data.hasAction(ui.SemanticsAction.longPress), isTrue);

    await tester.longPress(find.text('長押しタグ'));
    expect(longPressed, isTrue);
    semantics.dispose();
  });

  testWidgets('AppTag は plus アクションと強調選択スタイルを正常にレンダリングする', (tester) async {
    var actionTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ja'),
        home: Scaffold(
          body: AppTag(
            label: '追加タグ',
            actionType: AppTagActionType.plus,
            onAction: () => actionTapped = true,
            emphasizeSelectionStyle: true,
            color: Colors.blue,
          ),
        ),
      ),
    );

    expect(find.text('追加タグ'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.bySemanticsLabel('追加タグ を追加'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    expect(actionTapped, isTrue);
  });

  testWidgets('操作のない AppTag はコンパクトな表示を維持する', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('ja'),
        home: Scaffold(
          body: Center(child: AppTag(label: '表示タグ')),
        ),
      ),
    );

    final visualTag = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    expect(visualTag.constraints, isNull);
  });

  testWidgets('操作可能な AppTag は最小 48dp のタップ領域を持つ', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ja'),
        home: Scaffold(
          body: Wrap(
            children: [AppTag(label: '操作タグ', onTap: () => tapped = true)],
          ),
        ),
      ),
    );

    final hitTarget = find.byWidgetPredicate(
      (widget) =>
          widget is ConstrainedBox && widget.constraints.minHeight == 48,
    );
    expect(tester.getSize(hitTarget).height, greaterThanOrEqualTo(48));

    await tester.tap(hitTarget);
    expect(tapped, isTrue);
  });

  testWidgets('AppTag は isSelected: true でチェックアイコンと選択スタイルを適用する', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ja'),
        home: Scaffold(
          body: AppTag(
            label: '選択中タグ',
            count: '5',
            isSelected: true,
            color: Colors.purple,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('選択中タグ'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.tap(find.text('選択中タグ'));
    expect(tapped, isTrue);
  });

  testWidgets('AppTag は count が 0 のときにバッジを非表示にする', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('ja'),
        home: Scaffold(
          body: AppTag(label: 'ゼロタグ', count: '0'),
        ),
      ),
    );

    expect(find.text('ゼロタグ'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });
}
