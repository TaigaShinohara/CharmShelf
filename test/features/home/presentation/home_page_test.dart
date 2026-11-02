import 'dart:convert';
import 'package:private_shelf/features/library/presentation/providers/collection_cover_thumbnail_provider.dart';
import 'package:private_shelf/features/home/presentation/widgets/recent_collection_card.dart';
import 'package:private_shelf/features/home/presentation/widgets/recent_history_widgets.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:private_shelf/core/theme/app_theme.dart';
import 'package:private_shelf/features/library/data/services/external_storage_service.dart';
import 'package:private_shelf/features/library/data/repositories/viewing_history_repository.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/domain/models/recently_opened_file.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/core/providers/tab_navigation_provider.dart';
import 'package:private_shelf/features/home/presentation/home_page.dart';
import 'package:private_shelf/features/home/presentation/providers/favorite_collections_provider.dart';
import 'package:private_shelf/features/home/presentation/providers/home_library_items_provider.dart';
import 'package:private_shelf/features/home/presentation/providers/personal_library_state_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/viewing_history_provider.dart';
import 'package:private_shelf/features/samples/presentation/sample_preview_screen.dart';
import 'package:private_shelf/core/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:private_shelf/features/home/presentation/providers/recently_viewed_collections_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/selected_document.dart';
import 'package:private_shelf/features/library/presentation/helpers/system_file_picker.dart';
import 'package:private_shelf/features/library/presentation/providers/import_flow_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/features/library/presentation/screens/import_selection_screen.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import '../../../shared/finders.dart' as shared_find;

class _HistoryRepository extends Mock implements ViewingHistoryRepository {}

class _CancelledFilePicker extends Mock
    with MockPlatformInterfaceMixin
    implements FilePickerPlatform {}

class _CancelledStorageService extends Mock implements ExternalStorageService {}

class _CancelledSystemPicker extends SystemFilePicker {
  final calls = <String>[];
  @override
  Future<SelectedDocument?> openFile() async {
    calls.add('open');
    return null;
  }

  @override
  Future<List<SelectedDocument>?> pickFiles() async {
    calls.add('files');
    return null;
  }

  @override
  Future<PickedFolder?> pickFolder() async {
    calls.add('folder');
    return null;
  }
}

class _HomeMediaFilter extends MediaFilterNotifier {
  @override
  MediaFilter build(AppMode mode) => const MediaFilter(rootOnly: true);
}

class _HomeNavigationObserver extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    super.didPush(route, previousRoute);
  }
}

ProviderContainer _homeActionContainer({
  required SystemFilePicker picker,
  required VoidCallback onImportFlowRead,
  bool isAndroid = true,
  List<MediaItem> items = const [],
  PersonalLibraryState personalState = const PersonalLibraryState(
    hasImported: false,
  ),
  ExternalStorageService? storageService,
}) => ProviderContainer(
  overrides: [
    systemFilePickerIsAndroidProvider.overrideWithValue(isAndroid),
    systemFilePickerProvider.overrideWithValue(picker),
    mediaFilterNotifierProvider(
      AppMode.internal,
    ).overrideWith(_HomeMediaFilter.new),
    importFlowNotifierProvider.overrideWith(() {
      onImportFlowRead();
      throw StateError('A cancelled picker must not start an import');
    }),
    if (storageService != null)
      externalStorageServiceProvider.overrideWith(
        (ref) async => storageService,
      ),
    hapticsEnabledProvider.overrideWith((ref) => false),
    personalLibraryStateProvider.overrideWith(
      (ref) => Stream.value(personalState),
    ),
    recentlyOpenedFilesProvider.overrideWith((ref) => Stream.value([])),
    homeLibraryItemsProvider.overrideWith((ref) => Stream.value(items)),
    recentlyViewedCollectionsProvider.overrideWith(
      (ref) => Stream.value(<MediaCollection>[]),
    ),
    favoriteCollectionsProvider.overrideWith(
      (ref) => Stream.value(<MediaCollection>[]),
    ),
  ],
);

