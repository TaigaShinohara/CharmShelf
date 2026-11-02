import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:private_shelf/core/config/app_config.dart';
import 'package:private_shelf/core/providers/package_info_provider.dart';
import 'package:private_shelf/core/providers/shared_preferences_provider.dart';
import 'package:private_shelf/core/services/license_service.dart';
import 'package:private_shelf/features/permission/data/repositories/permission_repository_impl.dart';
import 'package:private_shelf/features/permission/domain/repositories/permission_repository.dart';
import 'package:private_shelf/features/settings/presentation/settings_page.dart';
import 'package:private_shelf/features/settings/presentation/info_page.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

import '../../shared/finders.dart' as shared_find;

class _FakePermissionRepository implements PermissionRepository {
  @override
  Future<PermissionResult> getNotificationPermissionStatus() async =>
      PermissionResult.denied;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<PermissionResult> requestNotificationPermission() async =>
      PermissionResult.granted;

  @override
  Future<PermissionResult> requestStoragePermission() async =>
      PermissionResult.granted;

  @override
  Future<PermissionResult> getManageStoragePermissionStatus() async =>
      PermissionResult.granted;

  @override
  Future<PermissionResult> requestManageStoragePermission() async =>
      PermissionResult.granted;
}

class _RouteObserver extends NavigatorObserver {
  int pushes = 0;
  int pops = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pops++;
  }
}

void main() {
  group('LicenseService', () {
    test('registerCustomLicensesでAppConfig.appNameのライセンスが登録される', () async {
      LicenseService.registerCustomLicenses();

      final licenses = await LicenseRegistry.licenses.toList();
      final hasAppLicense = licenses.any(
        (entry) => entry.packages.contains(AppConfig.appName),
      );

      expect(hasAppLicense, isTrue);
    });
  });

  group('ライセンス画面と設定タイルの表示', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      // Widget tests exercise navigation; the complete real notice stream is
      // verified separately by license_service_test outside the fake clock.
      LicenseRegistry.reset();
      LicenseRegistry.addLicense(
        () => Stream<LicenseEntry>.value(
          const LicenseEntryWithLineBreaks(<String>[
            AppConfig.appName,
          ], 'MIT License'),
        ),
      );
    });

    Widget buildTestWidget({Locale locale = const Locale('ja')}) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWith(
            (ref) async => SharedPreferences.getInstance(),
          ),
          permissionRepositoryProvider.overrideWithValue(
            _FakePermissionRepository(),
          ),
          appVersionProvider.overrideWithValue('1.0.12'),
          buildNumberProvider.overrideWithValue('103'),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ja'), Locale('en')],
          home: const SettingsPage(),
        ),
      );
    }

    testWidgets('文書画面から戻るとタブ内の設定画面に戻る', (tester) async {
      final observer = _RouteObserver();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith(
              (ref) async => SharedPreferences.getInstance(),
            ),
            permissionRepositoryProvider.overrideWithValue(
              _FakePermissionRepository(),
            ),
            appVersionProvider.overrideWithValue('1.0.12'),
            buildNumberProvider.overrideWithValue('103'),
          ],
          child: MaterialApp(
            locale: const Locale('ja'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('ja'), Locale('en')],
            home: Navigator(
              observers: [observer],
              onGenerateRoute: (_) =>
                  MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final title in ['ライセンス', 'プライバシーポリシー', '利用規約']) {
        final tile = shared_find.findAppText(title);
        await tester.scrollUntilVisible(
          tile,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        await tester.tap(tile);
        await tester.pumpAndSettle();

        expect(observer.pushes, observer.pops + 2);
        if (title == 'ライセンス') {
          expect(find.byType(LicensePage), findsOneWidget);
        } else {
          expect(find.byType(InfoPage), findsOneWidget);
        }

        await tester.tap(find.byIcon(Icons.arrow_back).last);
        await tester.pumpAndSettle();
        expect(observer.pushes, observer.pops + 1);
        expect(find.byType(SettingsPage), findsOneWidget);
      }
    });

    testWidgets('日本語環境でライセンスタイルが表示され、タップするとLicensePageが開く', (tester) async {
      await tester.pumpWidget(buildTestWidget(locale: const Locale('ja')));
      await tester.pumpAndSettle();

      // ライセンスタイルの表示位置までスクロール
      final tileFinder = shared_find.findAppText('ライセンス');
      await tester.scrollUntilVisible(
        tileFinder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(tileFinder);
      await tester.pumpAndSettle();

      expect(shared_find.findAppText('ライセンス'), findsOneWidget);
      expect(shared_find.findAppText('オープンソースライセンス'), findsOneWidget);

      // セマンティクスラベルの検証
      expect(find.bySemanticsLabel('オープンソースライセンス一覧を開く'), findsOneWidget);

      // ライセンスタイルをタップ
      await tester.tap(tileFinder);
      await tester.pumpAndSettle();

      // LicensePage が開いていることを確認
      expect(find.byType(LicensePage), findsOneWidget);
      expect(find.text('CharmShelf'), findsWidgets);
      expect(find.text('1.0.12 (103)'), findsOneWidget);
      expect(
        find.text(
          '© 2026 Private Shelf Project. CharmShelf のコードには MIT ライセンスが適用されます。各ソフトウェアの条件は以下の一覧をご確認ください。',
        ),
        findsOneWidget,
      );
    });

    testWidgets('英語環境でライセンスタイルが表示され、タップするとLicensePageが開く', (tester) async {
      await tester.pumpWidget(buildTestWidget(locale: const Locale('en')));
      await tester.pumpAndSettle();

      // ライセンスタイルの表示位置までスクロール
      final tileFinder = shared_find.findAppText('Licenses');
      await tester.scrollUntilVisible(
        tileFinder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(tileFinder);
      await tester.pumpAndSettle();

      expect(shared_find.findAppText('Licenses'), findsOneWidget);
      expect(shared_find.findAppText('Open source licenses'), findsOneWidget);

      // セマンティクスラベルの検証
      expect(
        find.bySemanticsLabel('Open open source licenses'),
        findsOneWidget,
      );

      // ライセンスタイルをタップ
      await tester.tap(tileFinder);
      await tester.pumpAndSettle();

      // LicensePage が開いていることを確認
      expect(find.byType(LicensePage), findsOneWidget);
      expect(find.text('CharmShelf'), findsWidgets);
      expect(find.text('1.0.12 (103)'), findsOneWidget);
      expect(
        find.text(
          '© 2026 Private Shelf Project. CharmShelf code is licensed under MIT. See the list below for each software license.',
        ),
        findsOneWidget,
      );
    });
  });
}
