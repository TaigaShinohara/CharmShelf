import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:private_shelf/core/providers/setting_notifier.dart';

part 'secret_mode_provider.g.dart';

@riverpod
class SecretMode extends _$SecretMode with SettingNotifierMixin<bool> {
  @override
  String get key => 'library_hidden_mode';

  @override
  bool get defaultValue => false;

  @override
  bool readFromPrefs(SharedPreferences prefs) {
    return prefs.getBool(key) ?? defaultValue;
  }

  @override
  Future<void> writeToPrefs(SharedPreferences prefs, bool value) async {
    await prefs.setBool(key, value);
  }

  @override
  FutureOr<bool> build() {
    return buildSetting();
  }

  /// シークレット表示のオンオフを切り替える
  Future<void> toggle() async {
    final current = state.value ?? defaultValue;
    await setValue(!current);
  }
}
