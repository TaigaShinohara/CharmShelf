import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shared_preferences_provider.dart';

/// SharedPreferencesを使う設定の標準パターン
///
/// - build(): prefsから読み込み、失敗時はdefaultValue
/// - setValue(): 保存してstate更新
/// @riverpod の生成Notifier（`_$X`）に mixin して使う前提。
mixin SettingNotifierMixin<T> on AnyNotifier<AsyncValue<T>, T> {
  String get key;
  T get defaultValue;

  T readFromPrefs(SharedPreferences prefs);
  Future<void> writeToPrefs(SharedPreferences prefs, T value);

  Future<T> buildSetting() async {
    try {
      final prefs = await ref.watch(sharedPreferencesProvider.future);
      return readFromPrefs(prefs);
    } catch (_) {
      return defaultValue;
    }
  }

  Future<bool> setValue(T value) async {
    // read(notifier)だけの呼出元でも、非同期保存が終わるまで破棄させない。
    final operation = ref.keepAlive();
    final oldState = state;
    // 楽観的UIにするため即座に反映するか、確実に保存してから反映するか。
    // 今回は安全側に倒しつつ、UIがちらつかないようLoadingにはせずそのまま試みる。
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      await writeToPrefs(prefs, value);
      if (ref.mounted) state = AsyncData(value);
      return true;
    } catch (e) {
      if (ref.mounted) state = oldState; // Rollback
      return false;
    } finally {
      operation.close();
    }
  }
}
