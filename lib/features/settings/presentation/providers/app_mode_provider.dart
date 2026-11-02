import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/setting_notifier.dart';
import '../../domain/models/app_mode.dart';

export '../../domain/models/app_mode.dart';

part 'app_mode_provider.g.dart';

@riverpod
class AppModeAsync extends _$AppModeAsync with SettingNotifierMixin<AppMode> {
  static const _key = 'app_mode';

  @override
  String get key => _key;

  @override
  AppMode get defaultValue => AppMode.internal;

  @override
  Future<AppMode> build() => buildSetting();

  Future<bool> setMode(AppMode mode) {
    if (mode == AppMode.external) {
      return Future.value(false);
    }
    return setValue(mode);
  }

  @override
  AppMode readFromPrefs(SharedPreferences prefs) {
    final index = prefs.getInt(key) ?? defaultValue.index;
    if (index < 0 || index >= AppMode.values.length) {
      return defaultValue;
    }
    return AppMode.values[index];
  }

  @override
  Future<void> writeToPrefs(SharedPreferences prefs, AppMode value) async {
    await prefs.setInt(key, value.index);
  }
}

@riverpod
AppMode appMode(Ref ref) {
  return AppMode.internal;
}

@riverpod
bool isExternalMode(Ref ref) {
  return ref.watch(appModeProvider) == AppMode.external;
}
