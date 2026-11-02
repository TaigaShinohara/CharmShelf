import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/theme/app_theme.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/widgets/library_discovery_empty_state.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

import '../../../../helpers/test_helpers.dart';

const _previewFont = String.fromEnvironment('UX_QA_FONT');
const _previewIcons = String.fromEnvironment('UX_QA_ICON_FONT');
const _previewBoundary = ValueKey('discovery-preview');

Widget subject({
  required MediaFilter filter,
  bool? defaultHiddenFilter = false,
  Locale locale = const Locale('ja'),
  double textScale = 1,
  bool dark = false,
  List<String>? actions,
}) {
  var theme = dark ? AppTheme.dark : AppTheme.light;
  if (_previewFont.isNotEmpty) {
    ButtonStyle withPreviewFont(ButtonStyle? style) {
      final textStyle = style?.textStyle?.resolve({}) ?? const TextStyle();
      return (style ?? const ButtonStyle()).copyWith(
        textStyle: WidgetStatePropertyAll(
          textStyle.copyWith(fontFamily: 'UxPreview'),
        ),
      );
    }

    theme = theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: 'UxPreview'),
      filledButtonTheme: FilledButtonThemeData(
        style: withPreviewFont(theme.filledButtonTheme.style),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: withPreviewFont(theme.outlinedButtonTheme.style),
      ),
      textButtonTheme: TextButtonThemeData(
        style: withPreviewFont(theme.textButtonTheme.style),
      ),
    );
  }
  return createLocalizedApp(
    RepaintBoundary(
      key: _previewBoundary,
      child: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: LibraryDiscoveryEmptyState(
            conditions: LibraryDiscoveryConditions(
              filter: filter,
              defaultHiddenFilter: defaultHiddenFilter,
            ),
            onSearchEntireLibrary: () => actions?.add('scope'),
            onIncludeFiles: () => actions?.add('files'),
            onClearFilters: () => actions?.add('filters'),
            onClearSearch: () => actions?.add('search'),
            onClearAll: () => actions?.add('all'),
          ),
        ),
      ),
    ),
    theme: theme,
    locale: locale,
  );
}

Finder action(String key) => find.byKey(ValueKey('discovery-$key'));

