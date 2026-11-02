import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/setting_notifier.dart';

part 'theme_provider.g.dart';

@riverpod
class ThemeModeAsync extends _$ThemeModeAsync
    with SettingNotifierMixin<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  Future<ThemeMode> build() => buildSetting();

  Future<void> setThemeMode(ThemeMode mode) => setValue(mode);

  @override
  String get key => _key;

  @override
  ThemeMode get defaultValue => ThemeMode.system;

  @override
  ThemeMode readFromPrefs(SharedPreferences prefs) {
    final index = prefs.getInt(key) ?? defaultValue.index;
    return ThemeMode.values[index.clamp(0, ThemeMode.values.length - 1)];
  }

  @override
  Future<void> writeToPrefs(SharedPreferences prefs, ThemeMode value) async {
    await prefs.setInt(key, value.index);
  }
}

@riverpod
ThemeMode themeMode(Ref ref) {
  return ref.watch(themeModeAsyncProvider).value ?? ThemeMode.system;
}
