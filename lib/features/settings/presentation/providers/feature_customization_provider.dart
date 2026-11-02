import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/setting_notifier.dart';

part 'feature_customization_provider.g.dart';

@riverpod
class FolderManagementEnabledAsync extends _$FolderManagementEnabledAsync
    with SettingNotifierMixin<bool> {
  @override
  String get key => 'folder_management_enabled';

  @override
  bool get defaultValue => true;

  @override
  Future<bool> build() => buildSetting();

  @override
  bool readFromPrefs(SharedPreferences prefs) =>
      prefs.getBool(key) ?? defaultValue;

  @override
  Future<void> writeToPrefs(SharedPreferences prefs, bool value) async {
    await prefs.setBool(key, value);
  }
}

@riverpod
bool folderManagementEnabled(Ref ref) {
  return ref.watch(folderManagementEnabledAsyncProvider).value ?? true;
}
