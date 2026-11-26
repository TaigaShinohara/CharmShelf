import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/settings/presentation/help_page.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

void main() {
  for (final locale in const [Locale('ja'), Locale('en')]) {
    testWidgets('問い合わせ案内が $locale のヘルプとポリシーに表示される', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ja'), Locale('en')],
          home: const HelpPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);

      final isJapanese = locale.languageCode == 'ja';
      final supportHeading = find.text(
        isJapanese ? '6. 困ったとき' : '6. If something goes wrong',
      );
      await tester.dragUntilVisible(
        supportHeading,
        find.byType(ListView),
        const Offset(0, -350),
      );
      await tester.pumpAndSettle();

      const supportLink = 'mailto:support-charmshelf@dobulab.com';
      final supportCard = tester.widget<MarkdownBody>(
        find.byWidgetPredicate(
          (widget) =>
              widget is MarkdownBody && widget.data.contains(supportLink),
        ),
      );
      final guardianNotice = isJapanese
          ? '保護者または法定代理人からご連絡ください'
          : 'ask your parent or legal guardian to contact us';
      final deletionNotice = isJapanese
          ? '対応完了から30日以内に削除'
          : 'within 30 days after the request is resolved';
      final beforeEmailLink = supportCard.data.split(supportLink).first;
      expect(beforeEmailLink, contains(guardianNotice));
      expect(beforeEmailLink, contains(deletionNotice));

      final policy = AppLocalizations.of(tester.element(find.byType(HelpPage)))!
          .privacyPolicyCurrentContent;
      expect(policy, contains(deletionNotice));
      expect(
        policy,
        contains(
          isJapanese
              ? '当該メールと添付を速やかに削除'
              : 'promptly delete the email and attachments',
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
