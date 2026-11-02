import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/features/library/presentation/widgets/dialogs/media_notes_editor_dialog.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/dialogs/confirm_dialog.dart';
import 'package:private_shelf/shared/widgets/dialogs/dialog_actions.dart';

const _inputKey = ValueKey('media-notes-input');
const _saveKey = ValueKey('media-notes-save');

Future<void> _pumpEditor(
  WidgetTester tester, {
  String? initialNotes,
  required Future<void> Function(String?) onSave,
  void Function(String?)? onClosed,
  String locale = 'en',
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [hapticsEnabledProvider.overrideWith((ref) => false)],
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final result = await showDialog<String>(
                  context: context,
                  builder: (context) => MediaNotesEditorDialog(
                    initialNotes: initialNotes,
                    onSave: onSave,
                  ),
                );
                onClosed?.call(result);
              },
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Edit'));
  await tester.pumpAndSettle();
}

String _inputText(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(_inputKey)).controller!.text;

void main() {
  testWidgets('save failure retains notes and retries before closing', (
    tester,
  ) async {
    final saved = <String?>[];
    String? result;
    await _pumpEditor(
      tester,
      initialNotes: 'old notes',
      onSave: (notes) async {
        saved.add(notes);
        if (saved.length == 1) throw StateError('private file path');
      },
      onClosed: (notes) => result = notes,
    );
    await tester.enterText(find.byKey(_inputKey), '  family morning  ');
    await tester.tap(find.byKey(_saveKey));
    await tester.pumpAndSettle();

    expect(find.byType(MediaNotesEditorDialog), findsOneWidget);
    expect(_inputText(tester), '  family morning  ');
    expect(
      find.byKey(const ValueKey('media-notes-save-error')),
      findsOneWidget,
    );
    expect(find.textContaining('private file path'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
    expect(result, isNull);

    await tester.tap(find.byKey(_saveKey));
    await tester.pumpAndSettle();
    expect(saved, ['family morning', 'family morning']);
    expect(find.byType(MediaNotesEditorDialog), findsNothing);
    expect(result, '  family morning  ');
  });

  testWidgets('pending save blocks duplicate requests and dismissal', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await _pumpEditor(
      tester,
      onSave: (notes) {
        calls++;
        return pending.future;
      },
    );
    await tester.enterText(find.byKey(_inputKey), 'keep this input');
    await tester.tap(find.byKey(_saveKey));
    await tester.pump();

    expect(calls, 1);
    expect(
      tester.widget<ElevatedButton>(find.byKey(_saveKey)).onPressed,
      isNull,
    );
    expect(tester.widget<TextField>(find.byKey(_inputKey)).enabled, isFalse);
    expect(find.text('Saving…'), findsOneWidget);
    await tester.tap(find.byKey(_saveKey));
    await tester.tapAt(const Offset(5, 5));
    await Navigator.of(
      tester.element(find.byType(MediaNotesEditorDialog)),
    ).maybePop();
    await tester.pump();
    expect(calls, 1);
    expect(find.byType(MediaNotesEditorDialog), findsOneWidget);
    expect(find.byType(ConfirmDialog), findsNothing);

    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(MediaNotesEditorDialog), findsNothing);
  });

  testWidgets('dirty back and outside tap preserve input unless discarded', (
    tester,
  ) async {
    var saves = 0;
    await _pumpEditor(tester, onSave: (notes) async => saves++);
    await tester.enterText(find.byKey(_inputKey), 'unfinished memo');
    await tester.pump();
    await Navigator.of(
      tester.element(find.byType(MediaNotesEditorDialog)),
    ).maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(ConfirmDialog), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(ConfirmDialog),
        matching: find.byType(DialogCloseButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(_inputText(tester), 'unfinished memo');

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(ConfirmDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(MediaNotesEditorDialog), findsNothing);
    expect(saves, 0);
  });

  testWidgets('unchanged cancel closes without a discard confirmation', (
    tester,
  ) async {
    await _pumpEditor(tester, onSave: (notes) async {});
    await tester.tap(find.byType(DialogCloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(MediaNotesEditorDialog), findsNothing);
    expect(find.byType(ConfirmDialog), findsNothing);
  });

  testWidgets('saving an empty memo clears it as null', (tester) async {
    final saved = <String?>[];
    await _pumpEditor(
      tester,
      initialNotes: 'remove me',
      onSave: (notes) async => saved.add(notes),
    );
    await tester.enterText(find.byKey(_inputKey), '   ');
    await tester.tap(find.byKey(_saveKey));
    await tester.pumpAndSettle();
    expect(saved, [null]);
    expect(find.byType(MediaNotesEditorDialog), findsNothing);
  });

  for (final locale in ['ja', 'en']) {
    testWidgets('failed $locale memo remains usable at 200% with keyboard', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await _pumpEditor(
        tester,
        locale: locale,
        textScale: 2,
        onSave: (notes) async => throw StateError('failed'),
      );
      await tester.enterText(find.byKey(_inputKey), 'my notes');
      await tester.ensureVisible(find.byKey(_saveKey));
      await tester.tap(find.byKey(_saveKey));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_inputText(tester), 'my notes');
      expect(
        find.byKey(const ValueKey('media-notes-save-error')),
        findsOneWidget,
      );
      expect(
        tester.widget<ElevatedButton>(find.byKey(_saveKey)).onPressed,
        isNotNull,
      );
    });
  }
}
