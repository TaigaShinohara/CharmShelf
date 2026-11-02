import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/viewer_source_context.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/external_file_preview_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/media_item_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/media_viewer_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/viewer_pages_provider.dart';
import 'package:private_shelf/features/library/presentation/screens/media_viewer_screen.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('画像ビューワーのジェスチャー調停', () {
    for (final frequency in <double>[60, 90, 120, 180, 240]) {
      testWidgets('MOVE頻度${frequency.toInt()}Hzの高速横スワイプでページ移動する', (
        tester,
      ) async {
        final fixture = _ViewerFixture.create();
        _registerFixtureTearDown(tester, fixture);
        await _showViewer(tester, fixture);

        await _swipePage(tester, frequency: frequency);
        _expectPageInMotion(tester);

        await tester.pumpAndSettle();
        await _expectCommittedItem(tester, fixture, 1);
      });
    }

    testWidgets('横成分が優勢な斜め高速スワイプでページ移動する', (tester) async {
      final fixture = _ViewerFixture.create();
      _registerFixtureTearDown(tester, fixture);
      await _showViewer(tester, fixture);

      await _swipePage(tester, offset: const Offset(-600, 160), frequency: 60);
      _expectPageInMotion(tester);

      await tester.pumpAndSettle();
      await _expectCommittedItem(tester, fixture, 1);
    });

    testWidgets('縦成分が優勢なドラッグではページ移動しない', (tester) async {
      final fixture = _ViewerFixture.create();
      _registerFixtureTearDown(tester, fixture);
      await _showViewer(tester, fixture);

      await _swipePage(
        tester,
        offset: const Offset(-10, 40),
        duration: const Duration(milliseconds: 300),
        frequency: 60,
      );
      await tester.pumpAndSettle();

      await _expectCommittedItem(tester, fixture, 0);
      expect(_pageController(tester).page, 0);
    });

    testWidgets('初期フレーム直後の高速横スワイプでもページ移動する', (tester) async {
      final fixture = _ViewerFixture.create();
      _registerFixtureTearDown(tester, fixture);
      await _showViewer(tester, fixture, settle: false);

      await _swipePage(tester, frequency: 60);
      _expectPageInMotion(tester);

      await tester.pumpAndSettle();
      await _expectCommittedItem(tester, fixture, 1);
    });

    testWidgets('高速スワイプで進んだ直後に逆方向へ戻れる', (tester) async {
      final fixture = _ViewerFixture.create();
      _registerFixtureTearDown(tester, fixture);
      await _showViewer(tester, fixture);

      await _swipePage(tester, frequency: 60);
      await tester.pumpAndSettle();
      await _expectCommittedItem(tester, fixture, 1);

      await _swipePage(tester, offset: const Offset(600, 0), frequency: 60);
      await tester.pumpAndSettle();
      await _expectCommittedItem(tester, fixture, 0);
    });

    testWidgets('キャンセルされた横ドラッグを破棄して次の操作を受け付ける', (tester) async {
      final fixture = _ViewerFixture.create();
      _registerFixtureTearDown(tester, fixture);
      await _showViewer(tester, fixture);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_pageViewKey)),
      );
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-80, 0));
      await tester.pump();
      _expectPageInMotion(tester);
      await gesture.cancel();
      await tester.pumpAndSettle();
      await _expectCommittedItem(tester, fixture, 0);

      await _swipePage(tester, frequency: 60);
      await tester.pumpAndSettle();
      await _expectCommittedItem(tester, fixture, 1);
    });

    testWidgets('同じページへ戻る短いドラッグ後も破棄された近傍先読みを再開する', (tester) async {
      final fixture = _ViewerFixture.create(externalReference: true);
      _registerFixtureTearDown(tester, fixture);
      await _showViewer(tester, fixture);
      await _drainPreloadWork(tester, fixture, expectedRequests: 1);

      expect(fixture.externalPreviewRequests[2], 1);
      fixture.container.invalidate(
        externalFilePreviewProvider(fixture.items[2]),
      );
      await tester.pump();
      expect(fixture.externalPreviewRequests[2], 1);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_pageViewKey)),
      );
      await gesture.moveBy(const Offset(-80, 0));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(80, 0));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();
      await _drainPreloadWork(tester, fixture, expectedRequests: 2);

      await _expectCommittedItem(tester, fixture, 0);
      expect(_pageController(tester).page, 0);
      expect(fixture.externalPreviewRequests[2], 2);
    });

    testWidgets('表示解像度が変わると新しいResizeImageキーで近傍を先読みし直す', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final fixture = _ViewerFixture.create(externalReference: true);
      _registerFixtureTearDown(tester, fixture);
      await _showViewer(tester, fixture);
      await _drainPreloadWork(tester, fixture, expectedRequests: 1);

      expect(fixture.externalPreviewRequests[2], 1);
      fixture.container.invalidate(
        externalFilePreviewProvider(fixture.items[2]),
      );
      await tester.pump();
      expect(fixture.externalPreviewRequests[2], 1);

      tester.view.physicalSize = const Size(1200, 800);
      await tester.pumpAndSettle();
      await _drainPreloadWork(tester, fixture, expectedRequests: 2);

      await _expectCommittedItem(tester, fixture, 0);
      expect(fixture.externalPreviewRequests[2], 2);
    });

    testWidgets('見開き画像の左右ページでも高速横スワイプを連続できる', (tester) async {
      final fixture = _ViewerFixture.create(splitSpread: true);
      _registerFixtureTearDown(tester, fixture);
      await _showViewer(tester, fixture);

      await _swipePage(tester, frequency: 60);
      await tester.pumpAndSettle();
      expect(_pageController(tester).page, 1);
      await _expectCommittedItem(tester, fixture, 0, pageIndex: 1);

      await _swipePage(tester, frequency: 60);
      await tester.pumpAndSettle();
      expect(_pageController(tester).page, 2);
      await _expectCommittedItem(tester, fixture, 1, pageIndex: 2);
    });

    testWidgets('外部参照画像でも粗い高速横スワイプでページ移動する', (tester) async {
      final fixture = _ViewerFixture.create(externalReference: true);
      _registerFixtureTearDown(tester, fixture);
      await _showViewer(tester, fixture);

      await _swipePage(tester, frequency: 60);
      _expectPageInMotion(tester);

      await tester.pumpAndSettle();
      await _expectCommittedItem(tester, fixture, 1);
    });

    testWidgets('ダブルタップ拡大中はページ移動せず等倍復帰後は移動する', (tester) async {
      final fixture = _ViewerFixture.create();
      _registerFixtureTearDown(tester, fixture);
      await _showViewer(tester, fixture);

      await _doubleTapImage(tester);
      await _swipePage(tester, frequency: 60);
      await tester.pumpAndSettle();
      await _expectCommittedItem(tester, fixture, 0);
      expect(_pageController(tester).page, 0);

      await _doubleTapImage(tester);
      await _swipePage(tester, frequency: 60);
      await tester.pumpAndSettle();
      await _expectCommittedItem(tester, fixture, 1);
    });

    testWidgets('2本指ピンチを横ドラッグが奪わず拡大後のパンもページ移動しない', (tester) async {
      final fixture = _ViewerFixture.create();
      _registerFixtureTearDown(tester, fixture);
      await _showViewer(tester, fixture);

      await _pinchOutImage(tester);
      await _swipePage(tester, frequency: 60);
      await tester.pumpAndSettle();

      await _expectCommittedItem(tester, fixture, 0);
      expect(_pageController(tester).page, 0);

      await _doubleTapImage(tester);
      await _swipePage(tester, frequency: 60);
      await tester.pumpAndSettle();
      await _expectCommittedItem(tester, fixture, 1);
    });

    testWidgets('画面幅の約20%程度の低速スワイプでも次ページへ移動する', (tester) async {
      final fixture = _ViewerFixture.create();
      _registerFixtureTearDown(tester, fixture);
      await _showViewer(tester, fixture);

      // 画面幅800pxに対し、約22% (180px) の低速ドラッグ（低速度で指を離す）
      await _swipePage(
        tester,
        offset: const Offset(-180, 0),
        duration: const Duration(milliseconds: 600),
        frequency: 60,
      );
      await tester.pumpAndSettle();

      await _expectCommittedItem(tester, fixture, 1);
      expect(_pageController(tester).page, 1);
    });

    testWidgets('指を途中で離した約15%以上の低速スワイプを素早く次ページへ確定する', (tester) async {
      final fixture = _ViewerFixture.create();
      _registerFixtureTearDown(tester, fixture);
      await _showViewer(tester, fixture);

      // 画面幅800pxに対し、約16% (130px) の低速ドラッグ。
      // 指を離した位置が50%未満でも、次のファイルを選択する。
      await _swipePage(
        tester,
        offset: const Offset(-130, 0),
        duration: const Duration(milliseconds: 600),
        frequency: 60,
      );
      await tester.pumpAndSettle();

      await _expectCommittedItem(tester, fixture, 1);
      expect(_pageController(tester).page, 1);
    });

    testWidgets('画面幅の約10%未満の微小ドラッグでは元のページに戻る', (tester) async {
      final fixture = _ViewerFixture.create();
      _registerFixtureTearDown(tester, fixture);
      await _showViewer(tester, fixture);

      // 画面幅800pxに対し、約8% (60px) の微小ドラッグ
      await _swipePage(
        tester,
        offset: const Offset(-60, 0),
        duration: const Duration(milliseconds: 600),
        frequency: 60,
      );
      await tester.pumpAndSettle();

      await _expectCommittedItem(tester, fixture, 0);
      expect(_pageController(tester).page, 0);
    });
  });
}

