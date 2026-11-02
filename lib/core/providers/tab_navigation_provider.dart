import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show Notifier, NotifierProvider;

import '../preferences/app_preferences.dart';
import 'shared_preferences_provider.dart';

part 'tab_navigation_provider.g.dart';

/// 現在選択されているタブのインデックスを管理するプロバイダー
@Riverpod(keepAlive: true)
class CurrentTabIndex extends _$CurrentTabIndex {
  @override
  int build() => AppPreferences.libraryTabIndex;

  Future<void> restoreLastSelectedTab() async {
    final indexBeforeRestore = state;
    final prefs = await ref.read(sharedPreferencesProvider.future);
    // 復元待ちの間にユーザー操作やディープリンクでタブが変わった場合は、
    // 古い保存値で現在の操作を上書きしない。
    if (state != indexBeforeRestore) return;
    final stored = prefs.getInt(AppPreferences.lastSelectedTabKey);
    if (stored == null) return;
    state = stored == AppPreferences.homeTabIndex
        ? AppPreferences.homeTabIndex
        : AppPreferences.libraryTabIndex;
  }

  /// タブを切り替える
  void switchTo(int index) {
    final normalized = index == AppPreferences.homeTabIndex
        ? AppPreferences.homeTabIndex
        : AppPreferences.libraryTabIndex;
    state = normalized;
    unawaited(_persistSelectedTab(normalized));
  }

  Future<void> _persistSelectedTab(int index) async {
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      await prefs.setInt(AppPreferences.lastSelectedTabKey, index);
    } catch (_) {
      // ナビゲーション自体は設定保存の失敗から独立して継続できる。
    }
  }

  /// ホームタブに切り替える
  void goToHome() => switchTo(AppPreferences.homeTabIndex);

  /// ライブラリタブに切り替える
  void goToLibrary() => switchTo(AppPreferences.libraryTabIndex);
}

enum LibraryLaunchAction { showAddMenu, importFile }

class PendingLibraryLaunchActionNotifier
    extends Notifier<LibraryLaunchAction?> {
  @override
  LibraryLaunchAction? build() => null;

  void requestAddMenu() => state = LibraryLaunchAction.showAddMenu;

  void requestImportFile() => state = LibraryLaunchAction.importFile;

  LibraryLaunchAction? take() {
    final action = state;
    state = null;
    return action;
  }
}

final pendingLibraryLaunchActionProvider =
    NotifierProvider<PendingLibraryLaunchActionNotifier, LibraryLaunchAction?>(
      PendingLibraryLaunchActionNotifier.new,
    );
