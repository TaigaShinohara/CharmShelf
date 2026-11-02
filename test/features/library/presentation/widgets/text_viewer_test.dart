import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/widgets/text_viewer.dart';
import '../../../../helpers/test_helpers.dart';

void main() {
  group('TextViewer ウィジェットテスト', () {
    late Directory tempDir;
    late File normalFile;
    late File largeFile;
    late File oversizedFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('text_viewer_test');
      normalFile = File('${tempDir.path}/normal.txt');
      await normalFile.writeAsString('Hello, Flutter Text Viewer!');

      largeFile = File('${tempDir.path}/large.txt');
      // 2MB超のファイルを書き込む (2.1MB)
      final largeBytes = List<int>.filled(
        2 * 1024 * 1024 + 100 * 1024,
        65,
      ); // 'A'
      await largeFile.writeAsBytes(largeBytes);

      oversizedFile = File('${tempDir.path}/oversized.txt');
      final oversizedHandle = await oversizedFile.open(mode: FileMode.write);
      await oversizedHandle.truncate(17 * 1024 * 1024);
      await oversizedHandle.close();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    for (final source in [
      'https://example.invalid/pixel.png',
      'http://example.invalid/pixel.png',
      'file:///private/secret.png',
      '../../secret.png',
      'resource:assets/secret.png',
      'data:image/png;base64,aGVsbG8=',
    ]) {
      testWidgets('Markdown画像参照を読み込まず本文と代替テキストを保持: $source', (tester) async {
        final item = MediaItem()
          ..path = 'article.md'
          ..type = MediaType.file;
        await tester.runAsync(() async {
          await File('${tempDir.path}/article.md').writeAsString(
            '# 本文の見出し\n\n[![確認用の代替テキスト]($source)](https://example.invalid/)',
          );
          await tester.pumpWidget(
            createProviderApp(
              Scaffold(body: TextViewer(item: item)),
              overrides: [
                appDocumentsPathSyncProvider.overrideWith(
                  (ref) => tempDir.path,
                ),
              ],
            ),
          );
          for (var i = 0; i < 5; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            await tester.pump();
          }
        });
        expect(find.textContaining('確認用の代替テキスト'), findsOneWidget);
        expect(find.byType(Image, skipOffstage: false), findsNothing);
        expect(
          find.textContaining('本文の見出し', findRichText: true),
          findsOneWidget,
        );
        await tester.tap(find.textContaining('確認用の代替テキスト'));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }

    for (final path in ['normal.txt', 'missing.txt', 'oversized.txt']) {
      testWidgets('正常に描画した本文だけload完了を通知する: $path', (tester) async {
        var loaded = 0;
        final item = MediaItem()
          ..id = 20
          ..path = path;
        await tester.runAsync(() async {
          await tester.pumpWidget(
            createProviderApp(
              Scaffold(
                body: TextViewer(item: item, onContentReady: () => loaded++),
              ),
              overrides: [
                appDocumentsPathSyncProvider.overrideWith(
                  (ref) => tempDir.path,
                ),
              ],
            ),
          );
          for (var i = 0; i < 5; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            await tester.pump();
          }
        });
        expect(loaded, path == 'normal.txt' ? greaterThan(0) : 0);
      });
    }

    testWidgets('先読みで読み込めても非表示の本文はload完了を通知しない', (tester) async {
      var loaded = 0;
      final item = MediaItem()
        ..id = 21
        ..path = 'normal.txt';
      await tester.runAsync(() async {
        await tester.pumpWidget(
          createProviderApp(
            Scaffold(
              body: TextViewer(
                item: item,
                renderContent: false,
                onContentReady: () => loaded++,
              ),
            ),
            overrides: [
              appDocumentsPathSyncProvider.overrideWith((ref) => tempDir.path),
            ],
          ),
        );
        for (var i = 0; i < 5; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });
      expect(loaded, 0);
    });

    testWidgets('通常のテキストファイルが正常に描画される', (tester) async {
      final item = MediaItem()
        ..id = 10
        ..path = 'normal.txt'
        ..originalPath = normalFile.path
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.file;

      await tester.runAsync(() async {
        await tester.pumpWidget(
          createProviderApp(
            Scaffold(body: TextViewer(item: item)),
            overrides: [
              appDocumentsPathSyncProvider.overrideWith((ref) => tempDir.path),
            ],
          ),
        );
        for (var i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });

      expect(find.text('Hello, Flutter Text Viewer!'), findsOneWidget);
    });

    testWidgets('2MB超の巨大ファイルは警告表示となり「そのまま開く」で閲覧可能になる', (tester) async {
      final item = MediaItem()
        ..id = 11
        ..path = 'large.txt'
        ..originalPath = largeFile.path
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.file;

      await tester.runAsync(() async {
        await tester.pumpWidget(
          createProviderApp(
            Scaffold(body: TextViewer(item: item)),
            overrides: [
              appDocumentsPathSyncProvider.overrideWith((ref) => tempDir.path),
            ],
          ),
        );
        for (var i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });

      // 警告UIが表示される
      expect(find.text('ファイルサイズが大きすぎます'), findsOneWidget);
      expect(find.text('そのまま開く'), findsOneWidget);

      // 「そのまま開く」をタップ
      await tester.runAsync(() async {
        await tester.tap(find.text('そのまま開く'));
        for (var i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });

      // 警告UIが消える
      expect(find.text('ファイルサイズが大きすぎます'), findsNothing);
      expect(find.byKey(const Key('virtualized_text_view')), findsOneWidget);
    });

    testWidgets('16MB超のファイルはアプリ内で強制展開できない', (tester) async {
      final item = MediaItem()
        ..id = 12
        ..path = 'oversized.txt'
        ..originalPath = oversizedFile.path
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.file;

      await tester.runAsync(() async {
        await tester.pumpWidget(
          createProviderApp(
            Scaffold(body: TextViewer(item: item)),
            overrides: [
              appDocumentsPathSyncProvider.overrideWith((ref) => tempDir.path),
            ],
          ),
        );
        for (var i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });

      expect(find.text('ファイルサイズが大きすぎます'), findsOneWidget);
      expect(find.text('そのまま開く'), findsNothing);
    });
  });
}
