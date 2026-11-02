import 'dart:ui';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/setting_notifier.dart';

part 'locale_provider.g.dart';

@riverpod
class AppLocaleAsync extends _$AppLocaleAsync
    with SettingNotifierMixin<Locale?> {
  static const _key = 'app_locale';

  @override
  String get key => _key;

  @override
  Locale? get defaultValue => null; // null means system language

  @override
  Future<Locale?> build() => buildSetting();

  Future<bool> setLocale(Locale? locale) => setValue(locale);

  @override
  Locale? readFromPrefs(SharedPreferences prefs) {
    final languageCode = prefs.getString(key);
    if (languageCode == null) return defaultValue;
    return Locale(languageCode);
  }

  @override
  Future<void> writeToPrefs(SharedPreferences prefs, Locale? value) async {
    if (value == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value.languageCode);
    }
  }
}

@riverpod
Locale? appLocale(Ref ref) {
  return ref.watch(appLocaleAsyncProvider).value;
}
