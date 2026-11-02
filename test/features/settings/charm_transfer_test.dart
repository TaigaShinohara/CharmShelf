import 'dart:async';
import 'package:private_shelf/core/feedback/snackbar_service.dart';
import '../../shared/finders.dart' as shared_find;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:private_shelf/core/providers/shared_preferences_provider.dart';
import 'package:private_shelf/features/library/data/services/tag_preset_service.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_export_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_preset_provider.dart';
import 'package:private_shelf/features/library/presentation/widgets/tag_import_sheet.dart';
import 'package:private_shelf/features/settings/presentation/settings_page.dart';
import 'package:private_shelf/features/settings/presentation/widgets/tiles/charm_transfer_tiles.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

class _ExportService extends Fake implements TagPresetService {
  int calls = 0;
  int? lastFacetId;
  Future<TagPresetExportResult?> Function() result = () async => null;

  @override
  Future<TagPresetExportResult?> exportPresetsToFile({
    int? facetId,
    String? dialogTitle,
  }) {
    calls++;
    lastFacetId = facetId;
    return result();
  }
}

class _Feedback extends Fake implements SnackBarService {
  final errors = <String>[];
  final successes = <String>[];
  @override
  void error({
    BuildContext? context,
    required String message,
    SnackBarAction? action,
    Duration? duration,
  }) => errors.add(message);
  @override
  void success({
    BuildContext? context,
    required String message,
    SnackBarAction? action,
    Duration? duration,
  }) => successes.add(message);
}

Future<void> _pump(
  WidgetTester tester,
  _ExportService service, {
  Widget? body,
  _Feedback? feedback,
  String locale = 'ja',
  double scale = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (feedback != null)
          snackBarServiceProvider.overrideWithValue(feedback),
        sharedPreferencesProvider.overrideWith(
          (ref) async => SharedPreferences.getInstance(),
        ),
        tagPresetServiceProvider.overrideWith((ref) async => service),
      ],
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: body ?? const SettingsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _showExport(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('settings-charm-export')),
    250,
  );
  await tester.ensureVisible(
    find.byKey(const ValueKey('settings-charm-export')),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final locale in ['ja', 'en']) {
    testWidgets('settings $locale at 200% exposes import and export', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = _ExportService();
      await _pump(tester, service, locale: locale, scale: 2);
      final importTile = find.byKey(const ValueKey('settings-charm-import'));
      await tester.scrollUntilVisible(importTile, 250);
      await tester.ensureVisible(importTile);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(importTile);
      await tester.pumpAndSettle();
      expect(find.byType(TagImportSheet), findsOneWidget);
      Navigator.of(tester.element(find.byType(TagImportSheet))).pop();
      await tester.pumpAndSettle();
      await _showExport(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('settings-charm-export')));
      await tester.pumpAndSettle();
      expect(service.calls, 1);
      expect(service.lastFacetId, isNull);
    });
  }

  testWidgets(
    'export prevents duplicate requests and permits retry after cancellation and error',
    (tester) async {
      final service = _ExportService();
      final feedback = _Feedback();
      final pending = Completer<TagPresetExportResult?>();
      service.result = () => pending.future;
      await _pump(
        tester,
        service,
        body: const Scaffold(body: CharmExportTile()),
        feedback: feedback,
      );
      final tile = find.byKey(const ValueKey('settings-charm-export'));
      await tester.tap(tile);
      await tester.pump();
      await tester.tap(tile);
      await tester.pump();
      expect(service.calls, 1);
      pending.complete(null);
      await tester.pumpAndSettle();
      expect(feedback.errors, isEmpty);
      expect(feedback.successes, isEmpty);
      service.result = () async => throw StateError('test failure');
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(service.calls, 2);
      expect(feedback.errors, hasLength(1));
      service.result = () async => const TagPresetExportResult(
        path: '/test/charms.json',
        facetCount: 2,
        tagCount: 3,
      );
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(service.calls, 3);
      expect(feedback.successes, ['分類2件・チャーム3件を書き出しました']);
    },
  );

  testWidgets('selected category scope and scope cancellation are preserved', (
    tester,
  ) async {
    final service = _ExportService();
    final facet = TagFacet()
      ..id = 42
      ..name = 'ジャンル';
    await _pump(
      tester,
      service,
      body: Scaffold(
        body: Consumer(
          builder: (context, ref, child) => TextButton(
            onPressed: () => ref
                .read(tagExportProvider.notifier)
                .export(context, selectedFacet: facet),
            child: const Text('export'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('export'));
    await tester.pumpAndSettle();
    await tester.tap(shared_find.findAppText('「ジャンル」のチャーム'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(service.lastFacetId, 42);
    await tester.tap(find.text('export'));
    await tester.pumpAndSettle();
    await tester.tap(shared_find.findAppText('すべてのチャーム'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(service.calls, 2);
    expect(service.lastFacetId, isNull);
    await tester.tap(find.text('export'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(shared_find.findAppText('すべてのチャーム'))).pop();
    await tester.pumpAndSettle();
    expect(service.calls, 2);
    await tester.tap(find.text('export'));
    await tester.pumpAndSettle();
    expect(shared_find.findAppText('すべてのチャーム'), findsOneWidget);
  });
}
