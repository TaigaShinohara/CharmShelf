import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/providers/shared_preferences_provider.dart';
import 'package:private_shelf/core/providers/tab_navigation_provider.dart';
import 'package:private_shelf/core/preferences/app_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CurrentTabIndex', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('初期値は0（ライブラリタブ）', () {
      final index = container.read(currentTabIndexProvider);
      expect(index, 0);
    });

    test('switchToでタブインデックスを切り替えられる', () {
      container.read(currentTabIndexProvider.notifier).switchTo(1);
      expect(container.read(currentTabIndexProvider), 1);
    });

    test('goToHomeでインデックスが1になる', () {
      container.read(currentTabIndexProvider.notifier).switchTo(0);
      expect(container.read(currentTabIndexProvider), 0);

      container.read(currentTabIndexProvider.notifier).goToHome();
      expect(container.read(currentTabIndexProvider), 1);
    });

    test('goToLibraryでインデックスが0になる', () {
      container.read(currentTabIndexProvider.notifier).switchTo(1);
      container.read(currentTabIndexProvider.notifier).goToLibrary();
      expect(container.read(currentTabIndexProvider), 0);
    });

    test('同じインデックスへの切り替えも正常に動作する', () {
      container.read(currentTabIndexProvider.notifier).switchTo(0);
      expect(container.read(currentTabIndexProvider), 0);

      container.read(currentTabIndexProvider.notifier).switchTo(0);
      expect(container.read(currentTabIndexProvider), 0);
    });

    test('保存済みの最終タブを復元できる', () async {
      SharedPreferences.setMockInitialValues({
        AppPreferences.lastSelectedTabKey: AppPreferences.homeTabIndex,
      });
      final restoredContainer = ProviderContainer();
      addTearDown(restoredContainer.dispose);

      await restoredContainer
          .read(currentTabIndexProvider.notifier)
          .restoreLastSelectedTab();

      expect(restoredContainer.read(currentTabIndexProvider), 1);
    });

    test('復元待ちのユーザー操作を保存済みタブで上書きしない', () async {
      SharedPreferences.setMockInitialValues({
        AppPreferences.lastSelectedTabKey: AppPreferences.libraryTabIndex,
      });
      final prefsCompleter = Completer<SharedPreferences>();
      final restoredContainer = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith(
            (ref) => prefsCompleter.future,
          ),
        ],
      );
      addTearDown(restoredContainer.dispose);

      final restore = restoredContainer
          .read(currentTabIndexProvider.notifier)
          .restoreLastSelectedTab();
      restoredContainer.read(currentTabIndexProvider.notifier).goToHome();
      prefsCompleter.complete(await SharedPreferences.getInstance());
      await restore;

      expect(
        restoredContainer.read(currentTabIndexProvider),
        AppPreferences.homeTabIndex,
      );
    });
  });
}
