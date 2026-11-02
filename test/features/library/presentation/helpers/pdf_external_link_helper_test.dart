import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/presentation/helpers/pdf_external_link_helper.dart';

import '../../../../helpers/test_helpers.dart';

void main() {
  test('PDF links allow explicit web/mail/phone destinations only', () {
    for (final url in [
      'https://example.com/document',
      'http://example.com/document',
      'mailto:reader@example.com',
      'tel:+81123456789',
    ]) {
      expect(isAllowedPdfExternalLink(Uri.parse(url)), isTrue, reason: url);
    }
    for (final url in [
      'javascript:alert(1)',
      'file:///private/document.pdf',
      'data:text/html,content',
      'intent://example.com',
      '/relative/document',
      'https:/missing-host',
      'https://user:password@example.com',
      'mailto:',
      'tel:',
    ]) {
      expect(isAllowedPdfExternalLink(Uri.parse(url)), isFalse, reason: url);
    }
  });

  Future<BuildContext> buildContext(WidgetTester tester) async {
    late BuildContext linkContext;
    await tester.pumpWidget(
      createLocalizedApp(
        Builder(
          builder: (context) {
            linkContext = context;
            return const SizedBox();
          },
        ),
      ),
    );
    return linkContext;
  }

  testWidgets('unsafe PDF annotation never opens a dialog or external app', (
    tester,
  ) async {
    final context = await buildContext(tester);
    var launches = 0;
    final opened = await openPdfExternalLink(
      context,
      Uri.parse('file:///private/document.pdf'),
      launch: (_) async {
        launches++;
        return true;
      },
    );
    await tester.pump();
    expect(opened, isFalse);
    expect(launches, 0);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('mail link requires confirmation and cancel preserves privacy', (
    tester,
  ) async {
    final context = await buildContext(tester);
    var launches = 0;
    final opening = openPdfExternalLink(
      context,
      Uri.parse('mailto:reader@example.com'),
      launch: (_) async {
        launches++;
        return true;
      },
    );
    await tester.pumpAndSettle();
    expect(find.text('mailto:reader@example.com'), findsOneWidget);
    expect(launches, 0);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(await opening, isFalse);
    expect(launches, 0);
  });

  testWidgets('confirmed destination is launched once', (tester) async {
    final context = await buildContext(tester);
    final target = Uri.parse('https://example.com/document');
    final launched = <Uri>[];
    final opening = openPdfExternalLink(
      context,
      target,
      launch: (uri) async {
        launched.add(uri);
        return true;
      },
    );
    await tester.pumpAndSettle();
    expect(launched, isEmpty);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(await opening, isTrue);
    expect(launched, [target]);
  });

  testWidgets('launcher failure is reported without closing the reader', (
    tester,
  ) async {
    final context = await buildContext(tester);
    final opening = openPdfExternalLink(
      context,
      Uri.parse('tel:+81123456789'),
      launch: (_) async => false,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(await opening, isFalse);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(context.mounted, isTrue);
  });
}
