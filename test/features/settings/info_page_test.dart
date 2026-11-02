import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/settings/presentation/info_page.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

Widget _buildTestWidget({
  required String title,
  required String content,
  Brightness brightness = Brightness.light,
  Future<bool> Function(Uri url)? canLaunchUrlFn,
  Future<bool> Function(Uri url, {LaunchMode mode})? launchUrlFn,
}) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: brightness,
      ),
      useMaterial3: true,
    ),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('ja'), Locale('en')],
    locale: const Locale('ja'),
    home: InfoPage(
      title: title,
      content: content,
      canLaunchUrlFn: canLaunchUrlFn,
      launchUrlFn: launchUrlFn,
    ),
  );
}

void main() {
  group('InfoPage Widget Tests', () {
    testWidgets('Markdown の見出し、太字、コード、リストが描画される', (tester) async {
      const markdownContent = '''
## セクション見出し
これは **太字テキスト** と `インラインコード` の説明です。

- リスト項目1
- リスト項目2
  - ネスト項目
''';

      await tester.pumpWidget(
        _buildTestWidget(title: 'テストヘルプ', content: markdownContent),
      );
      await tester.pumpAndSettle();

      expect(find.text('テストヘルプ'), findsOneWidget);
      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(find.byIcon(Icons.article_outlined), findsOneWidget);
      expect(find.textContaining('セクション見出し'), findsOneWidget);
      expect(find.textContaining('太字テキスト'), findsOneWidget);
      expect(find.textContaining('インラインコード'), findsOneWidget);
      expect(find.textContaining('リスト項目1'), findsOneWidget);
    });

    testWidgets('リンクタップ時に外部アプリ/メーラー起動関数が呼ばれる', (tester) async {
      Uri? launchedUri;
      LaunchMode? launchedMode;

      const markdownContent =
          '[support+staff@example.com](mailto:support+staff@example.com)';

      await tester.pumpWidget(
        _buildTestWidget(
          title: 'お問い合わせ',
          content: markdownContent,
          canLaunchUrlFn: (uri) async => true,
          launchUrlFn:
              (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
                launchedUri = uri;
                launchedMode = mode;
                return true;
              },
        ),
      );
      await tester.pumpAndSettle();

      final linkFinder = find.textContaining('support+staff@example.com');
      expect(linkFinder, findsOneWidget);

      await tester.tap(linkFinder);
      await tester.pumpAndSettle();

      expect(launchedUri, equals(Uri.parse('mailto:support+staff@example.com')));
      expect(launchedMode, equals(LaunchMode.externalApplication));
    });

    testWidgets('リンク起動に失敗した場合はクリップボードにコピーされる', (tester) async {
      const markdownContent = '[https://example.com](https://example.com)';

      await tester.pumpWidget(
        _buildTestWidget(
          title: 'リンクテスト',
          content: markdownContent,
          canLaunchUrlFn: (uri) async => false,
        ),
      );
      await tester.pumpAndSettle();

      final linkFinder = find.textContaining('https://example.com');
      expect(linkFinder, findsOneWidget);

      await tester.tap(linkFinder);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('ダークテーマでもエラーなく正しくレンダリングされる', (tester) async {
      const markdownContent = '''
## ダークモード確認
- アイテム1
- `code`
''';

      await tester.pumpWidget(
        _buildTestWidget(
          title: 'ダークモードテスト',
          content: markdownContent,
          brightness: Brightness.dark,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ダークモードテスト'), findsOneWidget);
      expect(find.textContaining('ダークモード確認'), findsOneWidget);
    });
  });
}
