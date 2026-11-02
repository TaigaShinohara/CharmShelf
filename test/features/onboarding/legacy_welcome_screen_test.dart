import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/onboarding/presentation/legacy_welcome_screen.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

Widget welcome({
  String locale = 'ja',
  Brightness brightness = Brightness.light,
  double scale = 1,
  bool residual = false,
  required Future<void> Function(String) onChoice,
}) => MaterialApp(
  locale: Locale(locale),
  theme: ThemeData(brightness: brightness),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: LegacyWelcomeScreen(
    hasResidualData: () async => residual,
    onChoice: onChoice,
  ),
);

void main() {
  for (final locale in ['ja', 'en']) {
    for (final brightness in Brightness.values) {
      testWidgets('$locale $brightness two-stage start works at 200%', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final l = lookupAppLocalizations(Locale(locale));
        final choices = <String>[];
        await tester.pumpWidget(
          welcome(
            locale: locale,
            brightness: brightness,
            scale: 2,
            onChoice: (value) async => choices.add(value),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(l.legacyFirstUse), findsOneWidget);
        expect(find.text(l.legacyReturningEntry), findsOneWidget);
        expect(find.text(l.legacyTransferTitle), findsNothing);
        expect(find.text(l.legacyStartWithoutTransfer), findsNothing);
        await tester.ensureVisible(find.text(l.legacyReturningEntry));
        await tester.tap(find.text(l.legacyReturningEntry));
        await tester.pumpAndSettle();
        expect(choices, isEmpty);
        expect(find.text(l.legacyTransferTitle), findsOneWidget);
        expect(find.text(l.legacyStartWithoutTransfer), findsOneWidget);
        await tester.ensureVisible(find.text(l.legacyStartWithoutTransfer));
        await tester.tap(find.text(l.legacyStartWithoutTransfer));
        await tester.pumpAndSettle();
        expect(find.text(l.freshStartConfirmBody), findsOneWidget);
        expect(choices, isEmpty);
        await tester.ensureVisible(find.text(l.commonCancel));
        await tester.tap(find.text(l.commonCancel));
        await tester.pumpAndSettle();
        expect(choices, isEmpty);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text(l.legacyFirstUse), findsOneWidget);
        await tester.ensureVisible(find.text(l.legacyFirstUse));
        await tester.tap(find.text(l.legacyFirstUse));
        await tester.pumpAndSettle();
        expect(choices, ['first']);
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'existing residues require confirmation; cancel changes nothing',
    (tester) async {
      final choices = <String>[];
      await tester.pumpWidget(
        welcome(residual: true, onChoice: (value) async => choices.add(value)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('始める'));
      await tester.pumpAndSettle();
      expect(choices, isEmpty);
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      expect(choices, isEmpty);
      await tester.tap(find.text('始める'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('リセットして始める'));
      await tester.pumpAndSettle();
      expect(choices, ['first']);
    },
  );

  testWidgets('transfer is selected only on returning page', (tester) async {
    final choices = <String>[];
    await tester.pumpWidget(
      welcome(onChoice: (value) async => choices.add(value)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('以前使っていた方へ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('以前のデータを引き継ぐ'));
    await tester.pumpAndSettle();
    expect(choices, ['transfer']);
  });

  testWidgets('confirmed reset failure locks entry choices and retry resumes', (
    tester,
  ) async {
    var attempts = 0;
    final completion = Completer<void>();
    await tester.pumpWidget(
      welcome(
        onChoice: (choice) async {
          expect(choice, 'fresh');
          if (++attempts == 1) throw StateError('reset');
          await completion.future;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('以前使っていた方へ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('引き継がずに始める'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('リセットして始める'));
    await tester.pumpAndSettle();
    expect(find.textContaining('初期化を完了できませんでした'), findsOneWidget);
    expect(find.text('以前のデータを引き継ぐ'), findsNothing);
    expect(find.byType(BackButton), findsNothing);
    await tester.tap(find.text('再試行'));
    await tester.pump();
    expect(attempts, 2);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    completion.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('residue-check failure never starts reset', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LegacyWelcomeScreen(
          hasResidualData: () async => throw StateError('read'),
          onChoice: (_) async => calls++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('始める'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.textContaining('開始の準備を完了できませんでした'), findsOneWidget);
  });
}
