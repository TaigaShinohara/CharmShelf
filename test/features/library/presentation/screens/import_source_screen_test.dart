import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:private_shelf/features/library/data/repositories/import_source_repository.dart';
import 'package:private_shelf/features/library/data/services/import_source_browser.dart';
import 'package:private_shelf/features/library/domain/models/import_source.dart';
import 'package:private_shelf/features/library/presentation/screens/import_source_screen.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/features/library/domain/models/file_tree.dart';
import 'package:private_shelf/features/library/presentation/providers/import_flow_provider.dart';
import 'package:private_shelf/features/library/presentation/screens/import_selection_screen.dart';

class _ImportFlow extends ImportFlowNotifier {
  @override
  ImportFlowState build() => ImportFlowState();

  @override
  Future<void> startSourceSelection(
    FileTreeNode selection, {
    String? targetParentPath,
  }) async {
    state = ImportFlowState(
      status: ImportFlowStatus.confirming,
      rootNode: selection,
      targetParentPath: targetParentPath,
    );
  }
}

class _Browser extends ImportSourceBrowser {
  Completer<List<ImportSourceEntry>>? pending;
  bool unavailable = false;
  bool cancelled = false;
  int reads = 0;
  ImportSourceEntry folder(int depth) => ImportSourceEntry(
    id: 'folder$depth',
    uri: Uri.parse('content://test/tree/root/document/$depth'),
    name: 'Folder $depth',
    isDirectory: true,
    path: List.generate(depth, (i) => 'Folder $i').join('/'),
  );
  @override
  Future<ImportSourceEntry> root(Uri tree) async => folder(0);
  @override
  Future<List<ImportSourceEntry>> children(
    ImportSource source,
    ImportSourceEntry directory,
  ) async {
    reads++;
    if (unavailable) throw StateError('Disconnected');
    if (pending != null) return pending!.future;
    return [folder(int.parse(directory.id.replaceFirst('folder', '')) + 1)];
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
  }

  @override
  Future<FileTreeNode> selection(
    ImportSource source,
    List<ImportSourceEntry> selected,
  ) async => FileTreeNode(
    name: 'sample.txt',
    uri: Uri.parse('content://test/sample.txt'),
    relativePath: 'sample.txt',
    isDirectory: false,
    isMedia: true,
    size: 5,
  );
}

void main() {
  Future<void> show(
    WidgetTester tester,
    _Browser browser, {
    String locale = 'ja',
    double scale = 1,
    bool selectForImport = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await ImportSourceRepository(prefs).save(
      ImportSource(
        id: 'root',
        name: 'Test source',
        treeUri: Uri.parse('content://test/tree/root'),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          importSourceBrowserProvider.overrideWithValue(browser),
          importFlowNotifierProvider.overrideWith(_ImportFlow.new),
        ],
        child: MaterialApp(
          locale: Locale(locale),
          supportedLocales: const [Locale('ja'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ImportSourceScreen(selectForImport: selectForImport),
                  ),
                ),
                child: const Text('Library'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Test source'));
    await tester.tap(find.text('Test source'));
    await tester.pumpAndSettle();
  }

  testWidgets('standalone source selection replaces browser with review', (
    tester,
  ) async {
    await show(tester, _Browser(), selectForImport: false);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(ImportSourceScreen));
    final l10n = AppLocalizations.of(context)!;
    await tester.tap(find.text(l10n.importSourceReview));
    await tester.pumpAndSettle();
    expect(find.byType(ImportSelectionScreen), findsOneWidget);
    expect(find.byType(ImportSourceScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Library'), findsOneWidget);
  });

  for (final systemBack in [false, true]) {
    testWidgets('ten levels close in one action, systemBack=$systemBack', (
      tester,
    ) async {
      final browser = _Browser();
      await show(tester, browser);
      for (var depth = 1; depth <= 10; depth++) {
        await tester.tap(find.byKey(ValueKey('folder$depth')));
        await tester.pumpAndSettle();
      }
      expect(browser.reads, 11);
      if (systemBack) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.byKey(const ValueKey('source-close')));
      }
      await tester.pumpAndSettle();
      expect(find.text('Library'), findsOneWidget);
      expect(find.byType(ImportSourceScreen), findsNothing);
      expect(browser.cancelled, isTrue);
    });
  }
  testWidgets('late directory response cannot reopen a closed selection', (
    tester,
  ) async {
    final browser = _Browser();
    await show(tester, browser);
    browser.pending = Completer();
    await tester.tap(find.byKey(const ValueKey('folder1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('source-close')));
    await tester.pumpAndSettle();
    browser.pending!.complete([browser.folder(2)]);
    await tester.pumpAndSettle();
    expect(find.text('Library'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final locale in ['ja', 'en']) {
    testWidgets('$locale narrow large text and provider error remain usable', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final browser = _Browser()..unavailable = true;
      await show(tester, browser, locale: locale, scale: 2);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('source-close')));
      await tester.pumpAndSettle();
      expect(find.text('Library'), findsOneWidget);
    });
  }
}
