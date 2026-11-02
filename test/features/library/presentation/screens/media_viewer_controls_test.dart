import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/viewer_source_context.dart';
import 'package:private_shelf/features/library/presentation/providers/media_viewer_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/external_file_preview_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/media_item_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/player_notifier.dart';
import 'package:private_shelf/features/library/presentation/screens/media_viewer_screen.dart';
import 'package:private_shelf/features/library/presentation/widgets/viewer/media_viewer_bottom_overlay.dart';
import 'package:private_shelf/features/library/presentation/widgets/viewer/media_viewer_top_overlay.dart';
import 'package:private_shelf/features/library/presentation/widgets/video_player_view.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaViewerScreen コントロール表示制御テスト', () {
    testWidgets('動画ファイル表示時、初期状態から主要操作が見え、タップで表示を切り替えられる', (tester) async {
      final videoItem = MediaItem()
        ..id = 200
        ..path = 'sample.mp4'
        ..type = MediaType.file
        ..mimeType = 'video/mp4'
        ..sourceType = MediaSourceType.localCopy;

      final container = ProviderContainer(
        overrides: [appDocumentsPathSyncProvider.overrideWithValue('/tmp')],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaViewerScreen(
              initialItem: videoItem,
              sourceContext: const ViewerSourceContext.single(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 初回利用でも閉じる・再生などの操作を発見できるよう、最初から表示する。
      final state = container.read(mediaViewerViewModelProvider);
      expect(state.showControls, isTrue);
      expect(find.byKey(const ValueKey('viewer-file-info')), findsOneWidget);
      expect(find.byKey(const ValueKey('player-title')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('viewer-file-info'))).dy,
        greaterThan(tester.getTopLeft(find.byType(AppBar)).dy),
      );

      // ファイル情報の詳細オーバーレイは操作するまで表示しない。
      expect(find.byType(MediaViewerTopOverlay), findsNothing);

      // 動画ファイルのため MediaViewerBottomOverlay（1/2 ファイル 等のページスライダー）は表示されない
      expect(find.byType(MediaViewerBottomOverlay), findsNothing);

      // VideoPlayerView が存在することを確認
      expect(find.byType(VideoPlayerView), findsOneWidget);

      // 画面をタップしてコントロールを非表示にする。
      await tester.tap(find.byType(VideoPlayerView));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        container.read(mediaViewerViewModelProvider).showControls,
        isFalse,
      );
      expect(find.byKey(const ValueKey('viewer-file-info')), findsNothing);
      expect(find.byType(MediaViewerTopOverlay), findsNothing);

      // 動画ファイルなので showControls が true でも MediaViewerBottomOverlay は表示されない（重なり防止）
      expect(find.byType(MediaViewerBottomOverlay), findsNothing);

      // もう一度タップして表示する。
      await tester.tap(find.byType(VideoPlayerView));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(container.read(mediaViewerViewModelProvider).showControls, isTrue);
      expect(find.byKey(const ValueKey('viewer-file-info')), findsOneWidget);
      expect(find.byType(MediaViewerTopOverlay), findsNothing);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('テキストファイル表示時、初期状態から主要操作が見え、タップで表示・非表示が切り替わる', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync(
        'media_viewer_txt_test',
      );
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });
      final file = File('${tempDir.path}/sample.txt');
      file.writeAsStringSync('Hello, Text Content!');

      final textItem = MediaItem()
        ..id = 100
        ..path = 'sample.txt'
        ..type = MediaType.file
        ..mimeType = 'text/plain'
        ..sourceType = MediaSourceType.localCopy;

      final container = ProviderContainer(
        overrides: [
          appDocumentsPathSyncProvider.overrideWithValue(tempDir.path),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaViewerScreen(
              initialItem: textItem,
              sourceContext: const ViewerSourceContext.single(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 初回利用でも閉じる操作を発見できるよう、最初から表示する。
      final state = container.read(mediaViewerViewModelProvider);
      expect(state.showControls, isTrue);
      expect(find.byType(MediaViewerTopOverlay), findsNothing);
      expect(find.byType(MediaViewerBottomOverlay), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      // 画面をタップしてコントロールを非表示にする。
      await tester.tap(find.byType(MediaViewerScreen));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        container.read(mediaViewerViewModelProvider).showControls,
        isFalse,
      );
      expect(find.byKey(const ValueKey('viewer-file-info')), findsNothing);
      expect(find.byType(MediaViewerTopOverlay), findsNothing);

      // もう一度タップして操作を表示する。
      await tester.tap(find.byType(MediaViewerScreen));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(container.read(mediaViewerViewModelProvider).showControls, isTrue);
      expect(find.byKey(const ValueKey('viewer-file-info')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('viewer-file-info')));
      await tester.pumpAndSettle();
      expect(find.byType(MediaViewerTopOverlay), findsOneWidget);
      Navigator.of(tester.element(find.byType(MediaViewerTopOverlay))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsOneWidget);

      // 再度タップして全画面に戻る。
      await tester.tap(find.byType(MediaViewerScreen));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        container.read(mediaViewerViewModelProvider).showControls,
        isFalse,
      );
      expect(find.byType(MediaViewerTopOverlay), findsNothing);
      expect(find.byType(AppBar), findsNothing);

      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('下部オーバーレイの背景領域からでも横スワイプできる', (tester) async {
      final first = MediaItem()
        ..id = 301
        ..path = 'first.txt'
        ..type = MediaType.file
        ..mimeType = 'text/plain'
        ..sourceType = MediaSourceType.localCopy;
      final second = MediaItem()
        ..id = 302
        ..path = 'second.txt'
        ..type = MediaType.file
        ..mimeType = 'text/plain'
        ..sourceType = MediaSourceType.localCopy;
      final container = ProviderContainer(
        overrides: [appDocumentsPathSyncProvider.overrideWithValue('/tmp')],
      );
      addTearDown(container.dispose);

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

      // コントロールを表示
      container
          .read(mediaViewerViewModelProvider.notifier)
          .setControlsVisible(true);
      await tester.pumpAndSettle();

      final overlayRect = tester.getRect(find.byType(MediaViewerBottomOverlay));
      final sliderRect = tester.getRect(
        find.byKey(const Key('media_viewer_page_slider')),
      );
      final start = Offset(overlayRect.left + 12, sliderRect.center.dy);
      expect(sliderRect.contains(start), isFalse);

      await tester.dragFrom(start, const Offset(-600, 0));
      await tester.pumpAndSettle();

      expect(
        container.read(mediaViewerViewModelProvider).currentItem?.id,
        second.id,
      );
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('スワイプ中は画面シェルの選択状態を更新せず、終了時に一度だけ確定する', (tester) async {
      final first = MediaItem()
        ..id = 311
        ..path = 'first.txt'
        ..type = MediaType.file
        ..mimeType = 'text/plain'
        ..sourceType = MediaSourceType.localCopy;
      final second = MediaItem()
        ..id = 312
        ..path = 'second.txt'
        ..type = MediaType.file
        ..mimeType = 'text/plain'
        ..sourceType = MediaSourceType.localCopy;
      final container = ProviderContainer(
        overrides: [appDocumentsPathSyncProvider.overrideWithValue('/tmp')],
      );
      addTearDown(container.dispose);

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

      final pageViewFinder = find.byKey(const Key('media_viewer_page_view'));
      final gesture = await tester.startGesture(
        tester.getCenter(pageViewFinder),
      );
      // The first movement resolves the horizontal/vertical gesture arena;
      // the second one moves the PageView while the pointer remains down.
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-680, 0));
      await tester.pump();

      // Force unrelated root rebuilds while the pointer is still down. The
      // transient PageView focus must not leak into the committed shell.
      final viewModel = container.read(mediaViewerViewModelProvider.notifier);
      viewModel.setControlsVisible(false);
      await tester.pump();
      viewModel.setControlsVisible(true);
      await tester.pump();

      final pageView = tester.widget<PageView>(pageViewFinder);
      expect(pageView.controller!.page, greaterThan(0.5));
      expect(
        container.read(mediaViewerViewModelProvider).currentItem?.id,
        first.id,
      );
      expect(
        tester
            .widget<MediaViewerBottomOverlay>(
              find.byType(MediaViewerBottomOverlay),
            )
            .currentIndex,
        0,
      );

      await gesture.up();
      await tester.pumpAndSettle();

      expect(
        container.read(mediaViewerViewModelProvider).currentItem?.id,
        second.id,
      );
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('ページスライダーはドラッグ終了時だけページ移動を通知する', (tester) async {
      final changedPages = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Stack(
              children: [
                MediaViewerBottomOverlay(
                  totalPages: 10,
                  currentIndex: 0,
                  totalFiles: 10,
                  currentFileIndex: 0,
                  splitSide: null,
                  onPageChanged: changedPages.add,
                ),
              ],
            ),
          ),
        ),
      );

      final slider = find.byKey(const Key('media_viewer_page_slider'));
      final sliderTheme = tester.widget<SliderTheme>(
        find.ancestor(of: slider, matching: find.byType(SliderTheme)).first,
      );
      expect(sliderTheme.data.tickMarkShape, SliderTickMarkShape.noTickMark);

      final gesture = await tester.startGesture(tester.getCenter(slider));
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();

      expect(changedPages, isEmpty);
      final sliderValue = tester.widget<Slider>(slider).value.round() + 1;
      final l10n = AppLocalizations.of(
        tester.element(find.byType(MediaViewerBottomOverlay)),
      )!;
      expect(
        find.text(l10n.viewerPagePosition(sliderValue, 10)),
        findsOneWidget,
      );

      await gesture.up();
      await tester.pumpAndSettle();

      expect(changedPages, hasLength(1));
      expect(changedPages.single, greaterThan(0));
    });

    testWidgets('遅れて完了した旧ページの外部再生要求を破棄する', (tester) async {
      SharedPreferences.setMockInitialValues({});
      const pathProviderChannel = MethodChannel(
        'plugins.flutter.io/path_provider',
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        pathProviderChannel,
        (call) async => '/tmp',
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          pathProviderChannel,
          null,
        ),
      );
      final first = MediaItem()
        ..id = 321
        ..path = 'content://example/first.mp4'
        ..originalPath = 'first.mp4'
        ..type = MediaType.file
        ..mimeType = 'video/mp4'
        ..isImportPreview = true
        ..sourceType = MediaSourceType.localCopy;
      final second = MediaItem()
        ..id = 322
        ..path = 'content://example/second.mp4'
        ..originalPath = 'second.mp4'
        ..type = MediaType.file
        ..mimeType = 'video/mp4'
        ..isImportPreview = true
        ..sourceType = MediaSourceType.localCopy;
      final firstPreview = Completer<String?>();
      final secondPreview = Completer<String?>();
      final playedItemIds = <int>[];
      final container = ProviderContainer(
        overrides: [
          appDocumentsPathSyncProvider.overrideWithValue('/tmp'),
          externalFilePreviewProvider(
            first,
          ).overrideWith((ref) => firstPreview.future),
          externalFilePreviewProvider(
            second,
          ).overrideWith((ref) => secondPreview.future),
          mediaItemProvider(first.id).overrideWith((ref) => first),
          mediaItemProvider(second.id).overrideWith((ref) => second),
          playerNotifierProvider.overrideWith(
            () => _RecordingPlayerNotifier(playedItemIds),
          ),
        ],
      );
      addTearDown(container.dispose);

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      final pageViewFinder = find.byKey(const Key('media_viewer_page_view'));
      final pageView = tester.widget<PageView>(pageViewFinder);
      unawaited(
        pageView.controller!.animateToPage(
          1,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        container.read(mediaViewerViewModelProvider).currentItem?.id,
        isNull,
      );

      expect(pageView.controller!.page, closeTo(1, 0.01));
      secondPreview.complete('/tmp/nonexistent-second.mp4');
      for (var i = 0; i < 5 && playedItemIds.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(playedItemIds, [second.id]);

      firstPreview.complete('/tmp/nonexistent-first.mp4');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();

      expect(playedItemIds, [second.id]);

      unawaited(
        pageView.controller!.animateToPage(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      for (var i = 0; i < 5 && playedItemIds.length < 2; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }

      expect(playedItemIds, [second.id, first.id]);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('指定ファイルのページを初期ページとして直接生成する', (tester) async {
      final items = List.generate(
        3,
        (index) => MediaItem()
          ..id = 401 + index
          ..path = 'page_$index.txt'
          ..type = MediaType.file
          ..mimeType = 'text/plain'
          ..sourceType = MediaSourceType.localCopy,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDocumentsPathSyncProvider.overrideWithValue('/tmp')],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaViewerScreen(
              initialItem: items.last,
              sourceContext: ViewerSourceContext.customList(items),
            ),
          ),
        ),
      );
      await tester.pump();

      final pageView = tester.widget<PageView>(
        find.byKey(const Key('media_viewer_page_view')),
      );
      expect(pageView.controller?.initialPage, 2);
      expect(
        find.byKey(const ValueKey('viewer-page-403-full')),
        findsOneWidget,
      );
    });
  });
}

class _RecordingPlayerNotifier extends PlayerNotifier {
  _RecordingPlayerNotifier(this.playedItemIds);

  final List<int> playedItemIds;

  @override
  PlayerState build() => PlayerState();

  @override
  Future<void> play(
    MediaItem item, {
    File? file,
    bool isExpanded = true,
    bool showMiniPlayer = true,
    List<MediaItem>? playlist,
    Object? owner,
  }) async {
    playedItemIds.add(item.id);
    state = PlayerState(
      currentItem: item,
      isExpanded: isExpanded,
      showMiniPlayer: showMiniPlayer,
    );
  }

  @override
  Future<void> stop({Object? owner}) async {}
}
