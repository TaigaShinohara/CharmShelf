import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:private_shelf/core/providers/shared_preferences_provider.dart';
import 'package:private_shelf/core/providers/tab_navigation_provider.dart';
import 'package:private_shelf/core/providers/unsaved_data_provider.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/features/home/presentation/providers/personal_library_state_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/viewing_history_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:private_shelf/features/settings/presentation/settings_page.dart';
import 'package:private_shelf/features/tab_navigation/presentation/main_tab_page.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/navigation/bottom_navigation_style.dart';
import 'package:private_shelf/shared/widgets/navigation/liquid_glass_navigation.dart';

import '../../shared/finders.dart' as shared_find;

void main() {
  group('MainTabPage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'tutorial.library.completed': true,
        'tutorial.home.completed': true,
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall methodCall) async {
              if (methodCall.method == 'getApplicationDocumentsDirectory') {
                return '/tmp';
              }
              return null;
            },
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
    });

    testWidgets('タブ切り替えでライブラリ⇄ホームが表示される', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith(
              (ref) async => SharedPreferences.getInstance(),
            ),
            hapticsEnabledProvider.overrideWith((ref) => false),
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
            personalLibraryStateProvider.overrideWith(
              (ref) =>
                  Stream.value(const PersonalLibraryState(hasImported: false)),
            ),
            recentlyOpenedFilesProvider.overrideWith((ref) => Stream.value([])),
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
            home: MainTabPage(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      // 初期はライブラリ
      // AppBarタイトルとタブラベルの両方に出るため、複数でもOK
      expect(find.text('ライブラリ'), findsWidgets);
      // 設定の入口はホームに集約されている。
      expect(find.byTooltip('設定'), findsNothing);
      // ホームへ切り替え
      await tester.tap(find.text('ホーム'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('ホーム'), findsWidgets);
      expect(find.byTooltip('設定'), findsOneWidget);
    });

    testWidgets('初回追加要求を受けるとライブラリで追加メニューを表示する', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith(
              (ref) async => SharedPreferences.getInstance(),
            ),
            hapticsEnabledProvider.overrideWith((ref) => false),
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
            personalLibraryStateProvider.overrideWith(
              (ref) =>
                  Stream.value(const PersonalLibraryState(hasImported: false)),
            ),
            recentlyOpenedFilesProvider.overrideWith((ref) => Stream.value([])),
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
            home: MainTabPage(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MainTabPage)),
      );
      container
          .read(pendingLibraryLaunchActionProvider.notifier)
          .requestAddMenu();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(shared_find.findAppText('新規フォルダ作成'), findsOneWidget);
      expect(shared_find.findAppText('フォルダを取り込む'), findsOneWidget);
      expect(shared_find.findAppText('ファイルを取り込む'), findsOneWidget);
      expect(container.read(currentTabIndexProvider), 0);
    });

    testWidgets('ルートで戻る操作をすると標準のSystemNavigator.popが呼ばれる', (tester) async {
      final platformCalls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (methodCall) async {
          platformCalls.add(methodCall);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith(
              (ref) async => SharedPreferences.getInstance(),
            ),
            hapticsEnabledProvider.overrideWith((ref) => false),
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
            personalLibraryStateProvider.overrideWith(
              (ref) =>
                  Stream.value(const PersonalLibraryState(hasImported: false)),
            ),
            recentlyOpenedFilesProvider.overrideWith((ref) => Stream.value([])),
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
            home: MainTabPage(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('ホーム'));
      await tester.pump(const Duration(milliseconds: 500));
      platformCalls.clear();

      // ルートの戻る操作はAndroid標準どおりランチャーへ戻す。
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('もう一度戻るを押すと終了します'), findsNothing);
      expect(
        platformCalls.where((call) => call.method == 'SystemNavigator.pop'),
        hasLength(1),
      );

      // クールダウン経過後は次の戻る操作も処理する。
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump(const Duration(milliseconds: 500));
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        platformCalls.where((call) => call.method == 'SystemNavigator.pop'),
        hasLength(2),
      );
    });

    testWidgets('同一タブ再タップでタブ内の深い画面からルートへ戻る', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith(
              (ref) async => SharedPreferences.getInstance(),
            ),
            hapticsEnabledProvider.overrideWith((ref) => false),
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
            personalLibraryStateProvider.overrideWith(
              (ref) =>
                  Stream.value(const PersonalLibraryState(hasImported: false)),
            ),
            recentlyOpenedFilesProvider.overrideWith((ref) => Stream.value([])),
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
            home: MainTabPage(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // ホーム（index 1）の設定を開き、同じホームタブの再選択で戻る。
      await tester.tap(find.text('ホーム'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('設定'), findsOneWidget);
      expect(find.byType(SettingsPage), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MainTabPage)),
      );
      expect(container.read(currentTabIndexProvider), 1);
      container
          .read(unsavedDataKeysProvider.notifier)
          .markAsUnsaved('settings-test');

      tester
          .widget<NavigationBar>(find.byType(NavigationBar))
          .onDestinationSelected!(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(shared_find.findAppText('変更を破棄しますか？'), findsOneWidget);
      expect(find.byType(SettingsPage), findsOneWidget);

      await tester.tap(find.byTooltip('キャンセル').last);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SettingsPage), findsOneWidget);

      tester
          .widget<NavigationBar>(find.byType(NavigationBar))
          .onDestinationSelected!(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(shared_find.findAppText('破棄する'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SettingsPage), findsNothing);
      expect(find.text('ホーム'), findsWidgets);
      expect(container.read(unsavedDataKeysProvider), isEmpty);
    });

    testWidgets('ライブラリ内のフォルダでも同一タブ再タップで先頭へ戻る', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith(
              (ref) async => SharedPreferences.getInstance(),
            ),
            hapticsEnabledProvider.overrideWith((ref) => false),
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
            personalLibraryStateProvider.overrideWith(
              (ref) =>
                  Stream.value(const PersonalLibraryState(hasImported: false)),
            ),
            recentlyOpenedFilesProvider.overrideWith((ref) => Stream.value([])),
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
            home: MainTabPage(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MainTabPage)),
      );
      final filter = mediaFilterNotifierProvider(AppMode.internal);
      container.read(filter.notifier).updateParentPath('library/folder');
      await tester.pump();
      expect(container.read(filter).parentPath, 'library/folder');

      tester
          .widget<NavigationBar>(find.byType(NavigationBar))
          .onDestinationSelected!(0);
      await tester.pump();

      expect(container.read(filter).parentPath, isNull);
    });

    testWidgets('異なるタブ切り替え時にも未保存データ確認ダイアログが表示される', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith(
              (ref) async => SharedPreferences.getInstance(),
            ),
            hapticsEnabledProvider.overrideWith((ref) => false),
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
            personalLibraryStateProvider.overrideWith(
              (ref) =>
                  Stream.value(const PersonalLibraryState(hasImported: false)),
            ),
            recentlyOpenedFilesProvider.overrideWith((ref) => Stream.value([])),
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
            home: MainTabPage(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MainTabPage)),
      );
      container
          .read(unsavedDataKeysProvider.notifier)
          .markAsUnsaved('tab-switch-test');

      // ホームタブ（index 1）を選択
      tester
          .widget<NavigationBar>(find.byType(NavigationBar))
          .onDestinationSelected!(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // ダイアログが出ること
      expect(shared_find.findAppText('変更を破棄しますか？'), findsOneWidget);
      expect(container.read(currentTabIndexProvider), 0); // まだタブは切り替わらない

      // キャンセル
      await tester.tap(find.byTooltip('キャンセル').last);
      await tester.pump(const Duration(milliseconds: 500));
      expect(container.read(currentTabIndexProvider), 0);

      // 再度ホームタブを選択して破棄
      tester
          .widget<NavigationBar>(find.byType(NavigationBar))
          .onDestinationSelected!(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(shared_find.findAppText('破棄する'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(container.read(currentTabIndexProvider), 1);
      expect(container.read(unsavedDataKeysProvider), isEmpty);
    });

    testWidgets('LiquidGlassNavigationスタイルで正常に表示・タブ切り替えができる', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith(
              (ref) async => SharedPreferences.getInstance(),
            ),
            hapticsEnabledProvider.overrideWith((ref) => false),
            appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
            personalLibraryStateProvider.overrideWith(
              (ref) =>
                  Stream.value(const PersonalLibraryState(hasImported: false)),
            ),
            recentlyOpenedFilesProvider.overrideWith((ref) => Stream.value([])),
            bottomNavigationStyleNotifierProvider.overrideWith(
              () => _TestLiquidGlassNotifier(),
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
            home: MainTabPage(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(LiquidGlassNavigation), findsOneWidget);
      expect(shared_find.findAppText('ライブラリ'), findsWidgets);
      expect(shared_find.findAppText('ホーム'), findsWidgets);

      // ホームタブへ切り替える
      await tester.tap(shared_find.findAppText('ホーム').last);
      await tester.pump(const Duration(milliseconds: 500));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MainTabPage)),
      );
      expect(container.read(currentTabIndexProvider), 1);
    });

    testWidgets(
      'ルートNavigator上にモーダルが表示されている状態で戻る操作をした場合、モーダルのみが閉じ終了スナックバーは表示されない',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWith(
                (ref) async => SharedPreferences.getInstance(),
              ),
              hapticsEnabledProvider.overrideWith((ref) => false),
              appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
              personalLibraryStateProvider.overrideWith(
                (ref) => Stream.value(
                  const PersonalLibraryState(hasImported: false),
                ),
              ),
              recentlyOpenedFilesProvider.overrideWith(
                (ref) => Stream.value([]),
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
              home: MainTabPage(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        final context = tester.element(find.byType(MainTabPage));

        // ルートNavigator上にモーダルボトムシートを表示
        showModalBottomSheet<void>(
          context: context,
          useRootNavigator: true,
          builder: (sheetContext) =>
              const Scaffold(body: Center(child: Text('テスト用ボトムシート'))),
        );
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('テスト用ボトムシート'), findsOneWidget);

        // 戻る操作を実行
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(milliseconds: 500));

        // ボトムシートが閉じ、かつ「もう一度戻るを押すと終了します」が表示されていないこと
        expect(find.text('テスト用ボトムシート'), findsNothing);
        expect(find.text('もう一度戻るを押すと終了します'), findsNothing);
      },
    );
  });
}

class _TestLiquidGlassNotifier extends BottomNavigationStyleNotifier {
  @override
  BottomNavigationStyle build() => BottomNavigationStyle.liquidGlass;
}
