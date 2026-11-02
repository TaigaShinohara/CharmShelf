import 'package:private_shelf/features/library/presentation/helpers/library_action_handler.dart';
import 'package:private_shelf/shared/widgets/app_popup_menu_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/shared/icons/library_action_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/library_selection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';
import 'package:private_shelf/features/library/presentation/widgets/library_selection_menu.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';

import '../../../../helpers/test_helpers.dart';

void main() {
  setUp(() {
    setupMockSharedPreferences();
  });

  MediaItem createItem({
    required int id,
    required String path,
    bool isCatalog = false,
  }) {
    final item = MediaItem()
      ..id = id
      ..path = path
      ..type = MediaType.file;

    if (isCatalog) {
      final col = MediaCollection()
        ..id = id
        ..path = path
        ..isCatalog = isCatalog;
      item.collection.value = col;
    }
    return item;
  }

  testWidgets('全選択と解除で件数が更新され選択モードは維持される', (tester) async {
    final items = [
      createItem(id: 1, path: 'one'),
      createItem(id: 2, path: 'two'),
    ];
    await tester.pumpWidget(
      createProviderApp(
        const LibrarySelectionMenu(mode: AppMode.internal),
        overrides: [
          libraryViewModelProvider.overrideWith(
            () => _MockLibraryViewModel(items),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LibrarySelectionMenu)),
    );
    for (final count in [2, 0]) {
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      final all = find.byWidgetPredicate(
        (widget) => widget is AppPopupMenuItem<String> && widget.value == 'all',
      );
      await tester.tap(all);
      await tester.pumpAndSettle();
      final state = container.read(librarySelectionNotifierProvider);
      expect(state.selectedCount, count);
      expect(state.isSelectionMode, isTrue);
    }
  });

  testWidgets('内部の全操作が既存ハンドラーへ接続される', (tester) async {
    final handler = _RecordingActionHandler();
    final items = [createItem(id: 1, path: 'book', isCatalog: true)];
    await tester.pumpWidget(
      createProviderApp(
        LibrarySelectionMenu(mode: AppMode.internal, actionHandler: handler),
        overrides: [
          libraryViewModelProvider.overrideWith(
            () => _MockLibraryViewModel(items),
          ),
          librarySelectionNotifierProvider.overrideWith(
            () => _MockLibrarySelectionNotifier(
              const LibrarySelectionState(
                isSelectionMode: true,
                selectedIds: {1},
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    for (final action in ['uncatalog', 'tag', 'move', 'copy', 'save']) {
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      final entry = find.byWidgetPredicate(
        (widget) =>
            widget is AppPopupMenuItem<String> && widget.value == action,
      );
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(handler.calls.last, action);
    }
  });

  testWidgets('外部ではタグとティアを表示し内部専用操作を出さない', (tester) async {
    final handler = _RecordingActionHandler();
    final items = [createItem(id: 1, path: 'book', isCatalog: true)];
    await tester.pumpWidget(
      createProviderApp(
        LibrarySelectionMenu(mode: AppMode.external, actionHandler: handler),
        overrides: [
          externalLibraryViewModelProvider.overrideWith(
            () => _MockExternalViewModel(items),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LibrarySelectionMenu)),
    );
    container
        .read(externalLibraryViewModelProvider.notifier)
        .toggleSelection(1);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    final entries = tester
        .widgetList<AppPopupMenuItem<String>>(
          find.byType(AppPopupMenuItem<String>),
        )
        .toList();
    expect(entries.map((item) => item.value), [
      'all',
      'catalog',
      'uncatalog',
      'tag',
      'tier',
    ]);
    expect(
      entries.singleWhere((item) => item.value == 'catalog').enabled,
      isFalse,
    );
    expect(entries.singleWhere((item) => item.value == 'tag').enabled, isTrue);
    final tier = find.byWidgetPredicate(
      (widget) => widget is AppPopupMenuItem<String> && widget.value == 'tier',
    );
    await tester.tap(tier);
    await tester.pumpAndSettle();
    expect(handler.calls, ['tier']);
  });

  group('LibrarySelectionMenu - タグボタンのカタログ限定有効化テスト', () {
    testWidgets('アイテムが選択されていない場合、タグボタンは無効', (tester) async {
      final items = [
        createItem(id: 1, path: 'folder1/file1.jpg', isCatalog: false),
      ];

      await tester.pumpWidget(
        createProviderApp(
          const LibrarySelectionMenu(mode: AppMode.internal),
          overrides: [
            libraryViewModelProvider.overrideWith(
              () => _MockLibraryViewModel(items),
            ),
            librarySelectionNotifierProvider.overrideWith(
              () =>
                  _MockLibrarySelectionNotifier(const LibrarySelectionState()),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      final iconFinder = find.byType(CharmIcon);
      expect(iconFinder, findsOneWidget);
      final iconButton = tester.widget<AppPopupMenuItem<String>>(
        find.ancestor(
          of: iconFinder,
          matching: find.byType(AppPopupMenuItem<String>),
        ),
      );
      expect(iconButton.enabled, isFalse);
    });

    testWidgets('通常ファイル（非カタログ）のみ選択されている場合、タグボタンは無効', (tester) async {
      final items = [
        createItem(id: 1, path: 'folder1/file1.jpg', isCatalog: false),
        createItem(id: 2, path: 'folder1/file2.jpg', isCatalog: false),
      ];

      await tester.pumpWidget(
        createProviderApp(
          const LibrarySelectionMenu(mode: AppMode.internal),
          overrides: [
            libraryViewModelProvider.overrideWith(
              () => _MockLibraryViewModel(items),
            ),
            librarySelectionNotifierProvider.overrideWith(
              () => _MockLibrarySelectionNotifier(
                const LibrarySelectionState(
                  isSelectionMode: true,
                  selectedIds: {1},
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      final iconFinder = find.byType(CharmIcon);
      expect(iconFinder, findsOneWidget);
      final iconButton = tester.widget<AppPopupMenuItem<String>>(
        find.ancestor(
          of: iconFinder,
          matching: find.byType(AppPopupMenuItem<String>),
        ),
      );
      expect(iconButton.enabled, isFalse);
    });

    testWidgets('通常ファイルとカタログが混在して選択されている場合、タグボタンは無効', (tester) async {
      final items = [
        createItem(id: 1, path: 'folder1/file1.jpg', isCatalog: false),
        createItem(id: 2, path: 'books/book1', isCatalog: true),
      ];

      await tester.pumpWidget(
        createProviderApp(
          const LibrarySelectionMenu(mode: AppMode.internal),
          overrides: [
            libraryViewModelProvider.overrideWith(
              () => _MockLibraryViewModel(items),
            ),
            librarySelectionNotifierProvider.overrideWith(
              () => _MockLibrarySelectionNotifier(
                const LibrarySelectionState(
                  isSelectionMode: true,
                  selectedIds: {1, 2},
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      final iconFinder = find.byType(CharmIcon);
      expect(iconFinder, findsOneWidget);
      final iconButton = tester.widget<AppPopupMenuItem<String>>(
        find.ancestor(
          of: iconFinder,
          matching: find.byType(AppPopupMenuItem<String>),
        ),
      );
      expect(iconButton.enabled, isFalse);
    });

    testWidgets('カタログのみ選択されている場合、タグボタンは有効', (tester) async {
      final items = [
        createItem(id: 1, path: 'books/book1', isCatalog: true),
        createItem(id: 2, path: 'books/book2', isCatalog: true),
        createItem(id: 3, path: 'normal/file.jpg', isCatalog: false),
      ];

      await tester.pumpWidget(
        createProviderApp(
          const LibrarySelectionMenu(mode: AppMode.internal),
          overrides: [
            libraryViewModelProvider.overrideWith(
              () => _MockLibraryViewModel(items),
            ),
            librarySelectionNotifierProvider.overrideWith(
              () => _MockLibrarySelectionNotifier(
                const LibrarySelectionState(
                  isSelectionMode: true,
                  selectedIds: {1, 2},
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      final iconFinder = find.byType(CharmIcon);
      expect(iconFinder, findsOneWidget);
      final iconButton = tester.widget<AppPopupMenuItem<String>>(
        find.ancestor(
          of: iconFinder,
          matching: find.byType(AppPopupMenuItem<String>),
        ),
      );
      expect(iconButton.enabled, isTrue);
    });

    testWidgets('320dp・文字200%でも操作を縮小せず全項目が48dp以上', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final items = [createItem(id: 1, path: 'books/book1', isCatalog: true)];
      await tester.pumpWidget(
        createProviderApp(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: const LibrarySelectionMenu(mode: AppMode.internal),
            ),
          ),
          overrides: [
            libraryViewModelProvider.overrideWith(
              () => _MockLibraryViewModel(items),
            ),
            librarySelectionNotifierProvider.overrideWith(
              () => _MockLibrarySelectionNotifier(
                const LibrarySelectionState(
                  isSelectionMode: true,
                  selectedIds: {1},
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // SVG icons fit their fixed-size viewport. Menu labels must never shrink.
      for (final element in find.byType(Text).evaluate()) {
        expect(
          find.ancestor(
            of: find.byWidget(element.widget),
            matching: find.byType(FittedBox),
          ),
          findsNothing,
        );
      }
      for (final element in find.byType(AppPopupMenuItem<String>).evaluate()) {
        final size = tester.getSize(find.byWidget(element.widget));
        expect(size.height, greaterThanOrEqualTo(48));
      }
    });
  });
}

class _MockLibraryViewModel extends LibraryViewModel {
  final List<MediaItem> _items;
  _MockLibraryViewModel(this._items);

  @override
  Future<List<MediaItem>> build() async => _items;
}

class _MockLibrarySelectionNotifier extends LibrarySelectionNotifier {
  final LibrarySelectionState _initialState;
  _MockLibrarySelectionNotifier(this._initialState);

  @override
  LibrarySelectionState build() => _initialState;
}

class _MockExternalViewModel extends ExternalLibraryViewModel {
  _MockExternalViewModel(this.items);
  final List<MediaItem> items;
  @override
  Future<List<MediaItem>> build() async => items;
}

class _RecordingActionHandler extends LibraryActionHandler {
  final calls = <String>[];
  @override
  Future<void> handleBulkCatalog(
    BuildContext context,
    WidgetRef ref,
    AppMode mode, {
    required bool decatalogify,
  }) async {
    calls.add(decatalogify ? 'uncatalog' : 'catalog');
  }

  @override
  Future<void> showBulkTagSelectorSheet(
    BuildContext context,
    WidgetRef ref,
    AppMode mode,
  ) async {
    calls.add('tag');
  }

  @override
  Future<void> handleBulkMove(
    BuildContext context,
    WidgetRef ref,
    AppMode mode,
  ) async {
    calls.add('move');
  }

  @override
  Future<void> handleBulkDuplicate(
    BuildContext context,
    WidgetRef ref,
    AppMode mode,
  ) async {
    calls.add('copy');
  }

  @override
  Future<void> handleBulkDownload(
    BuildContext context,
    WidgetRef ref,
    AppMode mode,
  ) async {
    calls.add('save');
  }

  @override
  Future<void> showExternalBulkTierDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    calls.add('tier');
  }
}