void main() {
  setUpAll(() async {
    for (final font in [
      ('UxPreview', _previewFont),
      ('MaterialIcons', _previewIcons),
    ]) {
      if (font.$2.isEmpty) continue;
      final loader = FontLoader(font.$1);
      loader.addFont(File(font.$2).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });

  testWidgets('語だけの0件では表記の見直しと検索解除だけを示す', (tester) async {
    final actions = <String>[];
    // The catalog display setting is dormant while searching all items.
    await tester.pumpWidget(
      subject(
        filter: const MediaFilter(searchQuery: '旅', onlyCatalogs: true),
        actions: actions,
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(LibraryDiscoveryEmptyState)),
    )!;
    expect(find.text(l10n.librarySearchNoResultsQueryGuidance), findsOneWidget);
    expect(action('clear-filters'), findsNothing);
    expect(action('include-files'), findsNothing);
    expect(action('search-entire-library'), findsNothing);
    expect(find.text(l10n.libraryClearSearch), findsOneWidget);
    await tester.tap(action('clear-search'));
    expect(actions, ['search']);
  });

  testWidgets('複合制限は入力を残す範囲・対象・絞り込みの順に提示する', (tester) async {
    final actions = <String>[];
    await tester.pumpWidget(
      subject(
        filter: const MediaFilter(
          searchQuery: '旅',
          parentPath: 'library/trip',
          searchWithinParent: true,
          searchTarget: SearchTarget.catalogsOnly,
          isFavorite: true,
        ),
        actions: actions,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.ancestor(
        of: action('search-entire-library'),
        matching: find.byType(Wrap),
      ),
      findsOneWidget,
    );
    final wrap = tester.widget<Wrap>(find.byType(Wrap));
    expect(wrap.children.map((child) => child.key), [
      const ValueKey('discovery-search-entire-library'),
      const ValueKey('discovery-include-files'),
      const ValueKey('discovery-clear-filters'),
      const ValueKey('discovery-clear-search'),
    ]);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNWidgets(2));
    expect(find.text('検索と絞り込みを解除'), findsOneWidget);
    for (final key in [
      'search-entire-library',
      'include-files',
      'clear-filters',
      'clear-search',
    ]) {
      await tester.tap(action(key));
    }
    expect(actions, ['scope', 'files', 'filters', 'all']);
  });

  testWidgets('語なしカタログ表示では検索対象の残存値によらず表示を解除する', (tester) async {
    final actions = <String>[];
    await tester.pumpWidget(
      subject(
        filter: const MediaFilter(
          onlyCatalogs: true,
          parentPath: 'library/trip',
          searchWithinParent: true,
          searchTarget: SearchTarget.catalogsOnly,
        ),
        actions: actions,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ファイルも表示'), findsOneWidget);
    expect(action('search-entire-library'), findsNothing);
    expect(action('clear-filters'), findsNothing);
    expect(action('clear-search'), findsNothing);
    await tester.tap(action('include-files'));
    expect(actions, ['files']);
  });

  testWidgets('各解除可能条件とモード既定の非表示保護を区別する', (tester) async {
    for (final filter in [
      const MediaFilter(tagIds: [1]),
      const MediaFilter(excludedTagIds: [1]),
      const MediaFilter(tiers: [1]),
      const MediaFilter(mediaTypes: [MediaType.file]),
      const MediaFilter(hasTags: false),
      const MediaFilter(isFavorite: false),
      const MediaFilter(isHidden: true),
    ]) {
      await tester.pumpWidget(subject(filter: filter));
      await tester.pumpAndSettle();
      expect(action('clear-filters'), findsOneWidget, reason: '$filter');
      expect(action('clear-search'), findsNothing);
    }
    for (final defaultHidden in [false, null]) {
      final conditions = LibraryDiscoveryConditions(
        filter: MediaFilter(
          isHidden: defaultHidden,
          searchQuery: '  ',
          searchTarget: SearchTarget.catalogsOnly,
          searchWithinParent: true,
          parentPath: 'library/trip',
          sortOrder: SortOrder.nameAsc,
        ),
        defaultHiddenFilter: defaultHidden,
      );
      expect(conditions.hasConditions, isFalse);
      expect(conditions.hasFilters, isFalse);
      expect(conditions.canSearchEntireLibrary, isFalse);
      expect(conditions.canIncludeFiles, isFalse);
    }
    await tester.pumpWidget(
      subject(
        filter: const MediaFilter(isHidden: false),
        defaultHiddenFilter: null,
      ),
    );
    await tester.pumpAndSettle();
    expect(action('clear-filters'), findsOneWidget);
  });

  for (final locale in ['ja', 'en']) {
    for (final dark in [false, true]) {
      testWidgets('$locale dark=$dark: 320dp・文字200%でも全操作へ届く', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final actions = <String>[];
        await tester.pumpWidget(
          subject(
            filter: const MediaFilter(
              searchQuery: '旅',
              parentPath: 'library/trip',
              searchWithinParent: true,
              searchTarget: SearchTarget.catalogsOnly,
              tagIds: [1],
            ),
            locale: Locale(locale),
            textScale: 2,
            dark: dark,
            actions: actions,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final key in [
          'search-entire-library',
          'include-files',
          'clear-filters',
          'clear-search',
        ]) {
          await tester.ensureVisible(action(key));
          expect(action(key).hitTestable(), findsOneWidget);
          expect(tester.getSize(action(key)).height, greaterThanOrEqualTo(48));
          await tester.tap(action(key));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(actions, ['scope', 'files', 'filters', 'all']);
      });
    }
  }

  testWidgets('代表画面で説明と回復操作を表示し、任意で画像を出力する', (tester) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      subject(
        filter: const MediaFilter(
          searchQuery: '旅',
          parentPath: 'library/trip',
          searchWithinParent: true,
          searchTarget: SearchTarget.catalogsOnly,
          tagIds: [1],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('条件に一致するアイテムがありません'), findsOneWidget);
    expect(find.text('検索語を残して、範囲や条件を変えられます。'), findsOneWidget);
    expect(action('search-entire-library').hitTestable(), findsOneWidget);
    expect(action('clear-search').hitTestable(), findsOneWidget);
    if (_previewFont.isEmpty) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_previewBoundary),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory('build/ux_review');
        await directory.create(recursive: true);
        await File('${directory.path}/search-recovery-ja.png').writeAsBytes(
          data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
      } finally {
        image.dispose();
      }
    });
  });
}