const _pageViewKey = Key('media_viewer_page_view');

void _registerFixtureTearDown(WidgetTester tester, _ViewerFixture fixture) {
  addTearDown(() async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    fixture.dispose();
  });
}

Future<void> _showViewer(
  WidgetTester tester,
  _ViewerFixture fixture, {
  bool settle = true,
}) async {
  await tester.pumpWidget(fixture.buildApp());
  if (settle) await tester.pumpAndSettle();
}

Future<void> _swipePage(
  WidgetTester tester, {
  Offset offset = const Offset(-600, 0),
  Duration duration = const Duration(milliseconds: 90),
  double frequency = 60,
}) async {
  await tester.timedDrag(
    find.byKey(_pageViewKey),
    offset,
    duration,
    frequency: frequency,
  );
}

Future<void> _drainPreloadWork(
  WidgetTester tester,
  _ViewerFixture fixture, {
  required int expectedRequests,
}) async {
  // 非同期の画像読込はpumpAndSettleの終了条件に含まれない。
  // 固定時間だけに依存せず、要求到達を最大5秒待つ。フレーム末尾の
  // ImageCacheリスナー解放用に、従来の20フレームも維持する。
  for (var i = 0; i < 500; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 1));
    if (i >= 19 && fixture.externalPreviewRequests[2] >= expectedRequests) {
      break;
    }
  }
  expect(fixture.externalPreviewRequests[2], expectedRequests);
}

