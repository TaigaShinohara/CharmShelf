import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/core/providers/package_info_provider.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/core/providers/shared_preferences_provider.dart';
import 'package:private_shelf/core/theme/app_theme.dart';
import 'package:private_shelf/features/home/presentation/home_page.dart';
import 'package:private_shelf/features/home/presentation/providers/favorite_collections_provider.dart';
import 'package:private_shelf/features/home/presentation/providers/home_library_items_provider.dart';
import 'package:private_shelf/features/home/presentation/providers/personal_library_state_provider.dart';
import 'package:private_shelf/features/home/presentation/providers/recently_viewed_collections_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/file_tree.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/presentation/dialogs/import_picker_guide_dialog.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/file_tree_thumbnail_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/import_flow_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/viewing_history_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/secret_mode_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_facet_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_view_model.dart';
import 'package:private_shelf/features/library/presentation/screens/import_selection_screen.dart';
import 'package:private_shelf/features/library/presentation/widgets/collection_action_sheet.dart';
import 'package:private_shelf/features/library/presentation/widgets/compact_tag_preview.dart';
import 'package:private_shelf/features/library/presentation/widgets/tag_form_sheet.dart';
import 'package:private_shelf/features/onboarding/presentation/onboarding_screen.dart';
import 'package:private_shelf/features/permission/data/repositories/permission_repository_impl.dart';
import 'package:private_shelf/features/permission/domain/repositories/permission_repository.dart';
import 'package:private_shelf/features/settings/presentation/settings_page.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/dialogs/modern_dialog.dart';
import 'package:private_shelf/shared/widgets/tag/app_tag.dart';
import 'package:private_shelf/shared/widgets/sheets/app_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

// フォントを同梱せず、任意のローカルフォントで実文字の目視確認画像を作成する。
// 未指定のCIでも、全ケースのレイアウトと操作到達性は検証する。
const _fontPath = String.fromEnvironment('UX_QA_FONT');
const _iconPath = String.fromEnvironment('UX_QA_ICON_FONT');
const _boundaryKey = ValueKey('ux-preview-boundary');

class _Facets extends TagFacetListViewModel {
  @override
  Stream<List<TagFacet>> build() => Stream.value([
    TagFacet()
      ..id = 1
      ..name = 'ジャンル'
      ..createdAt = DateTime(2026),
  ]);
}

class _Tags extends TagListViewModel {
  @override
  Stream<List<Tag>> build() => Stream.value([]);
}

class _Secret extends SecretMode {
  @override
  FutureOr<bool> build() => false;
}

class _Catalog extends CollectionNotifier {
  @override
  Future<MediaCollection?> build(String path) async => MediaCollection()
    ..path = path
    ..title = '週末の旅行アルバム'
    ..isCatalog = true
    ..createdAt = DateTime(2026, 8, 30)
    ..updatedAt = DateTime(2026, 8, 30);
}

