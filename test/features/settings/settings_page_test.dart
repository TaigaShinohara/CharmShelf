import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:private_shelf/core/preferences/app_preferences.dart';
import 'package:private_shelf/core/providers/shared_preferences_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/data_restore_provider.dart';
import 'package:private_shelf/features/settings/presentation/settings_page.dart';
import 'package:private_shelf/features/settings/presentation/storage_settings_page.dart';
import 'package:private_shelf/features/settings/presentation/tutorial_list_page.dart';
import 'package:private_shelf/features/settings/presentation/widgets/sections/settings_storage_section.dart';
import 'package:private_shelf/features/settings/presentation/widgets/storage_clear_progress_dialog.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/features/permission/data/repositories/permission_repository_impl.dart';
import 'package:private_shelf/features/permission/domain/repositories/permission_repository.dart';
import 'package:private_shelf/features/settings/data/repositories/privacy_repository.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';
import '../../shared/finders.dart' as shared_find;

class AdvancedSettingsPage extends StatelessWidget {
  const AdvancedSettingsPage({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _FakePermissionRepository implements PermissionRepository {
  _FakePermissionRepository(this.status);

  PermissionResult status;
  int requestNotificationCalls = 0;
  int openSettingsCalls = 0;

  @override
  Future<PermissionResult> getNotificationPermissionStatus() async => status;

  @override
  Future<bool> openAppSettings() async {
    openSettingsCalls++;
    return true;
  }

  @override
  Future<PermissionResult> requestNotificationPermission() async {
    requestNotificationCalls++;
    status = PermissionResult.granted;
    return status;
  }

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

void main() {
  group('SettingsPage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('デフォルト設定で必要なセクションが表示される', (tester) async {
      final permissionRepository = _FakePermissionRepository(
        PermissionResult.denied,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith(
              (ref) async => SharedPreferences.getInstance(),
            ),
            permissionRepositoryProvider.overrideWithValue(
              permissionRepository,
            ),
            dataRestoreIsAndroidProvider.overrideWithValue(true),
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
            home: SettingsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('設定'), findsOneWidget);

      expect(shared_find.findAppText('外観'), findsOneWidget);
      expect(find.byIcon(Icons.palette_outlined), findsOneWidget);
      expect(shared_find.findAppText('ビューワー'), findsOneWidget);
      expect(shared_find.findAppText('ページ送り'), findsOneWidget);
      expect(shared_find.findAppText('操作と通知'), findsOneWidget);
      expect(shared_find.findAppText('システム設定'), findsOneWidget);
      expect(shared_find.findAppText('取り込み通知'), findsOneWidget);
      expect(shared_find.findAppText('未許可'), findsOneWidget);
      final storageNavigation = find.byKey(
        const ValueKey('settings-storage-navigation'),
      );
      await tester.scrollUntilVisible(storageNavigation, 300);
      await tester.ensureVisible(storageNavigation);
      await tester.pumpAndSettle();
      expect(storageNavigation, findsOneWidget);
      expect(shared_find.findAppText('データ管理'), findsOneWidget);
      expect(shared_find.findAppText('ストレージ管理'), findsOneWidget);
      expect(shared_find.findAppText('保存場所'), findsNothing);

      await tester.tap(storageNavigation);
      await tester.pumpAndSettle();

      expect(find.byType(StorageSettingsPage), findsOneWidget);
      expect(find.text('ストレージ'), findsWidgets);
      expect(shared_find.findAppText('保存場所'), findsOneWidget);
      expect(shared_find.findAppText('ライブラリを最適化'), findsOneWidget);
      expect(shared_find.findAppText('ファイルの変更を反映'), findsOneWidget);
      expect(shared_find.findAppText('以前のAndroid版から引っ越す'), findsNothing);
      expect(shared_find.findAppText('バックアップと復元'), findsNothing);
      expect(shared_find.findAppText('整理情報を守る'), findsNothing);
      expect(
        find.byKey(const ValueKey('settings-advanced-navigation')),
        findsNothing,
      );
      expect(shared_find.findAppText('アーカイブ'), findsNothing);
      expect(shared_find.findAppText('ごみ箱'), findsNothing);

      Navigator.of(tester.element(find.byType(StorageSettingsPage))).pop();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        shared_find.findAppText('外部の法務ページを開く'),
        300,
      );
      expect(shared_find.findAppText('外部の法務ページを開く'), findsOneWidget);

      expect(shared_find.findAppText('開発者オプション'), findsNothing);
      expect(shared_find.findAppText('詳細機能設定'), findsNothing);
      expect(shared_find.findAppText('フォルダ管理機能を有効化'), findsNothing);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(SettingsPage)),
      )!;
      expect(
        l10n.privacyPolicyCurrentContent,
        contains('開発者運営のサーバーへ自動アップロードすることはありません'),
      );
      expect(
        l10n.privacyPolicyCurrentContent,
        contains('自動クラウドバックアップおよび端末間転送の対象から除外'),
      );
      expect(
        l10n.privacyPolicyCurrentContent,
        contains('Androidの公開フォルダ、外部参照元、外部サービス側のデータは除外対象外'),
      );
      expect(
        l10n.privacyPolicyCurrentContent,
        isNot(contains('端末（ローカル）内でのみ処理・管理')),
      );
    });

