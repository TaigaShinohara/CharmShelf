import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/device_files/data/device_storage.dart';
import 'package:private_shelf/features/device_files/data/device_file_repository.dart';
import 'package:private_shelf/features/device_files/domain/device_file.dart';
import 'package:private_shelf/features/device_files/presentation/device_files_screen.dart';
import 'package:private_shelf/features/device_files/presentation/device_access_panel.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'dart:io';

class Browser extends DeviceStorage {
  bool permission = true;
  int requests = 0;
  bool cancelled = false;
  Completer<DeviceListing>? pending;
  DeviceFile folder(int n) => DeviceFile(
    uri: Uri.file('/v${List.generate(n, (i) => '/folder${i + 1}').join()}'),
    identity: '$n',
    name: 'Folder $n',
    directory: true,
  );
  @override
  Future<bool> allowed() async => permission;
  @override
  Future<void> requestPermission() async {
    requests++;
  }

  @override
  Future<List<DeviceFile>> roots() async => [folder(0)];
  @override
  Future<void> validate(List<DeviceFile> entries) async {}
  @override
  Future<DeviceListing> children(Uri uri) async => pending == null
      ? DeviceListing([folder(uri.pathSegments.length)])
      : pending!.future;
  @override
  Future<void> cancel() async {
    cancelled = true;
  }
}

void main() {
  testWidgets('initial granted panel does not trigger parent reload loops', (
    tester,
  ) async {
    final browser = Browser();
    var changes = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [deviceStorageProvider.overrideWithValue(browser)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DeviceAccessPanel(onChanged: () => changes++)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(changes, 0);
    expect(browser.requests, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    browser.permission = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(changes, 1);
    expect(browser.requests, 0);
  });

  Future<void> show(
    WidgetTester tester,
    Browser browser, {
    String locale = 'en',
    double scale = 1,
  }) async {
    final repository = DeviceFileRepository(File('/unused-test-index'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceStorageProvider.overrideWithValue(browser),
          deviceFileRepositoryProvider.overrideWith((ref) async => repository),
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
                        const DeviceFilesScreen(selectForImport: true),
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
  }

  for (final systemBack in [true, false]) {
    testWidgets('ten levels close in one action, Back=$systemBack', (
      tester,
    ) async {
      final browser = Browser();
      await show(tester, browser);
      for (var n = 0; n <= 10; n++) {
        await tester.tap(find.text('Folder $n'));
        await tester.pumpAndSettle();
      }
      if (systemBack) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.byTooltip('Close').first);
      }
      await tester.pumpAndSettle();
      expect(find.text('Library'), findsOneWidget);
      expect(find.byType(DeviceFilesScreen), findsNothing);
      expect(browser.cancelled, isTrue);
    });
  }
  testWidgets('a slow response after close cannot restore a route', (
    tester,
  ) async {
    final browser = Browser();
    await show(tester, browser);
    browser.pending = Completer<DeviceListing>();
    await tester.tap(find.text('Folder 0'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    browser.pending!.complete(const DeviceListing([]));
    await tester.pumpAndSettle();
    expect(find.byType(DeviceFilesScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final locale in ['ja', 'en']) {
    testWidgets(
      'permission explanation fits 320dp 200% in $locale without auto-request',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final browser = Browser()..permission = false;
        await show(tester, browser, locale: locale, scale: 2);
        expect(tester.takeException(), isNull);
        expect(browser.requests, 0);
      },
    );
    testWidgets('browser controls fit 320dp 200% in $locale', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(tester, Browser(), locale: locale, scale: 2);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'permission revocation removes listings and selections on resume',
    (tester) async {
      final browser = Browser();
      await show(tester, browser);
      expect(find.text('Folder 0'), findsOneWidget);
      browser.permission = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Folder 0'), findsNothing);
      expect(find.text('Allow access'), findsOneWidget);
    },
  );
}