class _Import extends ImportFlowNotifier {
  _Import(this.root);
  final FileTreeNode root;
  @override
  ImportFlowState build() =>
      ImportFlowState(status: ImportFlowStatus.confirming, rootNode: root);
  @override
  Future<void> restoreDraftSession() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  Future<void> capture(WidgetTester tester, String name) async {
    expect(tester.takeException(), isNull);
    if (_fontPath.isEmpty) return;
    // Asset decoding can outlive pumpAndSettle without scheduling a frame.
    // Wait for the exact providers used by mounted images before capturing.
    final imageElements = find.byType(Image).evaluate().toList();
    await tester.runAsync(() async {
      for (final element in imageElements) {
        final widget = element.widget as Image;
        await precacheImage(widget.image, element);
      }
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_boundaryKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory('build/ux_review');
        await directory.create(recursive: true);
        await File(
          '${directory.path}/$name.png',
        ).writeAsBytes(data!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  const variants = [
    (
      name: 'ja_normal',
      locale: Locale('ja'),
      size: Size(390, 844),
      scale: 1.0,
      dark: false,
    ),
    (
      name: 'ja_large',
      locale: Locale('ja'),
      size: Size(320, 568),
      scale: 2.0,
      dark: false,
    ),
    (
      name: 'en_large',
      locale: Locale('en'),
      size: Size(320, 568),
      scale: 2.0,
      dark: false,
    ),
    (
      name: 'ja_dark',
      locale: Locale('ja'),
      size: Size(390, 844),
      scale: 1.0,
      dark: true,
    ),
  ];
  for (final variant in variants) {
    for (final screen in [
      'onboarding',
      'home',
      'settings',
      'tag_form',
      'catalog',
      'import',
      'picker',
      'tags',
      'tags_library',
      'tags_actions',
    ]) {
      testWidgets('UX ${variant.name} $screen', (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = variant.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final nodes = List.generate(
          2,
          (i) => FileTreeNode(
            name: '旅行写真${i + 1}.jpg',
            uri: Uri.parse('content://ux-preview/$i'),
            relativePath: '旅行写真${i + 1}.jpg',
            isDirectory: false,
            size: 2048000,
          ),
        );
        final root = FileTreeNode(
          name: '旅行アルバム',
          uri: Uri.parse('content://ux-preview/folder'),
          relativePath: '',
          isDirectory: true,
          isCatalog: true,
          children: nodes,
        );
        final tags = ['旅行', '写真', 'お気に入り', '夏休み', '風景', '旅行の写真と動画をまとめた長い名前のタグ']
            .map(
              (name) => Tag()
                ..name = name
                ..facetId = 1,
            )
            .toList();
        final child = switch (screen) {
          'onboarding' => OnboardingScreen(
            onComplete: () {},
            onTrySample: () {},
          ),
          'home' => const HomePage(),
          'settings' => const SettingsPage(),
          'tag_form' => const Scaffold(
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: TagFormSheet(initialFacetId: 1),
              ),
            ),
          ),
          'catalog' => const Scaffold(
            body: SafeArea(
              child: AppBottomSheet(
                child: CollectionActionSheet(collectionPath: 'preview'),
              ),
            ),
          ),
          'import' => const ImportSelectionScreen(),
          'picker' => const Scaffold(
            body: ModernDialog(child: ImportPickerGuideDialog()),
          ),
          'tags_actions' => Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: AppTagWrap(
                  children: [
                    for (final tag in tags)
                      AppTag(
                        label: tag.name,
                        size: AppTagSize.large,
                        color: Colors.blue,
                        count: '12',
                        maxLines: null,
                        actionType: AppTagActionType.minus,
                        onAction: () {},
                      ),
                  ],
                ),
              ),
            ),
          ),
          'tags_library' => Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ライブラリ・一覧'),
                    CompactTagPreview(
                      tags: tags,
                      onTagTap: null,
                      compactRemainingCount: true,
                    ),
                    const SizedBox(height: 16),
                    const Text('ライブラリ・グリッド'),
                    SizedBox(
                      width: 160,
                      child: CompactTagPreview(
                        tags: tags,
                        onTagTap: null,
                        compactRemainingCount: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _ => Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CompactTagPreview(tags: tags, onTagTap: (_) {}),
              ),
            ),
          ),
        };
        var theme = variant.dark ? AppTheme.dark : AppTheme.light;
        if (_fontPath.isNotEmpty) {
          ButtonStyle withPreviewFont(ButtonStyle? style) =>
              (style ?? const ButtonStyle()).copyWith(
                textStyle: WidgetStateProperty.resolveWith(
                  (states) =>
                      (style?.textStyle?.resolve(states) ?? const TextStyle())
                          .copyWith(fontFamily: 'UxPreview'),
                ),
              );
          theme = theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: 'UxPreview'),
            primaryTextTheme: theme.primaryTextTheme.apply(
              fontFamily: 'UxPreview',
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: withPreviewFont(theme.filledButtonTheme.style),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: withPreviewFont(theme.outlinedButtonTheme.style),
            ),
            textButtonTheme: TextButtonThemeData(
              style: withPreviewFont(theme.textButtonTheme.style),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: withPreviewFont(theme.elevatedButtonTheme.style),
            ),
            listTileTheme: theme.listTileTheme.copyWith(
              titleTextStyle: theme.listTileTheme.titleTextStyle?.copyWith(
                fontFamily: 'UxPreview',
              ),
              subtitleTextStyle: theme.listTileTheme.subtitleTextStyle
                  ?.copyWith(fontFamily: 'UxPreview'),
            ),
            chipTheme: theme.chipTheme.copyWith(
              labelStyle: theme.chipTheme.labelStyle?.copyWith(
                fontFamily: 'UxPreview',
              ),
            ),
          );
        }
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hapticsEnabledProvider.overrideWith((ref) => false),
              sharedPreferencesProvider.overrideWith(
                (ref) async => SharedPreferences.getInstance(),
              ),
              appDocumentsPathSyncProvider.overrideWithValue('/tmp'),
              appVersionProvider.overrideWithValue('v1.0.12'),
              buildNumberProvider.overrideWithValue('103'),
              homeLibraryItemsProvider.overrideWith((ref) => Stream.value([])),
              personalLibraryStateProvider.overrideWith(
                (ref) => Stream.value(
                  const PersonalLibraryState(hasImported: false),
                ),
              ),
              recentlyOpenedFilesProvider.overrideWith(
                (ref) => Stream.value([]),
              ),
              recentlyViewedCollectionsProvider.overrideWith(
                (ref) => Stream.value([]),
              ),
              favoriteCollectionsProvider.overrideWith(
                (ref) => Stream.value([]),
              ),
              tagFacetListViewModelProvider.overrideWith(_Facets.new),
              tagListViewModelProvider.overrideWith(_Tags.new),
              secretModeProvider.overrideWith(_Secret.new),
              collectionNotifierProvider('preview').overrideWith(_Catalog.new),
              importFlowNotifierProvider.overrideWith(() => _Import(root)),
              for (final node in [root, ...nodes])
                fileTreeNodeThumbnailProvider(
                  node,
                ).overrideWith((ref) async => null),
              notificationPermissionStatusProvider.overrideWith(
                (ref) async => PermissionResult.denied,
              ),
            ],
            child: MaterialApp(
              theme: theme.copyWith(platform: TargetPlatform.android),
              locale: variant.locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: true,
                  textScaler: TextScaler.linear(variant.scale),
                ),
                child: RepaintBoundary(key: _boundaryKey, child: child!),
              ),
              home: child,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await capture(tester, '${variant.name}_$screen');
        final l10n = AppLocalizations.of(
          tester.element(find.byType(Scaffold).first),
        )!;
        if (screen == 'onboarding') {
          expect(
            find.byKey(const ValueKey('onboarding-next')).hitTestable(),
            findsOneWidget,
          );
        } else if (screen == 'settings') {
          // Storage tools now live on a separate page. Verify its current
          // navigation entry without triggering storage or recovery work.
          final storage = find.byKey(
            const ValueKey('settings-storage-navigation'),
          );
          await tester.scrollUntilVisible(storage, 200);
          await tester.pumpAndSettle();
          expect(storage.hitTestable(), findsOneWidget);
          await capture(tester, '${variant.name}_storage_entry');
        } else if (screen == 'tag_form') {
          // The form exposes name and facet directly; there is no advanced panel.
          await tester.enterText(find.byType(TextField), '旅行の思い出');
          final facet = find.widgetWithText(FilterChip, 'ジャンル');
          await tester.ensureVisible(facet);
          await tester.pumpAndSettle();
          final wasSelected = tester.widget<FilterChip>(facet).selected;
          await tester.tap(facet);
          await tester.pumpAndSettle();
          expect(tester.widget<FilterChip>(facet).selected, !wasSelected);
          final create = find.widgetWithText(FilledButton, l10n.tagCreate);
          await tester.ensureVisible(create);
          await tester.pumpAndSettle();
          expect(create.hitTestable(), findsOneWidget);
          await capture(tester, '${variant.name}_tag_form_details');
        } else if (screen == 'catalog') {
          final title = find.text(l10n.librarySectionProperties);
          await tester.ensureVisible(title);
          await tester.tap(title);
          await tester.pumpAndSettle();
          await capture(tester, '${variant.name}_catalog_details');
        } else if (screen == 'home') {
          final add = find.byKey(const ValueKey('home-add-files'));
          await tester.ensureVisible(add);
          await tester.pumpAndSettle();
          expect(add.hitTestable(), findsOneWidget);
        } else if (screen == 'import') {
          final selection = find.text(l10n.importAdvancedSettings);
          await tester.ensureVisible(selection);
          await tester.pumpAndSettle();
          expect(selection.hitTestable(), findsOneWidget);
          await capture(tester, '${variant.name}_import_summary');
          await tester.tap(selection);
          await tester.pumpAndSettle();
          await capture(tester, '${variant.name}_import_selection');
        } else if (screen == 'tags') {
          await tester.tap(find.byKey(const ValueKey('show-more-tags')));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text(tags.last.name));
          await tester.pumpAndSettle();
          await capture(tester, '${variant.name}_all_tags');
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
