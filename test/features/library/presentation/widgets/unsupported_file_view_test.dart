import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/widgets/unsupported_file_view.dart';
import '../../../../helpers/test_helpers.dart';

void main() {
  group('UnsupportedFileView ウィジェットテスト', () {
    testWidgets('非対応ファイルの情報（ファイル名・拡張子・ボタン）が描画される', (tester) async {
      final item = MediaItem()
        ..id = 1
        ..path = 'library/report.docx'
        ..originalPath = 'report.docx'
        ..size = 1024 * 50
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.file;

      await tester.pumpWidget(
        createProviderApp(
          Scaffold(body: UnsupportedFileView(item: item)),
          overrides: [
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('report.docx'), findsOneWidget);
      expect(find.text('DOCX'), findsOneWidget);
      expect(find.text('50.00 KB'), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
      expect(find.byIcon(Icons.share_rounded), findsOneWidget);
      expect(find.byIcon(Icons.description_rounded), findsOneWidget);
    });

    testWidgets('ZIPアーカイブのアイコンが正しく表示される', (tester) async {
      final item = MediaItem()
        ..id = 2
        ..path = 'library/archive.zip'
        ..originalPath = 'archive.zip'
        ..size = 1024 * 1024 * 2
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.file;

      await tester.pumpWidget(
        createProviderApp(
          Scaffold(body: UnsupportedFileView(item: item)),
          overrides: [
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('archive.zip'), findsOneWidget);
      expect(find.text('ZIP'), findsOneWidget);
      expect(find.text('2.00 MB'), findsOneWidget);
      expect(find.byIcon(Icons.folder_zip_rounded), findsOneWidget);
    });
  });
}
