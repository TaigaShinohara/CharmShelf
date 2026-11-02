import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/setting_notifier.dart';

part 'show_hidden_files_provider.g.dart';

@riverpod
class ShowHiddenFilesAsync extends _$ShowHiddenFilesAsync
    with SettingNotifierMixin<bool> {
  static const _key = 'show_hidden_files';

  @override
  String get key => _key;

  @override
  bool get defaultValue => false;

  @override
  Future<bool> build() => buildSetting();

  Future<void> setEnabled(bool enabled) => setValue(enabled);

  @override
  bool readFromPrefs(SharedPreferences prefs) {
    return prefs.getBool(key) ?? defaultValue;
  }

  @override
  Future<void> writeToPrefs(SharedPreferences prefs, bool value) async {
    await prefs.setBool(key, value);
  }
}

@riverpod
bool showHiddenFiles(Ref ref) {
  return ref.watch(showHiddenFilesAsyncProvider).value ?? false;
}
