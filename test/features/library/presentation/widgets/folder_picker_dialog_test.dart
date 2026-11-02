import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';
import 'package:private_shelf/features/library/presentation/widgets/folder_picker_dialog.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

void main() {
  final sampleItems = [
    MediaItem()
      ..id = 1
      ..path = 'work/Folder A'
      ..type = MediaType.folder
      ..parentPath = 'work',
    MediaItem()
      ..id = 2
      ..path = 'photos/Folder B'
      ..type = MediaType.folder
      ..parentPath = 'photos',
    MediaItem()
      ..id = 3
      ..path = 'image.jpg'
      ..type = MediaType.file
      ..parentPath = null,
  ];

  Widget buildTestableWidget({
    required Widget child,
    List<MediaItem> items = const [],
  }) {
    return ProviderScope(
      overrides: [
        libraryViewModelProvider.overrideWith(
          () => _FakeLibraryViewModel(items),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ja'),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () =>
                    showDialog<String>(context: context, builder: (_) => child),
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );
  }

  group('FolderPickerDialog', () {
    testWidgets('タイトル・説明・フォルダ一覧（ルート含む）が表示されること', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: const FolderPickerDialog(title: '移動先を選択'),
          items: sampleItems,
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('移動先を選択'), findsOneWidget);
      expect(find.text('アイテムの移動先フォルダを選択してください'), findsOneWidget);
      expect(find.text('ルート'), findsOneWidget);
      expect(find.text('Folder A'), findsOneWidget);
      expect(find.text('work/Folder A'), findsOneWidget);
      expect(find.text('Folder B'), findsOneWidget);
      expect(find.text('photos/Folder B'), findsOneWidget);
      // ルート直下には image.jpg があるため (1項目)
      expect(find.text('(1項目)'), findsOneWidget);
      // 画像ファイル自体はリストに含まれない
      expect(find.text('image.jpg'), findsNothing);
    });

    testWidgets('現在地と移動元のバッジが正しく表示されること', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: const FolderPickerDialog(
            title: '移動先を選択',
            currentParentPath: '', // ルートが現在地
            movingItemPaths: {'work/Folder A'}, // Folder Aが移動元
          ),
          items: sampleItems,
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // ルートに「現在地」バッジが表示されている
      expect(find.text('現在地'), findsOneWidget);

      // Folder Aに「移動元」バッジが表示されている
      expect(find.text('移動元'), findsOneWidget);
    });

    testWidgets('移動可能なフォルダをタップするとパスが返ること', (tester) async {
      String? selectedPath;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryViewModelProvider.overrideWith(
              () => _FakeLibraryViewModel(sampleItems),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ja'),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      selectedPath = await showDialog<String>(
                        context: context,
                        builder: (_) => const FolderPickerDialog(
                          title: '移動先を選択',
                          currentParentPath: '', // ルートが現在地
                          movingItemPaths: {'work/Folder A'},
                        ),
                      );
                    },
                    child: const Text('Open'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Folder B をタップ（移動可能）
      await tester.tap(find.text('Folder B'));
      await tester.pumpAndSettle();

      // ダイアログが閉じて、'photos/Folder B' が返る
      expect(selectedPath, 'photos/Folder B');
    });

    testWidgets('現在地（無効アイテム）をタップしてもダイアログが閉じないこと', (tester) async {
      String? selectedPath;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryViewModelProvider.overrideWith(
              () => _FakeLibraryViewModel(sampleItems),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ja'),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      selectedPath = await showDialog<String>(
                        context: context,
                        builder: (_) => const FolderPickerDialog(
                          title: '移動先を選択',
                          currentParentPath: '', // ルートが現在地
                          movingItemPaths: {'Folder A'},
                        ),
                      );
                    },
                    child: const Text('Open'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // ルートをタップ（無効）
      await tester.tap(find.text('ルート'));
      await tester.pumpAndSettle();

      // まだダイアログが開いており、selectedPath は null
      expect(find.text('移動先を選択'), findsOneWidget);
      expect(selectedPath, isNull);
    });
  });
}

class _FakeLibraryViewModel extends LibraryViewModel {
  final List<MediaItem> _items;

  _FakeLibraryViewModel(this._items);

  @override
  Future<List<MediaItem>> build() async {
    return _items;
  }
}
