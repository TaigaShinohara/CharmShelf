import 'dart:async';
import 'package:private_shelf/features/library/presentation/providers/catalog_viewer_items_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/core/preferences/app_preferences.dart';
import 'package:private_shelf/core/providers/tab_navigation_provider.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/import_execution_report.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/viewer_source_context.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/presentation/providers/import_flow_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/import_result_revision_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/features/library/presentation/screens/import_results_screen.dart';
import 'package:private_shelf/features/library/presentation/screens/import_selection_screen.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

class _Repository extends Mock implements MediaRepository {}

class _CompletedFlow extends ImportFlowNotifier {
  _CompletedFlow(this.report, this.status);
  final ImportFlowStatus status;
  final ImportExecutionReport report;
  @override
  ImportFlowState build() =>
      ImportFlowState(status: status, importReport: report);
  @override
  Future<void> restoreDraftSession() async {}
  @override
  Future<void> reset() async => state = ImportFlowState();
}

class _Filter extends MediaFilterNotifier {
  @override
  MediaFilter build(AppMode mode) => const MediaFilter(isHidden: false);
}

class _Fixture {
  _Fixture({required int importedCount, bool catalog = true}) {
    files = [
      for (var i = 0; i < importedCount; i++)
        MediaItem()
          ..id = 20 + i
          ..uid = 'imported-$i'
          ..path = 'library/book/imported-$i.jpg'
          ..parentPath = 'library/book'
          ..type = MediaType.file,
    ];
    existing = MediaItem()
      ..id = 30
      ..uid = 'existing'
      ..path = 'library/book/existing.jpg'
      ..parentPath = 'library/book'
      ..type = MediaType.file;
    final byUid = {
      for (final item in [folder, ...files, existing]) item.uid!: item,
    };
    when(() => repository.getByUid(any())).thenAnswer(
      (call) async => Result.success(byUid[call.positionalArguments.single]),
    );
    when(
      () => repository.getByPath(
        any(),
        includeTrashed: any(named: 'includeTrashed'),
      ),
    ).thenAnswer(
      (call) async => Result.success(
        call.positionalArguments.single == folder.path ? folder : null,
      ),
    );
    when(() => repository.getCollectionByPath(any())).thenAnswer(
      (call) async => Result.success(
        call.positionalArguments.single == folder.path ? collection : null,
      ),
    );
    when(
      () => repository.getAll(filter: any(named: 'filter')),
    ).thenAnswer((_) async => Result.success([...files, existing]));
    report = ImportExecutionReport(
      totalItems: importedCount,
      processedItems: importedCount,
      failedItems: 0,
      failureThresholdCount: 5,
      committedItems: [
        for (final item in files)
          ImportCommittedItem(
            id: item.id,
            uid: item.uid,
            path: item.path,
            sourcePath: item.path.split('/').last,
          ),
      ],
      destinations: catalog
          ? [
              const ImportCommittedItem(
                id: 10,
                uid: 'root',
                path: 'library/book',
                sourcePath: '',
                isCatalog: true,
                isFolder: true,
              ),
            ]
          : const [],
    );
  }

  final repository = _Repository();
  final folder = MediaItem()
    ..id = 10
    ..uid = 'root'
    ..path = 'library/book'
    ..parentPath = 'library'
    ..type = MediaType.folder;
  final collection = MediaCollection()
    ..id = 11
    ..uid = 'root-catalog'
    ..path = 'library/book'
    ..isCatalog = true
    ..type = CollectionType.folder;
  late final List<MediaItem> files;
  late final MediaItem existing;
  late ImportExecutionReport report;
  ViewerRouteArgs? routeArgs;
}

