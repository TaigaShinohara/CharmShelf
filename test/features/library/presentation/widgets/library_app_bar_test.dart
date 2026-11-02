import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/presentation/widgets/library_app_bar.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

Widget subject({
  required TextEditingController controller,
  MediaFilter filter = const MediaFilter(onlyCatalogs: true),
  ValueChanged<SearchTarget>? onTargetChanged,
  ValueChanged<bool>? onScopeChanged,
  VoidCallback? onStopSearch,
  ValueChanged<String>? onSubmitted,
  Locale locale = const Locale('ja'),
  double textScale = 1,
  int? selectionCount,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('ja'), Locale('en')],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: CustomScrollView(
      slivers: [
        LibraryAppBar(
          isSearching: true,
          selectionCount: selectionCount,
          hasBackButton: false,
          isLibraryRoot: true,
          filter: filter,
          searchController: controller,
          onBackButtonPressed: () {},
          onStopSearch: onStopSearch ?? () {},
          onSearchSubmitted: onSubmitted,
          onSearchTargetChanged: onTargetChanged ?? (_) {},
          onSearchScopeChanged: onScopeChanged,
          onOpenFilter: () {},
          actions: const [Icon(Icons.more_vert)],
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 800)),
      ],
    ),
  ),
);

void main() {
  testWidgets('選択件数が検索欄に優先し終了すると検索入力を復元する', (tester) async {
    final controller = TextEditingController(text: 'travel');
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final count in [1, 12, 0]) {
      await tester.pumpWidget(
        subject(controller: controller, selectionCount: count, textScale: 2),
      );
      await tester.pumpAndSettle();
      expect(find.text('$count件選択中'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(subject(controller: controller));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(controller.text, 'travel');
  });

  testWidgets(
    'default search needs no target choice and advanced options stay reachable',
    (tester) async {
      final controller = TextEditingController(text: 'travel');
      addTearDown(controller.dispose);
      await tester.pumpWidget(subject(controller: controller));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(LibraryAppBar)),
      )!;
      expect(find.text(l10n.librarySearchTargetFiles), findsNothing);
      expect(find.text(l10n.librarySearchScopeAll), findsNothing);
      expect(find.text(l10n.librarySearchTargetCatalogs), findsNothing);
      await tester.tap(find.byKey(const ValueKey('library-search-options')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.librarySearchFilesIncluded), findsOneWidget);
      expect(find.text(l10n.librarySearchCatalogsOnly), findsOneWidget);
      expect(controller.text, 'travel');
    },
  );

  testWidgets(
    'explicit catalogs target stays visible and can broaden without clearing input',
    (tester) async {
      final controller = TextEditingController(text: 'travel');
      addTearDown(controller.dispose);
      SearchTarget? selected;
      await tester.pumpWidget(
        subject(
          controller: controller,
          filter: const MediaFilter(searchTarget: SearchTarget.catalogsOnly),
          onTargetChanged: (value) => selected = value,
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(LibraryAppBar)),
      )!;
      await tester.tap(find.text(l10n.librarySearchTargetCatalogs));
      await tester.pumpAndSettle();
      expect(selected, SearchTarget.filesIncluded);
      expect(controller.text, 'travel');
    },
  );

  testWidgets('close invokes search exit rather than folder navigation', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'travel');
    addTearDown(controller.dispose);
    var stopped = false;
    await tester.pumpWidget(
      subject(controller: controller, onStopSearch: () => stopped = true),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(LibraryAppBar)),
    )!;
    await tester.tap(find.byTooltip(l10n.libraryCloseSearch));
    expect(stopped, isTrue);
  });

  for (final locale in ['ja', 'en']) {
    for (final target in [
      SearchTarget.catalogsOnly,
      SearchTarget.filesIncluded,
    ]) {
      testWidgets(
        '$locale $target: 320dp and 200% keep scope and target reachable',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final controller = TextEditingController(text: 'travel');
          addTearDown(controller.dispose);
          await tester.pumpWidget(
            subject(
              controller: controller,
              filter: MediaFilter(searchTarget: target),
              locale: Locale(locale),
              textScale: 2,
            ),
          );
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(
            tester.element(find.byType(LibraryAppBar)),
          )!;
          if (target == SearchTarget.catalogsOnly) {
            expect(
              find.text(l10n.librarySearchTargetCatalogs).hitTestable(),
              findsOneWidget,
            );
          } else {
            expect(find.text(l10n.librarySearchTargetFiles), findsNothing);
          }
          expect(tester.takeException(), isNull);
          await tester.tap(
            find.byKey(const ValueKey('library-search-options')),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(l10n.librarySearchFilesIncluded).hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('inside a folder, search can stay in that folder', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    bool? withinParent;
    await tester.pumpWidget(
      subject(
        controller: controller,
        filter: const MediaFilter(parentPath: 'library/trip'),
        onScopeChanged: (value) => withinParent = value,
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(LibraryAppBar)),
    )!;
    expect(find.text(l10n.librarySearchScopeAll), findsOneWidget);
    expect(find.text(l10n.librarySearchScopeCurrent), findsOneWidget);
    await tester.tap(find.text(l10n.librarySearchScopeCurrent));
    await tester.pump();
    expect(withinParent, isTrue);
    await tester.tap(find.text(l10n.librarySearchScopeAll));
    await tester.pump();
    expect(withinParent, isFalse);
  });
  for (final locale in ['ja', 'en']) {
    testWidgets('$locale: folder scope survives 200% text at 320dp', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TextEditingController(text: 'trip');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        subject(
          controller: controller,
          filter: const MediaFilter(parentPath: 'library/trip'),
          locale: Locale(locale),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('search-scope-current')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('search-scope-all')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