Widget _homeActionsApp(
  ProviderContainer container,
  _HomeNavigationObserver observer,
) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    navigatorObservers: [observer],
    locale: const Locale('ja'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const HomePage(),
  ),
);

const _previewFont = String.fromEnvironment('RECENT_PREVIEW_FONT');
const _previewIcons = String.fromEnvironment('RECENT_PREVIEW_ICONS');
const _previewKey = ValueKey('recent-home-preview');

Future<void> _capture(WidgetTester tester, String name) async {
  if (_previewFont.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_previewKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('build/recent_home_review');
      await directory.create(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (_previewFont.isNotEmpty) {
      final loader = FontLoader('RecentPreview');
      loader.addFont(
        File(_previewFont).readAsBytes().then(ByteData.sublistView),
      );
      await loader.load();
    }
    if (_previewIcons.isNotEmpty) {
      final loader = FontLoader('MaterialIcons');
      loader.addFont(
        File(_previewIcons).readAsBytes().then(ByteData.sublistView),
      );
      await loader.load();
    }
  });

  final existingFile = MediaItem()..path = 'library/existing.txt';
  final legacySample = MediaItem()
    ..path = 'library/sample.txt'
    ..originalPath = 'template://welcome/Example';
  final homeStates = [
    (
      name: '初回',
      items: <MediaItem>[],
      state: const PersonalLibraryState(hasImported: false),
      showsGuide: true,
    ),
    (
      name: '取り込み済みの空状態',
      items: <MediaItem>[],
      state: const PersonalLibraryState(hasImported: true),
      showsGuide: true,
    ),
    (
      name: '通常',
      items: [existingFile],
      state: const PersonalLibraryState(hasImported: true),
      showsGuide: false,
    ),
    (
      name: '案内を閉じた状態',
      items: [legacySample],
      state: const PersonalLibraryState(
        hasImported: false,
        guideDismissed: true,
      ),
      showsGuide: false,
    ),
  ];
  for (final homeState in homeStates) {
    for (final action in ['folder', 'files']) {
      testWidgets(
        'Androidホームの${homeState.name}で$action選択をキャンセルしても取り込みを始めず留まる',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final picker = _CancelledSystemPicker();
          var importFlowReads = 0;
          final container = _homeActionContainer(
            picker: picker,
            items: homeState.items,
            personalState: homeState.state,
            onImportFlowRead: () => importFlowReads++,
          );
          addTearDown(container.dispose);
          container.read(currentTabIndexProvider.notifier).goToHome();
          final homeTab = container.read(currentTabIndexProvider);
          final observer = _HomeNavigationObserver();
          await tester.pumpWidget(_homeActionsApp(container, observer));
          await tester.pumpAndSettle();

          expect(find.text('端末のファイル'), findsNothing);
          expect(find.text('ファイルを追加'), findsNothing);
          expect(find.text('フォルダを取り込む'), findsOneWidget);
          expect(find.text('ファイルを取り込む'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('home-starter-title')),
            homeState.showsGuide ? findsOneWidget : findsNothing,
          );
          final folderButton = find.byKey(const ValueKey('home-add-folders'));
          final fileButton = find.byKey(const ValueKey('home-add-files'));
          expect(
            tester.getTopLeft(folderButton).dy,
            lessThan(tester.getTopLeft(fileButton).dy),
          );
          final pushesBeforePicker = observer.pushes;
          final button = action == 'folder' ? folderButton : fileButton;
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();

          expect(picker.calls, [action]);
          expect(importFlowReads, 0);
          expect(observer.pushes, pushesBeforePicker);
          expect(find.byType(ImportSelectionScreen), findsNothing);
          expect(find.byType(HomePage), findsOneWidget);
          expect(container.read(currentTabIndexProvider), homeTab);
          expect(container.read(pendingLibraryLaunchActionProvider), isNull);
          expect(find.text('ファイルを開く'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  for (final action in ['folder', 'files']) {
    testWidgets('Android以外のホームで$action選択をキャンセルしても元画面に留まる', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final systemPicker = _CancelledSystemPicker();
      final filePicker = _CancelledFilePicker();
      final originalPicker = FilePickerPlatform.instance;
      FilePickerPlatform.instance = filePicker;
      addTearDown(() => FilePickerPlatform.instance = originalPicker);
      when(
        () => filePicker.pickFiles(type: FileType.any),
      ).thenAnswer((_) async => <PlatformFile>[]);
      final storage = _CancelledStorageService();
      when(() => storage.pickFolder()).thenAnswer((_) async => null);
      var importFlowReads = 0;
      final container = _homeActionContainer(
        picker: systemPicker,
        isAndroid: false,
        storageService: storage,
        onImportFlowRead: () => importFlowReads++,
      );
      addTearDown(container.dispose);
      container.read(currentTabIndexProvider.notifier).goToHome();
      final homeTab = container.read(currentTabIndexProvider);
      final observer = _HomeNavigationObserver();
      await tester.pumpWidget(_homeActionsApp(container, observer));
      await tester.pumpAndSettle();
      final pushesBeforePicker = observer.pushes;
      final button = find.byKey(
        ValueKey(action == 'folder' ? 'home-add-folders' : 'home-add-files'),
      );
      await tester.ensureVisible(button);
      // The shared picker session awaits broadcast-stream cancellation even
      // when the native picker returns null. Finish that work outside the
      // widget clock before restoring its platform mock or starting a new test.
      await tester.runAsync(() async {
        await tester.tap(button);
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();

      if (action == 'folder') {
        verify(() => storage.pickFolder()).called(1);
        verifyNever(() => filePicker.pickFiles(type: FileType.any));
      } else {
        verify(() => filePicker.pickFiles(type: FileType.any)).called(1);
        verifyNever(() => storage.pickFolder());
      }
      expect(systemPicker.calls, isEmpty);
      expect(importFlowReads, 0);
      expect(observer.pushes, pushesBeforePicker);
      expect(find.byType(ImportSelectionScreen), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
      expect(container.read(currentTabIndexProvider), homeTab);
      expect(container.read(pendingLibraryLaunchActionProvider), isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('狭い画面と200%文字サイズでも初回見出しが画面内に収まる', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hapticsEnabledProvider.overrideWith((ref) => false),
          personalLibraryStateProvider.overrideWith(
            (ref) =>
                Stream.value(const PersonalLibraryState(hasImported: false)),
          ),
          recentlyOpenedFilesProvider.overrideWith((ref) => Stream.value([])),
          homeLibraryItemsProvider.overrideWith(
            (ref) => Stream.value(<MediaItem>[]),
          ),
          recentlyViewedCollectionsProvider.overrideWith(
            (ref) => Stream.value(<MediaCollection>[]),
          ),
          favoriteCollectionsProvider.overrideWith(
            (ref) => Stream.value(<MediaCollection>[]),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('ja'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('ja'), Locale('en')],
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: HomePage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final titleRect = tester.getRect(
      find.byKey(const ValueKey('home-starter-title')),
    );
    expect(titleRect.left, greaterThanOrEqualTo(0));
    expect(titleRect.right, lessThanOrEqualTo(320));
    for (final key in ['home-add-folders', 'home-add-files']) {
      final button = find.byKey(ValueKey(key));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      final buttonRect = tester.getRect(button);
      final label = find.descendant(of: button, matching: find.byType(Text));
      final labelRect = tester.getRect(label);
      expect(buttonRect.left, greaterThanOrEqualTo(0));
      expect(buttonRect.right, lessThanOrEqualTo(320));
      expect(buttonRect.height, greaterThanOrEqualTo(48));
      expect(labelRect.left, greaterThanOrEqualTo(buttonRect.left));
      expect(labelRect.right, lessThanOrEqualTo(buttonRect.right));
      expect(labelRect.top, greaterThanOrEqualTo(buttonRect.top));
      expect(labelRect.bottom, lessThanOrEqualTo(buttonRect.bottom));
      expect(
        tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
        isFalse,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('ホームの初回と通常状態で取り込みボタンを描画する', (tester) async {
    tester.view.physicalSize = const Size(360, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final hasImported in [false, true]) {
      await tester.pumpWidget(
        _homeApp(
          items: hasImported ? [existingFile] : [],
          hasImported: hasImported,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('フォルダを取り込む'), findsOneWidget);
      expect(find.text('ファイルを取り込む'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('home-add-files')));
      await tester.pumpAndSettle();
      await _capture(
        tester,
        hasImported ? 'imports-normal' : 'imports-initial',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('小型画面かつ200%文字サイズではホームのカタログを1列で表示する', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final collections = List.generate(
      5,
      (index) => MediaCollection()
        ..path = 'catalog-$index'
        ..title = 'Catalog $index'
        ..createdAt = DateTime(2026)
        ..updatedAt = DateTime(2026),
    );
    final favorites = List.generate(
      1,
      (index) => MediaCollection()
        ..path = 'favorite-$index'
        ..title = 'Favorite $index'
        ..createdAt = DateTime(2026)
        ..updatedAt = DateTime(2026),
    );
    final item = MediaItem()
      ..path = 'catalog-0'
      ..originalPath = 'catalog-0'
      ..addedAt = DateTime(2026)
      ..updatedAt = DateTime(2026);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hapticsEnabledProvider.overrideWith((ref) => false),
          personalLibraryStateProvider.overrideWith(
            (ref) =>
                Stream.value(const PersonalLibraryState(hasImported: true)),
          ),
          recentlyOpenedFilesProvider.overrideWith((ref) => Stream.value([])),
          homeLibraryItemsProvider.overrideWith((ref) => Stream.value([item])),
          recentlyViewedCollectionsProvider.overrideWith(
            (ref) => Stream.value(collections),
          ),
          favoriteCollectionsProvider.overrideWith(
            (ref) => Stream.value(favorites),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('ja'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('ja'), Locale('en')],
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: HomePage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final recentGrid = find.byType(RecentHistoryGrid).first;
    expect(recentGrid, findsOneWidget);
    final seeMore = find.text('さらに見る');
    expect(seeMore, findsOneWidget);
    await tester.ensureVisible(seeMore);
    expect(seeMore.hitTestable(), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-section-toggle-recentlyViewed')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('旧サンプルだけでも追加案内を表示し閉じた状態を保存する', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final sample = MediaItem()
      ..path = 'library/sample.txt'
      ..originalPath = 'template://welcome/Example';
    await tester.pumpWidget(_homeApp(items: [sample], prefs: prefs));
    await tester.pumpAndSettle();
    expect(shared_find.findAppText('ファイルを追加してはじめましょう'), findsOneWidget);
    expect(find.text('フォルダを取り込む'), findsOneWidget);
    expect(find.text('ファイルを取り込む'), findsOneWidget);
    await tester.ensureVisible(find.text('案内を閉じる'));
    await tester.tap(find.text('案内を閉じる'));
    await tester.pumpAndSettle();
    expect(prefs.getBool(personalImportGuideDismissedKey), isTrue);
    expect(shared_find.findAppText('ファイルを追加してはじめましょう'), findsNothing);
    expect(find.text('見本のカタログを見る'), findsOneWidget);
    final folderButton = find.byKey(const ValueKey('home-add-folders'));
    final fileButton = find.byKey(const ValueKey('home-add-files'));
    expect(folderButton, findsOneWidget);
    expect(fileButton, findsOneWidget);
    expect(
      tester.getTopLeft(folderButton).dy,
      lessThan(tester.getTopLeft(fileButton).dy),
    );
  });

  for (final count in [0, 1, 2, 3, 4, 5]) {
    testWidgets('最近のファイル$count件を件数に応じた幅で最大4件表示する', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final entries = [
        for (var i = 0; i < count; i++)
          RecentlyOpenedFile(
            item: MediaItem()
              ..uid = 'item-$i'
              ..path = 'library/file-$i.txt',
            catalog: MediaCollection()
              ..title = 'Catalog $i'
              ..alias = '別名 $i',
          ),
      ];
      await tester.pumpWidget(
        _homeApp(
          items: entries.map((e) => e.item).toList(),
          hasImported: true,
          recentEntries: entries,
        ),
      );
      await tester.pumpAndSettle();
      final cards = find.byKey(const ValueKey('home-open-recent'));
      final visibleCount = count > 4 ? 4 : count;
      expect(cards, findsNWidgets(visibleCount));
      for (var i = 0; i < visibleCount; i++) {
        final rect = tester.getRect(cards.at(i));
        expect(rect.top, tester.getRect(cards.at(i ~/ 2 * 2)).top);
        expect(rect.left, greaterThanOrEqualTo(16));
        expect(rect.right, lessThanOrEqualTo(344));
        expect(find.text('別名 $i'), findsOneWidget);
        expect(find.text('Catalog $i'), findsNothing);
        if (i.isOdd) {
          expect(rect.left, greaterThan(tester.getRect(cards.at(i - 1)).right));
        }
      }
      await _capture(tester, 'recent-$count');
      expect(find.text('file-4'), findsNothing);
      expect(find.text('さらに見る'), count > 4 ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('単体写真の名前と形式を分け、同じカタログ名を繰り返さない', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final item = MediaItem()
      ..uid = 'morning'
      ..path = 'library/spring_trip_morning.png';
    final collection = MediaCollection()
      ..path = item.path
      ..title = 'spring_trip_morning';
    await tester.pumpWidget(
      _homeApp(
        items: [item],
        hasImported: true,
        recentEntries: [RecentlyOpenedFile(item: item, catalog: collection)],
        documentsPath: Directory.systemTemp.path,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('spring_trip_morning'), findsOneWidget);
    expect(find.text('spring_trip_morning.png'), findsNothing);
    expect(find.text('PNG'), findsOneWidget);
    expect(tester.getSize(find.byType(RecentHistoryCard)).width, 358);
    expect(tester.takeException(), isNull);
  });

  testWidgets('単体ファイルに付けた表示名を最近のカードで優先する', (tester) async {
    final item = MediaItem()
      ..uid = 'morning'
      ..path = 'library/photo.png';
    final collection = MediaCollection()
      ..path = item.path
      ..title = 'photo'
      ..alias = '家族との朝';
    await tester.pumpWidget(
      _homeApp(
        items: [item],
        hasImported: true,
        recentEntries: [RecentlyOpenedFile(item: item, catalog: collection)],
        documentsPath: Directory.systemTemp.path,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('家族との朝'), findsOneWidget);
    expect(find.text('photo'), findsNothing);
    expect(find.text('PNG'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('狭い画面と文字200%では1列に切り替わり縦に閲覧できる', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final entries = [
      for (var i = 0; i < 3; i++)
        RecentlyOpenedFile(
          item: MediaItem()
            ..uid = 'long-$i'
            ..path = 'library/とても長いファイル名の確認用資料$i.txt',
          catalog: MediaCollection()..title = '長いカタログの名前を表示するテスト$i',
        ),
    ];
    await tester.pumpWidget(
      _homeApp(
        items: entries.map((e) => e.item).toList(),
        hasImported: true,
        recentEntries: entries,
        textScale: 2,
      ),
    );
    await tester.pumpAndSettle();
    final cards = find.byKey(const ValueKey('home-open-recent'));
    expect(cards, findsNWidgets(3));
    for (var i = 0; i < 3; i++) {
      final rect = tester.getRect(cards.at(i));
      expect(rect.left, 16);
      expect(rect.right, lessThanOrEqualTo(304));
      if (i > 0) {
        expect(rect.top, greaterThan(tester.getRect(cards.at(i - 1)).bottom));
      }
    }
    await _capture(tester, 'recent-large-text');
    expect(tester.takeException(), isNull);
  });

  testWidgets('最近開いた通常ファイルと独立サンプルの入口がホームに表示される', (tester) async {
    final item = MediaItem()
      ..uid = 'ordinary-file'
      ..path = 'library/reading-notes.txt'
      ..type = MediaType.file;
    await tester.pumpWidget(
      _homeApp(items: [item], hasImported: true, lastOpened: item),
    );
    await tester.pumpAndSettle();
    expect(find.text('最近開いたファイル'), findsOneWidget);
    expect(find.text('reading-notes'), findsOneWidget);
    expect(find.text('TXT'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-recent-preview')), findsOneWidget);
    expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsNothing);
    expect(find.byIcon(Icons.arrow_forward), findsNothing);
    expect(find.text('カタログなし'), findsNothing);
    expect(find.byKey(const ValueKey('home-open-recent')), findsOneWidget);
    expect(shared_find.findAppText('ファイルを追加してはじめましょう'), findsNothing);
    expect(find.text('お気に入りにすると、ここからすぐに開けます'), findsNothing);
    expect(find.text('さらに見る'), findsNothing);
    await tester.ensureVisible(find.text('見本のカタログを見る'));
    await tester.tap(find.text('見本のカタログを見る'));
    await tester.pumpAndSettle();
    expect(find.byType(SamplePreviewScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('各カードが選んだファイルを再確認し参照切れを通知する', (tester) async {
    final repository = _HistoryRepository();
    final entries = [
      for (var i = 0; i < 3; i++)
        RecentlyOpenedFile(
          item: MediaItem()
            ..uid = 'tap-$i'
            ..path = 'library/tap-$i.txt',
        ),
    ];
    for (final entry in entries) {
      when(
        () => repository.resolve(
          entry.item.uid!,
          sourceType: MediaSourceType.localCopy,
          includeHidden: false,
        ),
      ).thenAnswer((_) async => null);
    }
    await tester.pumpWidget(
      _homeApp(
        items: entries.map((e) => e.item).toList(),
        hasImported: true,
        recentEntries: entries,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.ensureVisible(
        find.byKey(const ValueKey('home-open-recent')).at(i),
      );
      await tester.tap(find.byKey(const ValueKey('home-open-recent')).at(i));
      await tester.pumpAndSettle();
      verify(
        () => repository.resolve(
          'tap-$i',
          sourceType: MediaSourceType.localCopy,
          includeHidden: false,
        ),
      ).called(1);
    }
    final context = tester.element(find.byType(HomePage));
    expect(
      find.text(AppLocalizations.of(context)!.homeRecentUnavailable),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('棚とファイルの幅・名前・順序を共通表示する ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final collections = [
        MediaCollection()
          ..path = 'trip'
          ..title = '春の旅行写真'
          ..alias = '旅の記録',
        MediaCollection()
          ..path = 'art'
          ..title = 'お気に入りのイラスト',
      ];
      final entries = [
        RecentlyOpenedFile(
          item: MediaItem()
            ..uid = 'photo'
            ..path = '海辺の朝.png'
            ..thumbnailPath =
                'assets/images/samples/photo_book/spring_trip_coast.png',
          catalog: collections.first,
        ),
        RecentlyOpenedFile(
          item: MediaItem()
            ..uid = 'art'
            ..path = '月明かりの読書.png'
            ..thumbnailPath =
                'assets/images/samples/illustration_collection/moonlit_reader.png',
          catalog: collections.last,
        ),
      ];
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final imageContext = tester.element(find.byType(SizedBox).first);
      await tester.runAsync(() async {
        for (final entry in entries) {
          await precacheImage(
            ResizeImage(
              FileImage(
                File('${Directory.current.path}/${entry.item.thumbnailPath}'),
              ),
              width: 512,
            ),
            imageContext,
          );
        }
      });
      await tester.pumpWidget(
        _homeApp(
          items: entries.map((e) => e.item).toList(),
          hasImported: true,
          recentEntries: entries,
          recentCollections: collections,
          documentsPath: Directory.current.path,
          dark: dark,
        ),
      );
      await tester.pumpAndSettle();
      final cards = find.byType(RecentHistoryCard);
      expect(cards, findsNWidgets(4));
      final file = tester.getRect(cards.first);
      final shelf = tester.getRect(cards.at(2));
      expect(file.size, shelf.size);
      expect(file.left, shelf.left);
      expect(find.text('旅の記録'), findsNWidgets(2));
      expect(
        tester.getTopLeft(find.text('最近開いたファイル')).dy,
        lessThan(tester.getTopLeft(find.text('最近見たカタログ')).dy),
      );
      expect(find.byType(RecentCollectionCard), findsNWidgets(2));
      await _capture(tester, dark ? 'unified-dark' : 'unified-light');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('最近開いた画像は中身の見本を表示する', (tester) async {
    final dir = Directory.systemTemp.createTempSync('tagshelf-recent-preview');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/page.png').writeAsBytesSync(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      ),
    );
    final item = MediaItem()
      ..uid = 'picture'
      ..path = 'page.png'
      ..type = MediaType.file;
    await tester.pumpWidget(
      _homeApp(
        items: [item],
        hasImported: true,
        lastOpened: item,
        documentsPath: dir.path,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-recent-preview')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _homeApp({
  required List<MediaItem> items,
  bool hasImported = false,
  MediaItem? lastOpened,
  List<RecentlyOpenedFile>? recentEntries,
  List<MediaCollection> recentCollections = const [],
  bool dark = false,
  SharedPreferences? prefs,
  String? documentsPath,
  double textScale = 1,
  ViewingHistoryRepository? repository,
}) => ProviderScope(
  overrides: [
    for (final collection in recentCollections)
      collectionCoverThumbnailProvider(collection).overrideWith(
        (ref) async => FileCoverData(
          collection.path == 'trip'
              ? 'assets/images/samples/photo_book/spring_trip_coast.png'
              : 'assets/images/samples/illustration_collection/moonlit_reader.png',
        ),
      ),
    if (repository != null)
      viewingHistoryRepositoryProvider.overrideWith((ref) async => repository),
    appModeProvider.overrideWith((ref) => AppMode.internal),
    hapticsEnabledProvider.overrideWith((ref) => false),
    if (documentsPath != null)
      appDocumentsPathSyncProvider.overrideWithValue(documentsPath),
    homeLibraryItemsProvider.overrideWith((ref) => Stream.value(items)),
    personalLibraryStateProvider.overrideWith(
      (ref) => Stream.value(
        PersonalLibraryState(
          hasImported: hasImported,
          guideDismissed:
              prefs?.getBool(personalImportGuideDismissedKey) ?? false,
        ),
      ),
    ),
    recentlyOpenedFilesProvider.overrideWith(
      (ref) => Stream.value(
        recentEntries ??
            [if (lastOpened != null) RecentlyOpenedFile(item: lastOpened)],
      ),
    ),
    recentlyViewedCollectionsProvider.overrideWith(
      (ref) => Stream.value(recentCollections),
    ),
    favoriteCollectionsProvider.overrideWith(
      (ref) => Stream.value(<MediaCollection>[]),
    ),
    if (prefs != null)
      sharedPreferencesProvider.overrideWith((ref) async => prefs),
  ],
  child: MaterialApp(
    theme: _previewFont.isEmpty
        ? null
        : (dark ? AppTheme.dark : AppTheme.light).copyWith(
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                textStyle: const TextStyle(fontFamily: 'RecentPreview'),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: (dark ? AppTheme.dark : AppTheme.light)
                  .filledButtonTheme
                  .style!
                  .copyWith(
                    textStyle: WidgetStatePropertyAll(
                      (dark ? AppTheme.dark : AppTheme.light)
                          .filledButtonTheme
                          .style!
                          .textStyle!
                          .resolve({})!
                          .copyWith(fontFamily: 'RecentPreview'),
                    ),
                  ),
            ),
            textTheme: (dark ? AppTheme.dark : AppTheme.light).textTheme.apply(
              fontFamily: 'RecentPreview',
            ),
          ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: RepaintBoundary(key: _previewKey, child: child!),
    ),
    locale: const Locale('ja'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('ja'), Locale('en')],
    home: const HomePage(),
  ),
);
