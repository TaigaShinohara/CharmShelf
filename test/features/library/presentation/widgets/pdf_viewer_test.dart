import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/widgets/pdf_viewer.dart';
import 'package:private_shelf/features/library/presentation/widgets/viewer_state_panel.dart';
import '../../../../helpers/test_helpers.dart';

void main() {
  group('PdfViewer ウィジェットテスト', () {
    testWidgets('ファイルが存在しない場合に ViewerStatePanel が表示される', (tester) async {
      final item = MediaItem()
        ..id = 20
        ..path = 'non_existent.pdf'
        ..originalPath = 'non_existent.pdf'
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.file;

      await tester.runAsync(() async {
        await tester.pumpWidget(
          createProviderApp(
            Scaffold(body: PdfViewer(item: item)),
            overrides: [
              appDocumentsPathSyncProvider.overrideWith(
                (ref) => '/non_existent_dir',
              ),
            ],
          ),
        );
        for (var i = 0; i < 5; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });

      expect(find.byType(ViewerStatePanel), findsOneWidget);
    });
  });
}