PageController _pageController(WidgetTester tester) {
  return tester.widget<PageView>(find.byKey(_pageViewKey)).controller!;
}

void _expectPageInMotion(WidgetTester tester) {
  expect(_pageController(tester).page, greaterThan(0));
}

Future<void> _expectCommittedItem(
  WidgetTester tester,
  _ViewerFixture fixture,
  int index, {
  int? pageIndex,
}) async {
  expect(
    fixture.container.read(mediaViewerViewModelProvider).currentItem?.id,
    fixture.items[index].isImportPreview ? null : fixture.items[index].id,
  );
  expect(
    _pageController(tester).page,
    closeTo((pageIndex ?? index).toDouble(), 0.01),
  );
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _doubleTapImage(WidgetTester tester) async {
  final center = tester.getCenter(find.byType(InteractiveViewer).first);
  await tester.tapAt(center);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tapAt(center);
  await tester.pumpAndSettle();
}

Future<void> _pinchOutImage(WidgetTester tester) async {
  final center = tester.getCenter(find.byType(InteractiveViewer).first);
  final first = await tester.startGesture(
    center - const Offset(40, 0),
    pointer: 21,
  );
  final second = await tester.startGesture(
    center + const Offset(40, 0),
    pointer: 22,
  );
  await tester.pump();
  await first.moveTo(center - const Offset(140, 0));
  await second.moveTo(center + const Offset(140, 0));
  await tester.pump();
  await first.up();
  await second.up();
  await tester.pumpAndSettle();
}

class _ViewerFixture {
  _ViewerFixture._(
    this.directory,
    this.items,
    this.container,
    this.aspectRatioCacheKeys,
    this.externalPreviewRequests,
  );

  final Directory directory;
  final List<MediaItem> items;
  final ProviderContainer container;
  final List<String> aspectRatioCacheKeys;
  final List<int> externalPreviewRequests;

  static _ViewerFixture create({
    bool splitSpread = false,
    bool externalReference = false,
  }) {
    final directory = Directory.systemTemp.createTempSync(
      'private-shelf-viewer-gesture-',
    );
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    final items = <MediaItem>[];
    final physicalPaths = <String>[];
    final aspectRatioCacheKeys = <String>[];
    final externalPreviewRequests = List<int>.filled(3, 0);
    final collection = splitSpread
        ? (MediaCollection()..splitSpreadView = true)
        : null;
    for (var index = 0; index < 3; index++) {
      final path = '$index.png';
      final physicalPath = '${directory.path}/$path';
      File(physicalPath).writeAsBytesSync(bytes);
      physicalPaths.add(physicalPath);
      final item = MediaItem()
        ..id = 9000 + index
        ..path = externalReference ? 'content://viewer/$path' : path
        ..originalPath = path
        ..type = MediaType.file
        ..mimeType = 'image/png'
        ..isImportPreview = externalReference
        ..sourceType = MediaSourceType.localCopy;
      if (collection != null) {
        item.collection.value = collection;
        globalImageAspectRatioCache[item.path] = 2;
        globalImageAspectRatioCache[physicalPath] = 2;
        aspectRatioCacheKeys.addAll([item.path, physicalPath]);
      }
      items.add(item);
    }
    final container = ProviderContainer(
      overrides: [
        appDocumentsPathSyncProvider.overrideWithValue(directory.path),
        for (final item in items) ...[
          mediaItemProvider(item.id).overrideWith((ref) => item),
          collectionNotifierProvider(
            item.path,
          ).overrideWith(_NullCollectionNotifier.new),
          if (externalReference)
            externalFilePreviewProvider(item).overrideWith((ref) {
              final index = items.indexOf(item);
              externalPreviewRequests[index]++;
              return physicalPaths[index];
            }),
        ],
      ],
    );
    return _ViewerFixture._(
      directory,
      items,
      container,
      aspectRatioCacheKeys,
      externalPreviewRequests,
    );
  }

  Widget buildApp() {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaViewerScreen(
          initialItem: items.first,
          sourceContext: ViewerSourceContext.customList(items),
        ),
      ),
    );
  }

  void dispose() {
    container.dispose();
    for (final key in aspectRatioCacheKeys) {
      globalImageAspectRatioCache.remove(key);
    }
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    directory.deleteSync(recursive: true);
  }
}

class _NullCollectionNotifier extends CollectionNotifier {
  @override
  Future<MediaCollection?> build(String path) async => null;
}
