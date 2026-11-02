import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/core/theme/app_theme.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_facet_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_view_model.dart';
import 'package:private_shelf/features/library/presentation/screens/tag_management_screen.dart';
import 'package:private_shelf/features/library/presentation/widgets/tag_form_sheet.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/tag/facet_chip.dart';

import '../../../../helpers/test_helpers.dart';

const _fontPath = String.fromEnvironment('UX_QA_FONT');
const _iconPath = String.fromEnvironment('UX_QA_ICON_FONT');
const _previewKey = ValueKey('charm-search-preview');

void main() {
  setUp(() => setupMockSharedPreferences());
  setUpAll(() async {
    if (_fontPath.isNotEmpty) {
      final loader = FontLoader('UxPreview');
      loader.addFont(File(_fontPath).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
    if (_iconPath.isNotEmpty) {
      final loader = FontLoader('MaterialIcons');
      loader.addFont(File(_iconPath).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });

  testWidgets('TagManagementScreen がエラーなく正常に描画され、タグ一覧が表示される', (tester) async {
    final semantics = tester.ensureSemantics();
    final testFacets = <TagFacet>[
      TagFacet()
        ..id = 1
        ..name = 'ジャンル'
        ..sortOrder = 0
        ..colorValue = 0xFF2196F3
        ..createdAt = DateTime(2026, 1, 1),
      TagFacet()
        ..id = 2
        ..name = '状態'
        ..sortOrder = 1
        ..colorValue = 0xFF4CAF50
        ..createdAt = DateTime(2026, 1, 1),
    ];

    final testTags = <Tag>[
      Tag()
        ..id = 1
        ..name = 'ファンタジー'
        ..facetId = 1
        ..usageCount = 5
        ..createdAt = DateTime(2026, 1, 1),
      Tag()
        ..id = 2
        ..name = '未読'
        ..facetId = 2
        ..usageCount = 12
        ..createdAt = DateTime(2026, 1, 2),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagListViewModelProvider.overrideWith(
            () => _FakeTagListViewModel(testTags),
          ),
          tagFacetListViewModelProvider.overrideWith(
            () => _FakeTagFacetListViewModel(testFacets),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('ja'),
          home: TagManagementScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 画面タイトルとタグが正常に表示されることを検証（AssertionError が発生しないこと）
    expect(find.text('チャーム管理'), findsOneWidget);
    expect(find.text('ファンタジー'), findsOneWidget);
    expect(find.text('未読'), findsOneWidget);
    expect(find.text('ジャンル'), findsWidgets);
    expect(find.text('状態'), findsWidgets);
    expect(find.byType(FloatingActionButton), findsNothing);
    final addButton = find.byKey(const ValueKey('tag-add-new'));
    expect(addButton, findsOneWidget);
    expect(tester.getSize(addButton).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(addButton).height, greaterThanOrEqualTo(48));
    final quickAddSize = tester.getSize(
      find.byKey(const ValueKey('tag-facet-quick-add-1')),
    );
    expect(quickAddSize.width, greaterThanOrEqualTo(48));
    expect(quickAddSize.height, greaterThanOrEqualTo(48));

    await tester.tap(find.byTooltip('メニュー'));
    await tester.pumpAndSettle();
    expect(find.text('ファイルから読み込む'), findsOneWidget);
    expect(find.text('ファイルに書き出す'), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    final tagNode = tester.getSemantics(find.bySemanticsLabel('ファンタジー, 5'));
    final tagSemantics = tagNode.getSemanticsData();
    expect(tagSemantics.hint, 'ファンタジー のその他の操作');
    expect(tagSemantics.hasAction(ui.SemanticsAction.tap), isTrue);
    expect(tagSemantics.hasAction(ui.SemanticsAction.longPress), isTrue);

    tester.semantics.tap(find.semantics.byLabel('ファンタジー, 5'));
    await tester.pumpAndSettle();

    expect(find.byType(TagFormSheet), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '削除'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '削除'));
    await tester.pumpAndSettle();

    expect(find.text('「ファンタジー」を削除しますか？'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('検索の原文と分類を引き継ぎ、改名・分類変更の保存後に新しい行を表示する', (tester) async {
    final saved = _SavedTags([_tag(1, 'Existing', 1)]);
    await _pumpManager(tester, saved, _facets());
    await tester.tap(find.byTooltip('リスト表示'));
    await tester.pumpAndSettle();
    await _selectManagerFacet(tester, 'ジャンル');
    await _search(tester, '  My TRIP  ');
    await _openSearchForm(tester);

    final sheet = tester.widget<TagFormSheet>(find.byType(TagFormSheet));
    expect(sheet.initialName, 'My TRIP');
    expect(sheet.initialFacetId, 1);
    expect(tester.widget<TextField>(_formField).controller!.text, 'My TRIP');
    await tester.enterText(_formField, 'Final Trip');
    await _selectFormFacet(tester, '状態');
    saved.publishGate = Completer<void>();
    await tester.tap(_formSave);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(saved.created.single.name, 'Final Trip');
    expect(saved.created.single.facetId, 2);
    expect(find.byType(TagFormSheet), findsNothing);
    saved.publishGate!.complete();
    await tester.pumpAndSettle();

    expect(_managerSearchText(tester), 'Final Trip');
    expect(_selectedManagerFacet(tester), '状態');
    expect(_rowName('Final Trip'), findsOneWidget);
    expect(find.byTooltip('チップ表示'), findsOneWidget);
    expect(find.byKey(const ValueKey('tag-create-from-search')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('検索から作成を取消しても検索を保持し、同じ語と分類から下書きを再開できる', (tester) async {
    final saved = _SavedTags([_tag(1, 'Existing', 1)]);
    await _pumpManager(tester, saved, _facets());
    await _selectManagerFacet(tester, 'ジャンル');
    await _search(tester, 'Original');
    await _openSearchForm(tester);
    await tester.enterText(_formField, 'Draft name');
    await _selectFormFacet(tester, '状態');
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(saved.created, isEmpty);
    expect(_managerSearchText(tester), 'Original');
    expect(_selectedManagerFacet(tester), 'ジャンル');
    await _openSearchForm(tester);
    expect(tester.widget<TextField>(_formField).controller!.text, 'Draft name');
    final draftFacet = tester.widget<FacetChip>(
      find.descendant(
        of: find.byType(TagFormSheet),
        matching: find.widgetWithText(FacetChip, '状態'),
      ),
    );
    expect(draftFacet.isSelected, isTrue);
    await tester.tap(_formSave);
    await tester.pumpAndSettle();

    expect(saved.created.single.name, 'Draft name');
    expect(saved.created.single.facetId, 2);
    expect(_managerSearchText(tester), 'Draft name');
    expect(_selectedManagerFacet(tester), '状態');
    expect(_rowName('Draft name'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('検索からの作成失敗はフォームと元の検索を保ち、再試行成功後だけ結果を更新する', (tester) async {
    final saved = _SavedTags([])..failSave = true;
    await _pumpManager(tester, saved, _facets());
    await _search(tester, 'New Charm');
    await _openSearchForm(tester);
    await tester.enterText(_formField, 'Changed Charm');
    await tester.tap(_formSave);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tag-form-save-error')), findsOneWidget);
    expect(saved.created, isEmpty);
    expect(
      tester.widget<TextField>(_formField).controller!.text,
      'Changed Charm',
    );
    expect(_managerSearchText(tester), 'New Charm');
    saved.failSave = false;
    await tester.tap(_formSave);
    await tester.pumpAndSettle();

    expect(saved.created.single.name, 'Changed Charm');
    expect(saved.created.single.facetId, 1);
    expect(_managerSearchText(tester), 'Changed Charm');
    expect(_selectedManagerFacet(tester), 'ジャンル');
    expect(_rowName('Changed Charm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('全件0でも検索語があれば作成を案内し、検索解除は保留入力を取り消す', (tester) async {
    await _pumpManager(tester, _SavedTags([]), _facets());
    expect(find.byKey(const ValueKey('tag-create-from-search')), findsNothing);
    await _search(tester, 'Missing');
    expect(
      find.byKey(const ValueKey('tag-create-from-search')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tag-search-all-categories')),
      findsNothing,
    );
    final clear = find.byKey(const ValueKey('tag-clear-search'));
    await _reveal(tester, clear);
    await tester.enterText(_managerSearchField, 'Pending');
    await tester.pump();
    // Exercise the pending-input race before 180 ms. Physical action reachability
    // is covered separately by the narrow-screen tests.
    tester.widget<TextButton>(clear).onPressed!();
    await tester.pump(const Duration(milliseconds: 500));

    expect(_managerSearchText(tester), isEmpty);
    expect(find.byKey(const ValueKey('tag-create-from-search')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('入力を空にした直後の作成操作は空フォームを開かず検索を解除する', (tester) async {
    await _pumpManager(tester, _SavedTags([]), _facets());
    await _search(tester, 'Missing');
    final create = find.byKey(const ValueKey('tag-create-from-search'));
    await _reveal(tester, create);
    await tester.enterText(_managerSearchField, '   ');
    await tester.pump();
    tester.widget<FilledButton>(create).onPressed!();
    await tester.pumpAndSettle();

    expect(find.byType(TagFormSheet), findsNothing);
    expect(_managerSearchText(tester), isEmpty);
    expect(find.byKey(const ValueKey('tag-create-from-search')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('別分類の一致がある時だけ分類を広げ、検索語は保持する', (tester) async {
    await _pumpManager(tester, _SavedTags([_tag(1, 'My TRIP', 2)]), _facets());
    await _selectManagerFacet(tester, 'ジャンル');
    await _search(tester, 'My TRIP');
    final expand = find.byKey(const ValueKey('tag-search-all-categories'));
    expect(expand, findsOneWidget);
    await _reveal(tester, expand);
    await tester.tap(expand);
    await tester.pumpAndSettle();

    expect(_managerSearchText(tester), 'My TRIP');
    expect(_selectedManagerFacet(tester), 'すべて');
    expect(_rowName('My TRIP'), findsOneWidget);
    await _search(tester, 'Nobody');
    expect(
      find.byKey(const ValueKey('tag-search-all-categories')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  for (final locale in [const Locale('ja'), const Locale('en')]) {
    for (final dark in [false, true]) {
      testWidgets(
        '${locale.languageCode} dark=$dark 320dp/200%の長い分類でも回復操作に届く',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final facets = _facets();
          facets.first.name = locale.languageCode == 'ja'
              ? '旅先で見つけた写真と作品の分類'
              : 'Travel photographs and favorite artworks';
          final saved = _SavedTags([_tag(1, 'Elsewhere', 2)]);
          await _pumpManager(
            tester,
            saved,
            facets,
            locale: locale,
            dark: dark,
            scale: 2,
          );
          await _selectManagerFacet(tester, facets.first.name);
          await _search(tester, 'Elsewhere');

          final l10n = AppLocalizations.of(
            tester.element(find.byType(TagManagementScreen)),
          )!;
          for (final tooltip in [l10n.tagViewList, l10n.tagSortTitle]) {
            final button = find.byTooltip(tooltip);
            await _reveal(tester, button);
            expect(button.hitTestable(), findsOneWidget);
            expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
            expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          }
          for (final key in [
            'tag-search-all-categories',
            'tag-create-from-search',
            'tag-clear-search',
          ]) {
            final action = find.byKey(ValueKey(key));
            await _reveal(tester, action);
            expect(action.hitTestable(), findsOneWidget);
            expect(tester.getSize(action).width, greaterThanOrEqualTo(48));
            expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
          }
          await tester.tap(find.byKey(const ValueKey('tag-clear-search')));
          await tester.pumpAndSettle();
          expect(_managerSearchText(tester), isEmpty);
          await _selectManagerFacet(tester, l10n.tagAllFacets);
          await _search(tester, 'New Trip');
          expect(
            find.byKey(const ValueKey('tag-search-all-categories')),
            findsNothing,
          );
          for (final key in ['tag-create-from-search', 'tag-clear-search']) {
            await _reveal(tester, find.byKey(ValueKey(key)));
          }
          await _openSearchForm(tester);
          await tester.enterText(_formField, 'Saved Trip');
          await _selectFormFacet(tester, facets.first.name);
          await _reveal(tester, _formSave);
          await tester.tap(_formSave);
          await tester.pumpAndSettle();
          expect(saved.created.single.facetId, 1);
          expect(_managerSearchText(tester), 'Saved Trip');
          expect(_selectedManagerFacet(tester), facets.first.name);
          expect(_rowName('Saved Trip'), findsOneWidget);
          for (final tooltip in [l10n.tagViewList, l10n.tagSortTitle]) {
            await _reveal(tester, find.byTooltip(tooltip));
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('チャーム検索から作成の代表preview', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpManager(tester, _SavedTags([_tag(1, '読書', 1)]), _facets());
    await _search(tester, '夏の旅行');
    expect(
      find.byKey(const ValueKey('tag-create-from-search')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    if (_fontPath.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_previewKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory('build/ux_review');
        await directory.create(recursive: true);
        await File(
          '${directory.path}/charm-search-create-ja.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  });
}

Finder get _formField => find.descendant(
  of: find.byType(TagFormSheet),
  matching: find.byType(TextField),
);

Finder get _formSave => find.descendant(
  of: find.byType(TagFormSheet),
  matching: find.byType(FilledButton),
);

Finder get _managerSearchField => find.descendant(
  of: find.byType(TagManagementScreen, skipOffstage: false),
  matching: find.byType(TextField, skipOffstage: false),
  skipOffstage: false,
);

Finder _rowName(String value) =>
    find.byWidgetPredicate((widget) => widget is Text && widget.data == value);

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  // Recompute layout after scrolling without advancing the 180 ms debounce.
  await tester.pump();
  // NestedScrollView can move the outer header while revealing the inner body.
  // Re-evaluate its laid-out position and avoid the pinned app bar's top edge.
  if (finder.hitTestable().evaluate().isEmpty) {
    await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
    await tester.pump();
  }
  // With a pinned header, nested ensureVisible can leave the inner viewport
  // at zero. Verify real gesture reachability instead of relying on that jump.
  for (
    var attempt = 0;
    attempt < 4 && finder.hitTestable().evaluate().isEmpty;
    attempt++
  ) {
    final center = tester.getRect(finder).center.dy;
    final height =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    await tester.drag(
      find.byType(NestedScrollView),
      Offset(0, center > height / 2 ? -180 : 180),
    );
    await tester.pump();
  }
  expect(finder.hitTestable(), findsOneWidget);
}

Future<void> _search(WidgetTester tester, String text) async {
  await _reveal(tester, _managerSearchField);
  await tester.enterText(_managerSearchField, text);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
}

Future<void> _openSearchForm(WidgetTester tester) async {
  final create = find.byKey(const ValueKey('tag-create-from-search'));
  await _reveal(tester, create);
  await tester.tap(create);
  await tester.pumpAndSettle();
  expect(find.byType(TagFormSheet), findsOneWidget);
}

String _managerSearchText(WidgetTester tester) =>
    tester.widget<TextField>(_managerSearchField).controller!.text;

String _selectedManagerFacet(WidgetTester tester) => tester
    .widgetList<FacetChip>(
      find.descendant(
        of: find.byType(TagManagementScreen, skipOffstage: false),
        matching: find.byType(FacetChip, skipOffstage: false),
        skipOffstage: false,
      ),
    )
    .singleWhere((chip) => chip.isSelected)
    .label;

Future<void> _selectManagerFacet(WidgetTester tester, String name) async {
  final chip = find.descendant(
    of: find.byType(TagManagementScreen, skipOffstage: false),
    matching: find.widgetWithText(FacetChip, name, skipOffstage: false),
    skipOffstage: false,
  );
  await tester.ensureVisible(chip);
  await tester.pump();
  // A long category chip can be wider than the horizontal viewport. Its
  // visible leading part remains a valid tap target even if its center is offscreen.
  final rect = tester.getRect(chip);
  await tester.tapAt(Offset(rect.left + 24, rect.center.dy));
  await tester.pumpAndSettle();
}

Future<void> _selectFormFacet(WidgetTester tester, String name) async {
  final chip = find.descendant(
    of: find.byType(TagFormSheet),
    matching: find.widgetWithText(FacetChip, name),
  );
  await tester.ensureVisible(chip);
  await tester.pump();
  final rect = tester.getRect(chip);
  await tester.tapAt(Offset(rect.left + 24, rect.center.dy));
  await tester.pumpAndSettle();
}

List<TagFacet> _facets() => [
  TagFacet()
    ..id = 1
    ..name = 'ジャンル'
    ..sortOrder = 0,
  TagFacet()
    ..id = 2
    ..name = '状態'
    ..sortOrder = 1,
];

Tag _tag(int id, String name, int facetId) => Tag()
  ..id = id
  ..name = name
  ..facetId = facetId;

class _SavedTags {
  _SavedTags(this.tags);
  final List<Tag> tags;
  final created = <Tag>[];
  bool failSave = false;
  Completer<void>? publishGate;
}

class _CreatingTagListViewModel extends TagListViewModel {
  _CreatingTagListViewModel(this.saved);
  final _SavedTags saved;

  @override
  Stream<List<Tag>> build() {
    final pending = saved.publishGate;
    return pending == null
        ? Stream.value([...saved.tags])
        : Stream.fromFuture(pending.future.then((_) => [...saved.tags]));
  }

  @override
  Future<Tag> addTag(
    String name, {
    int? facetId,
    int? parentId,
    int? level,
    int? colorValue,
    bool isHidden = false,
  }) async {
    if (saved.failSave) throw AppError.database('Save failed');
    final created = _tag(saved.tags.length + 1, name, facetId ?? 1)
      ..parentId = parentId
      ..isHidden = isHidden;
    saved.tags.add(created);
    saved.created.add(created);
    ref.invalidateSelf();
    return created;
  }
}

Future<void> _pumpManager(
  WidgetTester tester,
  _SavedTags saved,
  List<TagFacet> facets, {
  Locale locale = const Locale('ja'),
  bool dark = false,
  double scale = 1,
}) async {
  var theme = dark ? AppTheme.dark : AppTheme.light;
  if (_fontPath.isNotEmpty) {
    ButtonStyle withFont(ButtonStyle? style) =>
        (style ?? const ButtonStyle()).copyWith(
          textStyle: WidgetStateProperty.resolveWith(
            (states) => (style?.textStyle?.resolve(states) ?? const TextStyle())
                .copyWith(fontFamily: 'UxPreview'),
          ),
        );
    theme = theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: 'UxPreview'),
      primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'UxPreview'),
      filledButtonTheme: FilledButtonThemeData(
        style: withFont(theme.filledButtonTheme.style),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: withFont(theme.outlinedButtonTheme.style),
      ),
      textButtonTheme: TextButtonThemeData(
        style: withFont(theme.textButtonTheme.style),
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
          fontFamily: 'UxPreview',
        ),
        toolbarTextStyle: theme.appBarTheme.toolbarTextStyle?.copyWith(
          fontFamily: 'UxPreview',
        ),
      ),
      listTileTheme: theme.listTileTheme.copyWith(
        titleTextStyle: theme.listTileTheme.titleTextStyle?.copyWith(
          fontFamily: 'UxPreview',
        ),
        subtitleTextStyle: theme.listTileTheme.subtitleTextStyle?.copyWith(
          fontFamily: 'UxPreview',
        ),
      ),
      chipTheme: theme.chipTheme.copyWith(
        labelStyle: (theme.chipTheme.labelStyle ?? const TextStyle()).copyWith(
          fontFamily: 'UxPreview',
        ),
        secondaryLabelStyle:
            (theme.chipTheme.secondaryLabelStyle ?? const TextStyle()).copyWith(
              fontFamily: 'UxPreview',
            ),
      ),
    );
  }
  await tester.pumpWidget(
    createProviderApp(
      MediaQuery(
        data: MediaQueryData(
          size: tester.view.physicalSize / tester.view.devicePixelRatio,
          textScaler: TextScaler.linear(scale),
        ),
        child: const RepaintBoundary(
          key: _previewKey,
          child: TagManagementScreen(),
        ),
      ),
      theme: theme,
      locale: locale,
      overrides: [
        hapticsEnabledProvider.overrideWith((ref) => false),
        tagListViewModelProvider.overrideWith(
          () => _CreatingTagListViewModel(saved),
        ),
        tagFacetListViewModelProvider.overrideWith(
          () => _FakeTagFacetListViewModel(facets),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeTagListViewModel extends TagListViewModel {
  final List<Tag> initialTags;
  _FakeTagListViewModel(this.initialTags);

  @override
  Stream<List<Tag>> build() => Stream.value(initialTags);
}

class _FakeTagFacetListViewModel extends TagFacetListViewModel {
  final List<TagFacet> initialFacets;
  _FakeTagFacetListViewModel(this.initialFacets);

  @override
  Stream<List<TagFacet>> build() => Stream.value(initialFacets);
}