    testWidgets('iOSの保存場所案内にAndroid文言と内部パス操作を表示しない', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.iOS),
            locale: const Locale('ja'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('ja'), Locale('en')],
            home: const Scaffold(
              body: SingleChildScrollView(
                child: SettingsStorageSection(isSyncing: false, onSync: _noop),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(shared_find.findAppText('保存場所'), 250);
      await tester.tap(shared_find.findAppText('保存場所'));
      await tester.pumpAndSettle();

      expect(find.textContaining('iPhone内のアプリ専用領域'), findsOneWidget);
      expect(find.textContaining('Documents/CharmShelf'), findsNothing);
      expect(find.text('パスをコピー'), findsNothing);
    });

    testWidgets('ストレージの分かりにくい操作はinfoボタンで用途を確認できる', (tester) async {
      var syncCalls = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dataRestoreIsAndroidProvider.overrideWithValue(true)],
          child: MaterialApp(
            locale: const Locale('ja'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('ja'), Locale('en')],
            home: Center(
              child: SizedBox(
                width: 427,
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: SettingsStorageSection(
                      isSyncing: false,
                      onSync: () => syncCalls++,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final optimizeButton = find.byKey(
        const ValueKey('storage-optimize-button'),
      );
      expect(optimizeButton, findsOneWidget);
      expect(tester.widget(optimizeButton), isA<IconButton>());
      expect(
        tester.getSize(shared_find.findAppText('ライブラリを最適化')).width,
        greaterThan(140),
      );
      expect(
        find.descendant(
          of: find.ancestor(
            of: shared_find.findAppText('ライブラリを最適化'),
            matching: find.byType(ListTile),
          ),
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsNothing,
      );

      await tester.tap(optimizeButton);
      await tester.pump();
      expect(syncCalls, 1);

      final infoButtons = find.byIcon(Icons.info_outline);
      expect(infoButtons, findsOneWidget);

      await tester.tap(infoButtons.first);
      await tester.pumpAndSettle();

      expect(find.textContaining('アプリ内に取り込んだファイルをもう一度確認'), findsOneWidget);
      expect(syncCalls, 1);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
    });

    testWidgets('テーマ設定は循環ではなく選択ダイアログで変更できる', (tester) async {
      final permissionRepository = _FakePermissionRepository(
        PermissionResult.denied,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith(
              (ref) async => SharedPreferences.getInstance(),
            ),
            permissionRepositoryProvider.overrideWithValue(
              permissionRepository,
            ),
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
            home: SettingsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(
        find
            .ancestor(
              of: shared_find.findAppText('テーマ'),
              matching: find.byType(ListTile),
            )
            .first,
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('システム設定に合わせる'), findsWidgets);
      expect(find.text('ライトモード固定'), findsWidgets);
      expect(find.text('ダークモード固定'), findsWidgets);

      await tester.tap(find.text('ライトモード固定').last);
      await tester.pumpAndSettle();

      expect(shared_find.findAppText('ライト'), findsOneWidget);
    });

    testWidgets('テーマ設定ダイアログは選択肢をセマンティクスで説明する', (tester) async {
      final semantics = tester.ensureSemantics();

      final permissionRepository = _FakePermissionRepository(
        PermissionResult.denied,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith(
              (ref) async => SharedPreferences.getInstance(),
            ),
            permissionRepositoryProvider.overrideWithValue(
              permissionRepository,
            ),
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
            home: SettingsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(
        find
            .ancestor(
              of: shared_find.findAppText('テーマ'),
              matching: find.byType(ListTile),
            )
            .first,
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('システム設定に合わせる'), findsOneWidget);
      expect(find.bySemanticsLabel('ライトモード固定'), findsOneWidget);
      expect(find.bySemanticsLabel('ダークモード固定'), findsOneWidget);

      semantics.dispose();
    });

    testWidgets('外部法務ページを開けない場合はURLをクリップボードへ退避する', (tester) async {
      final permissionRepository = _FakePermissionRepository(
        PermissionResult.denied,
      );
      var fallbackCalled = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith(
              (ref) async => SharedPreferences.getInstance(),
            ),
            permissionRepositoryProvider.overrideWithValue(
              permissionRepository,
            ),
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
            home: SettingsPage(
              canLaunchExternalUrl: (_) async => false,
              copyExternalLegalUrl: (messenger, l10n, url) async {
                fallbackCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        shared_find.findAppText('外部の法務ページを開く'),
        300,
      );
      await tester.ensureVisible(shared_find.findAppText('外部の法務ページを開く'));
      await tester.pumpAndSettle();
      await tester.tap(shared_find.findAppText('外部の法務ページを開く'));
      await tester.pumpAndSettle();

      expect(fallbackCalled, isTrue);
    });

    testWidgets('外部法務ページを開ける場合は外部アプリへ遷移する', (tester) async {
      final permissionRepository = _FakePermissionRepository(
        PermissionResult.denied,
      );
      var launchCalled = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith(
              (ref) async => SharedPreferences.getInstance(),
            ),
            permissionRepositoryProvider.overrideWithValue(
              permissionRepository,
            ),
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
            home: SettingsPage(
              canLaunchExternalUrl: (_) async => true,
              launchExternalUrl: (uri) async {
                launchCalled = true;
                return true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        shared_find.findAppText('外部の法務ページを開く'),
        300,
      );
      await tester.ensureVisible(shared_find.findAppText('外部の法務ページを開く'));
      await tester.pumpAndSettle();
      await tester.tap(shared_find.findAppText('外部の法務ページを開く'));
      await tester.pumpAndSettle();

      expect(launchCalled, isTrue);
    });

    testWidgets('恒久拒否時は説明後にOS設定を開く', (tester) async {
      final permissionRepository = _FakePermissionRepository(
        PermissionResult.permanentlyDenied,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith(
              (ref) async => SharedPreferences.getInstance(),
            ),
            permissionRepositoryProvider.overrideWithValue(
              permissionRepository,
            ),
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
            home: SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(shared_find.findAppText('取り込み通知'));
      await tester.pumpAndSettle();
      expect(find.textContaining('広告・不要な通知は送りません。通知は任意です。'), findsOneWidget);

      await tester.tap(find.text('端末の設定を開く'));
      await tester.pumpAndSettle();

      expect(permissionRepository.openSettingsCalls, 1);
      expect(permissionRepository.requestNotificationCalls, 0);
    });

    testWidgets('未許可時は説明への同意後だけ通知権限を要求する', (tester) async {
      final permissionRepository = _FakePermissionRepository(
        PermissionResult.denied,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith(
              (ref) async => SharedPreferences.getInstance(),
            ),
            permissionRepositoryProvider.overrideWithValue(
              permissionRepository,
            ),
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
            home: SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(permissionRepository.requestNotificationCalls, 0);
      final importNotificationFinder = shared_find.findAppText('取り込み通知');
      await tester.scrollUntilVisible(importNotificationFinder, 300);
      await tester.tap(importNotificationFinder);
      await tester.pumpAndSettle();
      expect(permissionRepository.requestNotificationCalls, 0);

      await tester.tap(find.text('通知を許可する'));
      await tester.pumpAndSettle();

      expect(permissionRepository.requestNotificationCalls, 1);
      expect(permissionRepository.openSettingsCalls, 0);
      expect(shared_find.findAppText('取り込み通知を許可しました'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('チュートリアル一覧へ移動し、一覧内でリセットできる', (tester) async {
      final permissionRepository = _FakePermissionRepository(
        PermissionResult.denied,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('tutorial.library.completed', true);
      await prefs.setBool(AppPreferences.onboardingCompletedKey, true);
      await prefs.setBool(AppPreferences.importPickerGuideDismissedKey, true);
      await prefs.setBool('feature_tooltip.example.shown', true);
      await prefs.setBool('unrelated.preference', true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith((ref) async => prefs),
            permissionRepositoryProvider.overrideWithValue(
              permissionRepository,
            ),
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
            home: SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SettingsPage));
      final l10n = AppLocalizations.of(context)!;
      final targetFinder = shared_find.findAppText(l10n.settingsTutorialView);
      await tester.scrollUntilVisible(targetFinder, 500);
      await tester.ensureVisible(targetFinder);
      await tester.pumpAndSettle();
      await tester.tap(targetFinder);
      await tester.pumpAndSettle();

      expect(find.byType(TutorialListPage), findsOneWidget);
      expect(
        shared_find.findAppText(l10n.settingsTutorialListDescription),
        findsOneWidget,
      );
      expect(
        shared_find.findAppText(l10n.tutorialOnboardingTitle),
        findsOneWidget,
      );
      expect(
        shared_find.findAppText(l10n.tutorialLibraryTitle),
        findsOneWidget,
      );

      final importGuideFinder = shared_find.findAppText(
        l10n.tutorialImportPickerTitle,
      );
      await tester.scrollUntilVisible(importGuideFinder, 300);
      expect(importGuideFinder, findsOneWidget);

      final welcomeGuideFinder = shared_find.findAppText(
        l10n.tutorialWelcomeGuideTitle,
      );
      await tester.scrollUntilVisible(welcomeGuideFinder, 300);
      expect(welcomeGuideFinder, findsOneWidget);

      final resetFinder = shared_find.findAppText(l10n.settingsTutorialReset);
      await tester.scrollUntilVisible(resetFinder, 300);
      await tester.ensureVisible(resetFinder);
      await tester.tap(resetFinder);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(l10n.settingsTutorialResetConfirmTitle), findsOneWidget);
      expect(
        find.text(l10n.settingsTutorialResetConfirmMessage),
        findsOneWidget,
      );

      await tester.tap(find.text(l10n.commonExecute));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(prefs.getBool('tutorial.library.completed'), isNull);
      expect(prefs.getBool(AppPreferences.onboardingCompletedKey), isNull);
      expect(
        prefs.getBool(AppPreferences.importPickerGuideDismissedKey),
        isNull,
      );
      expect(prefs.getBool('feature_tooltip.example.shown'), isNull);
      expect(prefs.getBool('unrelated.preference'), isTrue);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('ストレージを空にするを押すと影響確認と取消可能なカウントダウンが表示される', (tester) async {
      final permissionRepository = _FakePermissionRepository(
        PermissionResult.granted,
      );
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith((ref) async => prefs),
            permissionRepositoryProvider.overrideWithValue(
              permissionRepository,
            ),
            privacyRepositoryProvider.overrideWithValue(
              PrivacyRepository(prefs),
            ),
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
            home: StorageSettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final clearTileFinder = shared_find.findAppText('ストレージを空にする');
      await tester.scrollUntilVisible(clearTileFinder, 300);
      await tester.ensureVisible(clearTileFinder);
      await tester.pumpAndSettle();
      await tester.tap(clearTileFinder);
      await tester.pumpAndSettle();

      // 影響範囲をページごとに確認する
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('ストレージを空にしますか？'), findsOneWidget);
      expect(find.text('アプリ内ファイルの削除'), findsOneWidget);
      expect(find.text('登録データの消去'), findsNothing);
      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();
      expect(find.text('登録データの消去'), findsOneWidget);
      expect(find.textContaining('消去したアプリ内データは元に戻せません'), findsOneWidget);
      expect(find.text('消去する'), findsOneWidget);
      expect(find.text('キャンセル'), findsNothing);

      // 最終確認へ進む
      await tester.tap(find.text('消去する'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('本当にストレージを空にしますか？'), findsOneWidget);
      expect(find.text('消去へ進む'), findsOneWidget);

      // 追加した最終確認で取り消せば、カウントダウンは開始しない
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pumpAndSettle();
      expect(find.byType(StorageClearProgressDialog), findsNothing);

      // 再度開いて、最終確認まで同じ導線で進む
      await tester.tap(clearTileFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('消去する'));
      await tester.pump(const Duration(milliseconds: 300));

      // カウントダウンへ進む
      await tester.tap(find.text('消去へ進む'));
      await tester.pump(const Duration(milliseconds: 300));

      // カウントダウンダイアログが表示される
      expect(find.byType(StorageClearProgressDialog), findsOneWidget);
      expect(find.text('ストレージ消去の準備中'), findsOneWidget);
      expect(find.text('今すぐ中断する'), findsOneWidget);

      // カウントダウン中に中断
      await tester.tap(find.text('今すぐ中断する'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('英語表示でも主要セクションと外部法務導線を維持する', (tester) async {
      final permissionRepository = _FakePermissionRepository(
        PermissionResult.denied,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith(
              (ref) async => SharedPreferences.getInstance(),
            ),
            permissionRepositoryProvider.overrideWithValue(
              permissionRepository,
            ),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [Locale('ja'), Locale('en')],
            home: SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Appearance'), findsWidgets);
      expect(find.text('Controls and Notifications'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('Open external legal page'),
        300,
      );
      expect(find.text('Open external legal page'), findsOneWidget);
    });

    testWidgets('診断情報をコピーを押すと診断データが生成されてクリップボードにコピーされ成功SnackBarが表示される', (
      tester,
    ) async {
      final permissionRepository = _FakePermissionRepository(
        PermissionResult.granted,
      );
      String? copiedText;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith(
              (ref) async => SharedPreferences.getInstance(),
            ),
            permissionRepositoryProvider.overrideWithValue(
              permissionRepository,
            ),
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
            home: SettingsPage(
              copyDiagnosticsToClipboard: (text) async {
                copiedText = text;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final copyFinder = shared_find.findAppText('診断情報をコピー');
      await tester.scrollUntilVisible(copyFinder, 500);
      await tester.ensureVisible(copyFinder);
      await tester.pumpAndSettle();
      await tester.tap(copyFinder);
      await tester.pumpAndSettle();

      expect(copiedText, isNotNull);
      expect(copiedText, contains('=== System Diagnostics ==='));
      expect(copiedText, contains('Platform: '));
      expect(copiedText, contains('Notification Permission: granted'));
      expect(shared_find.findAppText('診断情報をコピーしました'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('診断情報のクリップボードコピー失敗時にエラーSnackBarが表示される', (tester) async {
      final permissionRepository = _FakePermissionRepository(
        PermissionResult.granted,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith(
              (ref) async => SharedPreferences.getInstance(),
            ),
            permissionRepositoryProvider.overrideWithValue(
              permissionRepository,
            ),
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
            home: SettingsPage(
              copyDiagnosticsToClipboard: (text) async {
                throw Exception('Clipboard error');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final copyFinder = shared_find.findAppText('診断情報をコピー');
      await tester.scrollUntilVisible(copyFinder, 500);
      await tester.ensureVisible(copyFinder);
      await tester.pumpAndSettle();
      await tester.tap(copyFinder);
      await tester.pumpAndSettle();

      expect(shared_find.findAppText('診断情報のコピーに失敗しました'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });
  });
}

void _noop() {}
