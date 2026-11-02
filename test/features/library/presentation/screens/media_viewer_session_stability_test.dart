import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/catalog_viewer_items_provider.dart';
import 'package:private_shelf/features/library/presentation/widgets/viewer/media_viewer_bottom_overlay.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/home/presentation/providers/recent_media_provider.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/data/repositories/viewing_history_repository.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/viewer_source_context.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/presentation/providers/catalog_resume_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/external_file_preview_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/media_item_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/media_viewer_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/viewer_pages_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/viewing_history_provider.dart';
import 'package:private_shelf/features/library/presentation/screens/media_viewer_screen.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(const MediaFilter());
    registerFallbackValue(MediaItem());
    registerFallbackValue(DateTime(2026));
  });

  for (final retryFirst in [false, true]) {
    testWidgets('カタログの後読みは初期位置を維持する retry=$retryFirst', (tester) async {
      final first = _item(31, 'first.bin');
      final resumed = _item(32, 'resumed.bin');
      final pending = Completer<List<MediaItem>>();
      final retry = Completer<List<MediaItem>>();
      var attempts = 0;
      const filter = MediaFilter(parentPath: 'catalog');
      final container = ProviderContainer(
        overrides: [
          appDocumentsPathSyncProvider.overrideWithValue('/tmp'),
          mediaItemProvider(first.id).overrideWith((ref) => first),
          mediaItemProvider(resumed.id).overrideWith((ref) => resumed),
          catalogViewerItemsProvider(filter).overrideWith(
            (ref) => attempts++ == 0 ? pending.future : retry.future,
          ),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        container.dispose();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaViewerScreen(
              initialItem: resumed,
              sourceContext: ViewerSourceContext.catalog(
                items: [resumed],
                parentPath: 'catalog',
                appMode: AppMode.internal,
                catalogFilter: filter,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('viewer-page-32-full')), findsOneWidget);
      expect(find.byType(MediaViewerBottomOverlay), findsNothing);
      expect(find.byIcon(Icons.close), findsOneWidget);
      if (retryFirst) {
        pending.completeError(StateError('temporary'));
        await tester.pump();
        await tester.pump();
        expect(
          find.byKey(const ValueKey('catalog-pages-retry')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('viewer-page-32-full')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('catalog-pages-retry')));
        await tester.pump();
        retry.complete([first, resumed]);
      } else {
        pending.complete([first, resumed]);
      }
      await tester.pumpAndSettle();
      final pages = tester.widget<PageView>(
        find.byKey(const Key('media_viewer_page_view')),
      );
      expect(pages.controller!.page, 1);
      expect(container.read(mediaViewerViewModelProvider).currentItem?.id, 32);
      expect(find.byType(MediaViewerBottomOverlay), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('再開対象が現在の検索から外れても自身の見開き設定と履歴先を保持する', (tester) async {
    const folderPath = 'library/catalog';
    const filePath = '$folderPath/spread.png';
    final directory = Directory.systemTemp.createTempSync(
      'private-shelf-resume-session-',
    );
    final physicalPath = '${directory.path}/$filePath';
    addTearDown(() {
      globalImageAspectRatioCache.remove(filePath);
      globalImageAspectRatioCache.remove(physicalPath);
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      directory.deleteSync(recursive: true);
    });
    final file = File(physicalPath)..parent.createSync(recursive: true);
    // A two-pixel landscape image lets the real image viewer finish loading.
    file.writeAsBytesSync(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAADklEQVR4nGP4z8AAQv8BD/kD/YURmXYAAAAASUVORK5CYII=',
      ),
    );
    final folderCatalog = MediaCollection()
      ..id = 41
      ..path = folderPath
      ..type = CollectionType.folder
      ..isCatalog = true
      ..lastViewedItemId = 42
      ..splitSpreadView = false;
    final fileCatalog = MediaCollection()
      ..id = 43
      ..path = filePath
      ..type = CollectionType.file
      ..isCatalog = true
      ..splitSpreadView = true;
    final resumed = _item(42, filePath)
      ..parentPath = folderPath
      ..mimeType = 'image/png';
    resumed.collection.value = fileCatalog;
    final folder = _item(41, folderPath)
      ..type = MediaType.folder
      ..parentPath = 'library';
    final repository = _ResumeSessionRepository();
    final openedHistory = _OpenedHistoryRepository();
    var loadedHistoryCalls = 0;
    when(
      () => repository.getCollectionById(folderCatalog.id),
    ).thenAnswer((_) async => Result.success(folderCatalog));
    when(
      () => repository.getById(resumed.id),
    ).thenAnswer((_) async => Result.success(resumed));
    when(() => repository.getCollectionByPath(any())).thenAnswer((invocation) {
      final path = invocation.positionalArguments.single;
      return Future.value(
        Result<MediaCollection?, AppError>.success(
          path == filePath
              ? fileCatalog
              : path == folderPath
              ? folderCatalog
              : null,
        ),
      );
    });
    when(() => repository.getByPath(any(), includeTrashed: true)).thenAnswer(
      (invocation) async => Result.success(
        invocation.positionalArguments.single == folderPath ? folder : null,
      ),
    );
    when(
      () => repository.watchLibraryChanges(filter: any(named: 'filter')),
    ).thenAnswer((_) => const Stream<void>.empty());
    when(
      () => repository.getPage(
        filter: any(named: 'filter'),
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => Result.success(<MediaItem>[]));
    when(
      () => repository.updateCollectionLastViewed(
        any(),
        itemId: any(named: 'itemId'),
        viewedAt: any(named: 'viewedAt'),
      ),
    ).thenAnswer((_) async => Result.success(true));
    when(
      () => openedHistory.record(any(), openedAt: any(named: 'openedAt')),
    ).thenAnswer((_) async {
      loadedHistoryCalls++;
    });
    final target = await resolveCatalogResumeTarget(repository, (
      collectionId: folderCatalog.id,
      collectionPath: folderPath,
      itemId: resumed.id,
    ), includeHidden: false);
    expect(target, isNotNull);
    globalImageAspectRatioCache[filePath] = 2;
    globalImageAspectRatioCache[physicalPath] = 2;
    final container = ProviderContainer(
      overrides: [
        appDocumentsPathSyncProvider.overrideWithValue(directory.path),
        mediaRepositoryProvider.overrideWith((ref) async => repository),
        viewingHistoryRepositoryProvider.overrideWith(
          (ref) async => openedHistory,
        ),
        mediaFilterNotifierProvider(
          AppMode.internal,
        ).overrideWith(_ExcludedResumeFilter.new),
        mediaItemProvider(resumed.id).overrideWith((ref) => target!.item),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaViewerScreen(
            initialItem: target!.item,
            sourceContext: const ViewerSourceContext.folder(
              parentPath: folderPath,
              appMode: AppMode.internal,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // File image decoding is not part of pumpAndSettle's completion condition.
    // Wait for the real content-ready history gate, without invoking it by hand.
    for (var attempt = 0; attempt < 500 && loadedHistoryCalls == 0; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(loadedHistoryCalls, greaterThan(0));

    expect(container.read(libraryViewModelProvider).value, isEmpty);
    final queriedFilters = verify(
      () => repository.getPage(
        filter: captureAny(named: 'filter'),
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
      ),
    ).captured.cast<MediaFilter>();
    expect(queriedFilters, isNotEmpty);
    expect(
      queriedFilters.every((filter) => filter.searchQuery == 'not-this-file'),
      isTrue,
    );
    final pages = tester.widget<PageView>(
      find.byKey(const Key('media_viewer_page_view')),
    );
    expect(pages.childrenDelegate.estimatedChildCount, 2);
    expect(pages.controller!.page, 0);
    expect(find.byKey(const ValueKey('viewer-page-42-full')), findsNothing);
    expect(find.byKey(const ValueKey('viewer-page-42-left')), findsOneWidget);
    expect(
      container.read(mediaViewerViewModelProvider).currentItem,
      same(resumed),
    );

    unawaited(
      pages.controller!.animateToPage(
        1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      ),
    );
    await tester.pumpAndSettle();
    expect(pages.controller!.page, 1);
    expect(find.byKey(const ValueKey('viewer-page-42-right')), findsOneWidget);
    expect(container.read(mediaViewerViewModelProvider).currentIndex, 1);
    expect(
      container.read(mediaViewerViewModelProvider).currentItem,
      same(resumed),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    final saves = verify(
      () => repository.updateCollectionLastViewed(
        captureAny(),
        itemId: captureAny(named: 'itemId'),
        viewedAt: any(named: 'viewedAt'),
      ),
    ).captured;
    expect(saves, isNotEmpty);
    expect(saves.whereType<String>(), everyElement(filePath));
    expect(saves.whereType<int>(), everyElement(resumed.id));
    final opened = verify(
      () =>
          openedHistory.record(captureAny(), openedAt: any(named: 'openedAt')),
    ).captured.cast<MediaItem>();
    expect(opened, isNotEmpty);
    expect(opened.every((item) => identical(item, resumed)), isTrue);
  });

  testWidgets('等価なRecent再通知ではページを再確定せず、順序変更だけを反映する', (tester) async {
    final recentItems = StreamController<List<MediaItem>>();
    final initialItems = [_item(1, 'one.bin'), _item(2, 'two.bin')];
    final container = ProviderContainer(
      overrides: [
        appDocumentsPathSyncProvider.overrideWithValue('/tmp'),
        recentMediaProvider.overrideWith((ref) => recentItems.stream),
      ],
    );
    ProviderSubscription<MediaViewerState>? subscription;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      subscription?.close();
      // A paused Riverpod stream still owns its source subscription. Dispose
      // that subscription before waiting for the controller's close event.
      container.dispose();
      await recentItems.close();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaViewerScreen(
            initialItem: initialItems.first,
            sourceContext: const ViewerSourceContext.recent(),
          ),
        ),
      ),
    );
    recentItems.add(initialItems);
    await tester.pumpAndSettle();

    var viewerStateNotifications = 0;
    subscription = container.listen(mediaViewerViewModelProvider, (
      previous,
      next,
    ) {
      viewerStateNotifications++;
    });

    recentItems.add([_item(1, 'one.bin'), _item(2, 'two.bin')]);
    await tester.pumpAndSettle();

    expect(viewerStateNotifications, 0);
    expect(container.read(mediaViewerViewModelProvider).currentIndex, 0);

    recentItems.add([_item(2, 'two.bin'), _item(1, 'one.bin')]);
    await tester.pumpAndSettle();

    expect(viewerStateNotifications, greaterThan(0));
    expect(container.read(mediaViewerViewModelProvider).currentIndex, 1);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('隣接する外部テキストはスクロール確定まで取得しない', (tester) async {
    final first = _item(11, 'first.bin');
    final second = _item(12, 'content://viewer/second.txt')
      ..mimeType = 'text/plain'
      ..isImportPreview = true
      ..sourceType = MediaSourceType.localCopy;
    var previewRequests = 0;
    final container = ProviderContainer(
      overrides: [
        appDocumentsPathSyncProvider.overrideWithValue('/tmp'),
        mediaItemProvider(first.id).overrideWith((ref) => first),
        mediaItemProvider(second.id).overrideWith((ref) => second),
        externalFilePreviewProvider(second).overrideWith((ref) {
          previewRequests++;
          return null;
        }),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaViewerScreen(
            initialItem: first,
            sourceContext: ViewerSourceContext.customList([first, second]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(previewRequests, 0);

    final pageView = tester.widget<PageView>(
      find.byKey(const Key('media_viewer_page_view')),
    );
    unawaited(
      pageView.controller!.animateToPage(
        1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));

    expect(previewRequests, 0);

    await tester.pumpAndSettle();

    expect(previewRequests, 1);
    await tester.pump(const Duration(seconds: 1));
  });
}

class _ResumeSessionRepository extends Mock implements MediaRepository {}

class _OpenedHistoryRepository extends Mock
    implements ViewingHistoryRepository {}

class _ExcludedResumeFilter extends MediaFilterNotifier {
  @override
  MediaFilter build(AppMode mode) => const MediaFilter(
    parentPath: 'library/catalog',
    sourceType: MediaSourceType.localCopy,
    searchQuery: 'not-this-file',
  );
}

MediaItem _item(int id, String path) {
  return MediaItem()
    ..id = id
    ..path = path
    ..originalPath = path
    ..type = MediaType.file
    ..mimeType = 'application/octet-stream'
    ..sourceType = MediaSourceType.localCopy;
}
