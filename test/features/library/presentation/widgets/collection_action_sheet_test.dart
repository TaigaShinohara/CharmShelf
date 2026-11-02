import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/secret_mode_provider.dart';
import 'package:private_shelf/features/library/presentation/widgets/collection_action_sheet.dart';
import 'package:private_shelf/features/library/presentation/widgets/dialogs/media_notes_editor_dialog.dart';
import 'package:private_shelf/features/settings/domain/models/privacy_settings.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Collection extends CollectionNotifier {
  @override
  Future<MediaCollection?> build(String path) async => null;
}

class _Secret extends SecretMode {
  @override
  FutureOr<bool> build() => false;
}

class _Privacy extends PrivacySettingsNotifier {
  @override
  Future<PrivacySettings> build() async => const PrivacySettings();
}

class _NotesCollection extends CollectionNotifier {
  final collection = MediaCollection()
    ..path = 'folder'
    ..title = 'My collection'
    ..isCatalog = true
    ..notes = 'original memo';
  int saves = 0;

  @override
  Future<MediaCollection?> build(String path) async => collection;

  @override
  Future<void> updateNotes(String? notes) async {
    saves++;
    if (saves == 1) throw StateError('storage failed');
    collection.notes = notes;
    state = AsyncData(collection);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('未カタログのメニューは狭い幅と文字拡大でも文言を収める', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hapticsEnabledProvider.overrideWith((ref) => false),
          appDocumentsPathSyncProvider.overrideWithValue('/tmp'),
          collectionNotifierProvider('folder').overrideWith(_Collection.new),
          secretModeProvider.overrideWith(_Secret.new),
        ],
        child: const MaterialApp(
          locale: Locale('ja'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('ja'), Locale('en')],
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Center(
                child: SizedBox(
                  width: 240,
                  child: SingleChildScrollView(
                    child: CollectionActionSheet(collectionPath: 'folder'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const ValueKey('catalogify-button'));
    expect(button, findsOneWidget);
    final l10n = AppLocalizations.of(tester.element(button))!;
    final label = find.descendant(
      of: button,
      matching: find.text(l10n.settingsCollectionCatalogify),
    );
    expect(label, findsOneWidget);
    expect(tester.getSize(button).height, lessThanOrEqualTo(44));
    expect(
      tester.getRect(button).contains(tester.getRect(label).topLeft),
      isTrue,
    );
    expect(
      tester.getRect(button).contains(tester.getRect(label).bottomRight),
      isTrue,
    );
    final hintBox = find.byKey(const ValueKey('catalogify-hint'));
    expect(hintBox, findsOneWidget);
    final hint = tester.widget<Text>(hintBox);
    expect(hint.data, l10n.settingsCollectionCatalogifyHint);
    expect(hint.softWrap, isTrue);
    expect(hint.maxLines, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('実際のメモ操作は保存失敗後も入力を保持し再試行で一覧へ反映する', (tester) async {
    final notifier = _NotesCollection();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hapticsEnabledProvider.overrideWith((ref) => false),
          appDocumentsPathSyncProvider.overrideWithValue('/tmp'),
          collectionNotifierProvider('folder').overrideWith(() => notifier),
          parentCatalogProvider(
            parentPath: '.',
          ).overrideWith((ref) async => null),
          privacySettingsNotifierProvider.overrideWith(_Privacy.new),
          secretModeProvider.overrideWith(_Secret.new),
        ],
        child: const MaterialApp(
          locale: Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: CollectionActionSheet(collectionPath: 'folder'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('catalog-details')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('original memo'));
    await tester.tap(find.text('original memo'));
    await tester.pumpAndSettle();
    expect(find.byType(MediaNotesEditorDialog), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('media-notes-input')),
      'changed memo',
    );
    await tester.tap(find.byKey(const ValueKey('media-notes-save')));
    await tester.pumpAndSettle();
    expect(notifier.saves, 1);
    expect(find.byType(MediaNotesEditorDialog), findsOneWidget);
    expect(notifier.collection.notes, 'original memo');

    await tester.tap(find.byKey(const ValueKey('media-notes-save')));
    await tester.pumpAndSettle();
    expect(notifier.saves, 2);
    expect(find.byType(MediaNotesEditorDialog), findsNothing);
    expect(find.text('changed memo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
