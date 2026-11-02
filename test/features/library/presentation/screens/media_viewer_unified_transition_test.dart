import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/viewer_source_context.dart';
import 'package:private_shelf/features/library/presentation/providers/viewer_pages_provider.dart';
import 'package:private_shelf/features/library/presentation/screens/media_viewer_screen.dart';
import 'package:private_shelf/features/settings/domain/models/app_mode.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

void main() {
  group('MediaViewerScreen & ViewerSourceContext 統一アーキテクチャテスト', () {
    test('ViewerSourceContextの各バリアントが正しく生成・比較できる', () {
      const recentContext = ViewerSourceContext.recent();
      const folderContext = ViewerSourceContext.folder(parentPath: 'folder1');
      const singleContext = ViewerSourceContext.single();
      final catalogItem = MediaItem()
        ..id = 2
        ..path = 'folder1/item.jpg'
        ..type = MediaType.file;
      final catalogContext = ViewerSourceContext.catalog(
        items: [catalogItem],
        parentPath: 'folder1',
        appMode: AppMode.internal,
      );

      expect(recentContext.kind, ViewerSourceKind.recent);
      expect(folderContext.kind, ViewerSourceKind.folder);
      expect(folderContext.parentPath, 'folder1');
      expect(singleContext.kind, ViewerSourceKind.single);
      expect(catalogContext.kind, ViewerSourceKind.catalog);
      expect(catalogContext.parentPath, 'folder1');
      expect(catalogContext.appMode, AppMode.internal);

      expect(recentContext, equals(const ViewerSourceContext.recent()));
      expect(recentContext, isNot(equals(folderContext)));
    });

    test('ViewerPagesParamがsourceContextを正しく保持する', () {
      final item = MediaItem()
        ..id = 1
        ..path = 'test.jpg'
        ..type = MediaType.file;

      final param = ViewerPagesParam([
        item,
      ], sourceContext: const ViewerSourceContext.recent());

      expect(param.items.length, 1);
      expect(param.sourceContext?.kind, ViewerSourceKind.recent);
    });

    testWidgets('MediaViewerScreenがinitialItemとPopScopeを正しく描画・保持する', (
      tester,
    ) async {
      final item = MediaItem()
        ..id = 100
        ..path = 'sample.txt'
        ..type = MediaType.file
        ..mimeType = 'text/plain'
        ..sourceType = MediaSourceType.localCopy;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDocumentsPathSyncProvider.overrideWithValue('/tmp')],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaViewerScreen(
              initialItem: item,
              sourceContext: const ViewerSourceContext.single(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // PopScope が配置されていることを確認
      expect(
        find.byWidgetPredicate((widget) => widget is PopScope),
        findsWidgets,
      );
      // MediaViewerScreen が正しく描画されていることを確認
      expect(find.byType(MediaViewerScreen), findsOneWidget);
    });
  });
}
