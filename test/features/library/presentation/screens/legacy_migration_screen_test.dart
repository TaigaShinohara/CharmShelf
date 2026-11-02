import 'package:private_shelf/features/device_files/data/device_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/features/library/data/services/legacy_migration_service.dart';
import 'package:private_shelf/features/library/presentation/providers/legacy_migration_provider.dart';
import 'package:private_shelf/features/library/presentation/screens/legacy_migration_screen.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

class _Migration extends Mock implements LegacyMigrationService {}

void main() {
  late _Migration service;
  late LegacyMigrationRecord record;
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          DeviceStorage.channel,
          (call) async => {'allowed': false, 'sdk': 35},
        );
    service = _Migration();
    when(() => service.finishCleanup()).thenAnswer((_) async {});
    record = LegacyMigrationRecord(
      id: '1',
      tree: Uri.parse(
        'content://com.android.externalstorage.documents/tree/primary%3ADocuments',
      ),
      entries: [
        LegacyEntry(
          path: 'library/photo.jpg',
          directory: false,
          size: 3,
          hash: 'a' * 64,
        ),
      ],
    );
    when(() => service.load()).thenAnswer((_) async => record);
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceStorage.channel, null),
  );
  Future<void> show(
    WidgetTester tester, {
    double scale = 1,
    Locale locale = const Locale('ja'),
    Brightness brightness = Brightness.light,
    VoidCallback? onCompleted,
    VoidCallback? onDeferred,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          legacyMigrationServiceProvider.overrideWith((ref) async => service),
        ],
        child: MaterialApp(
          locale: locale,
          theme: ThemeData(brightness: brightness),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: LegacyMigrationScreen(
            onCompleted: onCompleted ?? () {},
            onDeferred: onDeferred,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final locale in [const Locale('ja'), const Locale('en')]) {
    for (final brightness in Brightness.values) {
      for (final initial in [true, false]) {
        testWidgets('narrow large text $locale $brightness initial=$initial', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(360, 720);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          if (initial) when(() => service.load()).thenAnswer((_) async => null);
          await show(tester, scale: 2, locale: locale, brightness: brightness);
          expect(
            find.text(locale.languageCode == 'ja' ? 'おすすめ' : 'Recommended'),
            initial ? findsNothing : findsOneWidget,
          );
          await tester.ensureVisible(find.byType(FilledButton).last);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('defer leaves the confirmed inventory untouched', (tester) async {
    var deferred = 0;
    await show(tester, onDeferred: () => deferred++);
    await tester.ensureVisible(find.text('あとで決める'));
    await tester.tap(find.text('あとで決める'));
    await tester.pumpAndSettle();
    expect(deferred, 1);
    verifyNever(() => service.execute(restore: false));
    verifyNever(() => service.execute(restore: true));
    expect(record.phase, LegacyPhase.choice);
  });

  testWidgets('unfinished writes cannot be deferred or replaced', (
    tester,
  ) async {
    record.phase = LegacyPhase.restoring;
    await show(tester, onDeferred: () {});
    expect(find.text('あとで決める'), findsNothing);
    expect(find.text('引き継がずに削除する'), findsNothing);
    expect(find.text('確認し直す'), findsNothing);
    expect(find.text('再試行'), findsOneWidget);
  });

  testWidgets('unreadable record exposes retry without folder or skip', (
    tester,
  ) async {
    when(() => service.load()).thenThrow(const FormatException('broken'));
    await show(tester, onDeferred: () {});
    expect(find.text('あとで'), findsNothing);
    expect(find.text('フォルダを選ぶ'), findsNothing);
    expect(find.text('再試行'), findsOneWidget);
  });

  testWidgets('declining requires a warning; cancel does not delete', (
    tester,
  ) async {
    await show(tester);
    await tester.tap(find.text('引き継がずに削除する'));
    await tester.pumpAndSettle();
    expect(find.text('以前のデータを削除しますか？'), findsOneWidget);
    expect(find.textContaining('元に戻せません'), findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    verifyNever(() => service.execute(restore: false));
    expect(find.widgetWithText(FilledButton, '引き継ぐ'), findsOneWidget);
  });
  testWidgets(
    'only the final confirmation starts discard; completion permits continuation',
    (tester) async {
      var continued = 0;
      when(() => service.execute(restore: false)).thenAnswer((_) async {
        record.phase = LegacyPhase.complete;
        return record;
      });
      await show(tester, onCompleted: () => continued++);
      await tester.tap(find.text('引き継がずに削除する'));
      await tester.pumpAndSettle();
      expect(continued, 0);
      await tester.tap(find.text('削除する'));
      await tester.pumpAndSettle();
      verify(() => service.execute(restore: false)).called(1);
      await tester.tap(find.text('CharmShelfを始める'));
      await tester.pumpAndSettle();
      expect(continued, 1);
    },
  );
  testWidgets(
    'deletion failure exposes resume, never skip or a second restore',
    (tester) async {
      record.phase = LegacyPhase.deleting;
      when(
        () => service.execute(restore: false),
      ).thenThrow(StateError('failed'));
      await show(tester);
      expect(find.text('引き継ぐ'), findsNothing);
      expect(find.text('CharmShelfを始める'), findsNothing);
      await tester.tap(find.text('再試行'));
      await tester.pumpAndSettle();
      expect(find.textContaining('処理を完了できませんでした'), findsOneWidget);
      expect(find.text('CharmShelfを始める'), findsNothing);
    },
  );
  testWidgets('large text on a narrow screen remains scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await show(tester, scale: 2);
    await tester.ensureVisible(find.text('引き継がずに削除する'));
    await tester.tap(find.text('引き継がずに削除する'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('削除する'), findsOneWidget);
  });
  testWidgets(
    'folder picker receives a tree URI and cancellation makes no decision',
    (tester) async {
      when(() => service.load()).thenAnswer((_) async => null);
      const channel = MethodChannel(
        'io.alexrintt.plugins/sharedstorage/documentfile',
      );
      MethodCall? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            captured = call;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await show(tester);
      await tester.tap(find.text('フォルダを選ぶ'));
      await tester.pumpAndSettle();
      expect(captured!.method, 'openDocumentTree');
      expect(
        (captured!.arguments as Map)['initialUri'],
        'content://com.android.externalstorage.documents/tree/primary%3ADocuments',
      );
      verifyNever(() => service.execute(restore: false));
      expect(find.text('CharmShelfを始める'), findsNothing);
    },
  );
}
