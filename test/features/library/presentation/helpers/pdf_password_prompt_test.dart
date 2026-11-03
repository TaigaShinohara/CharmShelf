import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/presentation/helpers/pdf_password_prompt.dart';

import '../../../../helpers/test_helpers.dart';

Future<BuildContext> reader(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(
    createLocalizedApp(
      Builder(
        builder: (value) {
          context = value;
          return const Text('Reader');
        },
      ),
    ),
  );
  return context;
}

void main() {
  testWidgets('duplicate submit never closes the underlying reader route', (
    tester,
  ) async {
    final context = await reader(tester);
    final underlying = Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Open reader')),
      ),
    );
    await tester.pumpAndSettle();
    final request = PdfPasswordPrompt().request(context);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'synthetic');
    await tester.pump();
    final submit = tester
        .widget<TextButton>(find.widgetWithText(TextButton, '開く'))
        .onPressed!;
    submit();
    submit();
    await tester.pumpAndSettle();
    expect(await request, 'synthetic');
    expect(find.text('Open reader'), findsOneWidget);
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    await underlying;
    expect(tester.takeException(), isNull);
  });

  testWidgets('obscures input and preserves the exact submitted password', (
    tester,
  ) async {
    final context = await reader(tester);
    final prompt = PdfPasswordPrompt();
    final request = prompt.request(context);
    expect(identical(request, prompt.request(context)), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('PDFのパスワード'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isTrue);
    expect(field.enableSuggestions, isFalse);
    expect(field.autocorrect, isFalse);
    expect(field.enableIMEPersonalizedLearning, isFalse);
    expect(field.autofillHints, isNull);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '開く'))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), '  synthetic password  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(await request, '  synthetic password  ');
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Reader'), findsOneWidget);
  });

  testWidgets('the next engine request explains rejection and starts empty', (
    tester,
  ) async {
    final context = await reader(tester);
    final prompt = PdfPasswordPrompt();
    final first = prompt.request(context);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'wrong-synthetic');
    await tester.pump();
    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();
    expect(await first, 'wrong-synthetic');
    final second = prompt.request(context);
    await tester.pumpAndSettle();
    expect(find.text('パスワードが違います。もう一度入力してください。'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(await second, isNull);
  });

  testWidgets(
    'cancel before the deferred dialog prevents an obsolete request',
    (tester) async {
      final context = await reader(tester);
      final prompt = PdfPasswordPrompt();
      final request = prompt.request(context);
      prompt.cancel();
      await tester.pumpAndSettle();
      expect(await request, isNull);
      expect(await prompt.request(context), isNull);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('cancel during a reader rebuild closes only the password route', (
    tester,
  ) async {
    final context = await reader(tester);
    final prompt = PdfPasswordPrompt();
    final request = prompt.request(context);
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      createLocalizedApp(
        Builder(
          builder: (_) {
            prompt.cancel();
            return const Text('New document');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(await request, isNull);
    expect(find.text('New document'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancellation never pops a newer dialog', (tester) async {
    final context = await reader(tester);
    final prompt = PdfPasswordPrompt();
    final request = prompt.request(context);
    await tester.pumpAndSettle();
    final other = showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Other dialog'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    prompt.cancel();
    await tester.pumpAndSettle();
    expect(await request, isNull);
    expect(find.text('Other dialog'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await other;
    expect(find.text('Reader'), findsOneWidget);
  });

  testWidgets('a disposed reader cannot open a password dialog', (
    tester,
  ) async {
    final context = await reader(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(await PdfPasswordPrompt().request(context), isNull);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('English prompt fits a narrow view with large text and keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late BuildContext context;
    await tester.pumpWidget(
      createLocalizedApp(
        Builder(
          builder: (value) {
            context = value;
            return const Text('Reader');
          },
        ),
        locale: const Locale('en'),
      ),
    );
    // Apply accessibility/keyboard conditions to the entire Navigator overlay.
    final binding = tester.binding;
    binding.platformDispatcher.textScaleFactorTestValue = 2;
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    addTearDown(binding.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetViewInsets);
    final request = PdfPasswordPrompt().request(context);
    await tester.pumpAndSettle();
    expect(find.text('PDF password'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'synthetic');
    await tester.pump();
    await tester.ensureVisible(find.text('Open'));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(await request, 'synthetic');
    expect(tester.takeException(), isNull);
  });
}