class _TabDestination extends ConsumerWidget {
  const _TabDestination();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Text(
      ref.watch(currentTabIndexProvider) == AppPreferences.homeTabIndex
          ? 'home destination'
          : 'library destination',
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  _Fixture fixture, {
  bool libraryBelow = false,
  bool imperativeImport = false,
  bool startOnHome = false,
  bool nestedLibrary = false,
  ImportFlowStatus status = ImportFlowStatus.completed,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => libraryBelow
            ? nestedLibrary
                  ? Navigator(
                      onGenerateRoute: (_) => MaterialPageRoute<void>(
                        builder: (_) => const _TabDestination(),
                      ),
                    )
                  : const _TabDestination()
            : const ImportSelectionScreen(),
        routes: [
          GoRoute(
            path: 'viewer/:id',
            builder: (context, state) {
              fixture.routeArgs = state.extra as ViewerRouteArgs;
              return Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                    tooltip: 'Close viewer',
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
                body: const Text('viewer destination'),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/import',
        builder: (_, _) => const ImportSelectionScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hapticsEnabledProvider.overrideWith((ref) => false),
        mediaRepositoryProvider.overrideWith((ref) async => fixture.repository),
        importFlowNotifierProvider.overrideWith(
          () => _CompletedFlow(fixture.report, status),
        ),
        importResultRevisionProvider.overrideWith(
          (ref) => const Stream.empty(),
        ),
        mediaFilterNotifierProvider(AppMode.internal).overrideWith(_Filter.new),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (libraryBelow) {
    final libraryContext = tester.element(find.text('library destination'));
    if (startOnHome) {
      ProviderScope.containerOf(
        libraryContext,
      ).read(currentTabIndexProvider.notifier).goToHome();
    }
    if (imperativeImport) {
      unawaited(
        Navigator.of(libraryContext).push<void>(
          MaterialPageRoute(builder: (_) => const ImportSelectionScreen()),
        ),
      );
    } else {
      unawaited(router.push<void>('/import'));
    }
    await tester.pumpAndSettle();
  }
}

Future<void> _tapPrimary(WidgetTester tester, String label) async {
  final button = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => registerFallbackValue(const MediaFilter()));

  for (final count in [1, 2]) {
    testWidgets(
      '$count imported files open the complete root catalog, including existing files',
      (tester) async {
        final fixture = _Fixture(importedCount: count);
        await _pump(tester, fixture);
        await _tapPrimary(tester, '追加したカタログを開く');
        expect(find.text('viewer destination'), findsOneWidget);
        expect(
          fixture.routeArgs?.sourceContext?.kind,
          ViewerSourceKind.catalog,
        );
        expect(
          fixture.routeArgs?.sourceContext?.parentPath,
          fixture.folder.path,
        );
        expect(
          fixture.routeArgs?.sourceContext?.customItems?.map(
            (item) => item.uid,
          ),
          [fixture.files.first.uid],
        );
        final filter =
            verify(
                  () => fixture.repository.getAll(
                    filter: captureAny(named: 'filter'),
                  ),
                ).captured.single
                as MediaFilter;
        expect(filter.parentPath, fixture.folder.path);
        expect(filter.mediaTypes, [MediaType.file]);
        expect(filter.isHidden, isFalse);
        expect(filter.limit, 1);
        final source = fixture.routeArgs!.sourceContext!;
        expect(source.catalogFilter!.limit, isNull);
        final container = ProviderScope.containerOf(
          tester.element(find.text('viewer destination')),
        );
        final completeItems = await container.read(
          catalogViewerItemsProvider(source.catalogFilter!).future,
        );
        expect(completeItems.map((item) => item.uid), [
          ...fixture.files.map((item) => item.uid),
          fixture.existing.uid,
        ]);

        expect(find.byType(ImportResultsScreen), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  final invalid = <String, void Function(_Fixture)>{
    'hidden folder': (fixture) => fixture.folder.isHidden = true,
    'missing folder': (fixture) => fixture.folder.isMissing = true,
    'archived catalog': (fixture) => fixture.collection.isArchived = true,
    'hidden catalog': (fixture) => fixture.collection.isHidden = true,
    'trashed catalog': (fixture) => fixture.collection.isTrashed = true,
    'no longer catalog': (fixture) => fixture.collection.isCatalog = false,
  };
  for (final entry in invalid.entries) {
    testWidgets(
      '${entry.key} is rejected when activating a stale import result',
      (tester) async {
        final fixture = _Fixture(importedCount: 1);
        await _pump(tester, fixture);
        entry.value(fixture);
        await _tapPrimary(tester, '追加したカタログを開く');
        expect(fixture.routeArgs, isNull);
        expect(find.text('viewer destination'), findsNothing);
        verifyNever(
          () => fixture.repository.getAll(filter: any(named: 'filter')),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a single independent file retains single-file navigation', (
    tester,
  ) async {
    final fixture = _Fixture(importedCount: 1, catalog: false);
    await _pump(tester, fixture);
    await _tapPrimary(tester, '追加したファイルを開く');
    expect(fixture.routeArgs?.sourceContext?.kind, ViewerSourceKind.single);
    expect(fixture.routeArgs?.initialItem?.uid, fixture.files.single.uid);
    verifyNever(() => fixture.repository.getAll(filter: any(named: 'filter')));
    expect(tester.takeException(), isNull);
  });

  for (final nested in [false, true]) {
    testWidgets(
      'a successful single import from ${nested ? 'a tab' : 'the root'} opens directly and returns to the library',
      (tester) async {
        final fixture = _Fixture(importedCount: 1, catalog: false);
        await _pump(
          tester,
          fixture,
          libraryBelow: true,
          imperativeImport: true,
          startOnHome: true,
          nestedLibrary: nested,
        );
        expect(find.text('viewer destination'), findsOneWidget);
        expect(find.byType(ImportSelectionScreen), findsNothing);
        expect(find.text('追加したファイルを開く'), findsNothing);
        expect(fixture.routeArgs?.sourceContext?.kind, ViewerSourceKind.single);
        expect(fixture.routeArgs?.initialItem?.uid, fixture.files.single.uid);
        final container = ProviderScope.containerOf(
          tester.element(find.text('viewer destination')),
        );
        expect(
          container.read(importFlowNotifierProvider).status,
          ImportFlowStatus.idle,
        );
        expect(
          container.read(currentTabIndexProvider),
          AppPreferences.libraryTabIndex,
        );
        verify(
          () => fixture.repository.getByUid(fixture.files.single.uid!),
        ).called(1);

        await tester.tap(find.byTooltip('Close viewer'));
        await tester.pumpAndSettle();
        expect(find.text('library destination'), findsOneWidget);
        expect(find.byType(ImportSelectionScreen), findsNothing);
        expect(find.text('取り込み完了'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final startOnHome in [true, false]) {
    for (final imperative in [true, false]) {
      for (final nested in [true, false]) {
        for (final status in [
          ImportFlowStatus.completed,
          ImportFlowStatus.error,
        ]) {
          testWidgets(
            'explicit library return: home=$startOnHome imperative=$imperative nested=$nested status=$status',
            (tester) async {
              final fixture = _Fixture(importedCount: 2, catalog: false);
              await _pump(
                tester,
                fixture,
                libraryBelow: true,
                startOnHome: startOnHome,
                imperativeImport: imperative,
                nestedLibrary: nested,
                status: status,
              );
              final container = ProviderScope.containerOf(
                tester.element(find.byType(ImportSelectionScreen)),
              );
              final filterProvider = mediaFilterNotifierProvider(
                AppMode.internal,
              );
              final subscription = container.listen(filterProvider, (_, _) {});
              addTearDown(subscription.close);
              container
                  .read(filterProvider.notifier)
                  .updateSearchQuery('kept query');
              final before = container.read(filterProvider);
              final action = find.widgetWithText(OutlinedButton, 'ライブラリへ戻る');
              await tester.ensureVisible(action);
              await tester.tap(action);
              await tester.pumpAndSettle();
              expect(find.text('library destination'), findsOneWidget);
              expect(find.text('home destination'), findsNothing);
              expect(find.byType(ImportSelectionScreen), findsNothing);
              expect(
                container.read(currentTabIndexProvider),
                AppPreferences.libraryTabIndex,
              );
              expect(container.read(filterProvider), before);
              expect(
                container.read(importFlowNotifierProvider).status,
                ImportFlowStatus.idle,
              );
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }

  for (final status in [
    ImportFlowStatus.confirming,
    ImportFlowStatus.completed,
    ImportFlowStatus.error,
  ]) {
    testWidgets('normal back preserves the originating home tab: $status', (
      tester,
    ) async {
      final fixture = _Fixture(importedCount: 2, catalog: false);
      await _pump(
        tester,
        fixture,
        libraryBelow: true,
        startOnHome: true,
        imperativeImport: true,
        status: status,
      );
      final context = tester.element(find.byType(ImportSelectionScreen));
      final container = ProviderScope.containerOf(context);
      await Navigator.of(context).maybePop();
      await tester.pumpAndSettle();
      expect(find.text('home destination'), findsOneWidget);
      expect(find.byType(ImportSelectionScreen), findsNothing);
      expect(
        container.read(currentTabIndexProvider),
        AppPreferences.homeTabIndex,
      );
      expect(tester.takeException(), isNull);
    });
  }

  final reportsRequiringReview =
      <String, ImportExecutionReport Function(ImportExecutionReport)>{
        'skipped files': (report) => report.copyWith(totalItems: 2),
        'failed files': (report) =>
            report.copyWith(totalItems: 2, failedItems: 1),
        'pending files': (report) =>
            report.copyWith(pendingSourcePaths: ['pending.jpg']),
        'cancelled import': (report) => report.copyWith(isCancelled: true),
        'rolled back import': (report) => report.copyWith(isRolledBack: true),
        'uncertain destination': (report) =>
            report.copyWith(retryBlocked: true),
      };
  for (final entry in reportsRequiringReview.entries) {
    testWidgets('${entry.key} keeps the report even with one retained file', (
      tester,
    ) async {
      final fixture = _Fixture(importedCount: 1, catalog: false);
      fixture.report = entry.value(fixture.report);
      await _pump(tester, fixture, libraryBelow: true, imperativeImport: true);
      expect(find.byType(ImportSelectionScreen), findsOneWidget);
      expect(find.text('viewer destination'), findsNothing);
      expect(find.text('ライブラリへ戻る'), findsOneWidget);
      expect(fixture.routeArgs, isNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'an unavailable single import remains recoverable on the report',
    (tester) async {
      final fixture = _Fixture(importedCount: 1, catalog: false);
      fixture.files.single.isHidden = true;
      await _pump(tester, fixture, libraryBelow: true, imperativeImport: true);
      expect(find.byType(ImportSelectionScreen), findsOneWidget);
      expect(find.text('viewer destination'), findsNothing);
      expect(find.text('追加したファイルを開く'), findsOneWidget);
      expect(find.text('ライブラリへ戻る'), findsOneWidget);
      expect(fixture.routeArgs, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('multiple independent files retain the import results list', (
    tester,
  ) async {
    final fixture = _Fixture(importedCount: 2, catalog: false);
    await _pump(tester, fixture);
    await _tapPrimary(tester, '追加できた項目を見る');
    expect(find.byType(ImportResultsScreen), findsOneWidget);
    expect(
      tester
          .widget<ImportResultsScreen>(find.byType(ImportResultsScreen))
          .items
          .map((item) => item.uid),
      fixture.files.map((item) => item.uid),
    );
    expect(fixture.routeArgs, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'empty catalog opens its folder and returns to the underlying library',
    (tester) async {
      final fixture = _Fixture(importedCount: 0);
      when(
        () => fixture.repository.getAll(filter: any(named: 'filter')),
      ).thenAnswer((_) async => Result.success(<MediaItem>[]));
      await _pump(tester, fixture, libraryBelow: true);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ImportSelectionScreen)),
      );
      final subscription = container.listen(
        mediaFilterNotifierProvider(AppMode.internal),
        (_, _) {},
      );
      addTearDown(subscription.close);
      await _tapPrimary(tester, '追加したカタログを開く');
      expect(find.text('library destination'), findsOneWidget);
      expect(find.byType(ImportSelectionScreen), findsNothing);
      expect(
        container
            .read(mediaFilterNotifierProvider(AppMode.internal))
            .parentPath,
        fixture.folder.path,
      );
      expect(fixture.routeArgs, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'files outside the root catalog keep all successful results accessible',
    (tester) async {
      final fixture = _Fixture(importedCount: 2);
      final outside = fixture.files.last
        ..path = 'library/outside.jpg'
        ..parentPath = 'library';
      fixture.report = fixture.report.copyWith(
        committedItems: [
          fixture.report.committedItems.first,
          ImportCommittedItem(
            id: outside.id,
            uid: outside.uid,
            path: outside.path,
            sourcePath: 'outside.jpg',
          ),
        ],
      );
      await _pump(tester, fixture);
      expect(find.text('追加したカタログを開く'), findsNothing);
      await _tapPrimary(tester, '追加できた項目を見る');
      expect(find.byType(ImportResultsScreen), findsOneWidget);
      expect(
        tester
            .widget<ImportResultsScreen>(find.byType(ImportResultsScreen))
            .items
            .map((item) => item.path),
        [fixture.files.first.path, outside.path],
      );
      expect(fixture.routeArgs, isNull);
      verifyNever(
        () => fixture.repository.getAll(filter: any(named: 'filter')),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
