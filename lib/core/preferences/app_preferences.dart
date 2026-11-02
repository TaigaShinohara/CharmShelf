import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/shared_preferences_provider.dart';

final appPreferencesProvider = FutureProvider<AppPreferences>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return AppPreferences(prefs);
});

class AppPreferences {
  AppPreferences(this._prefs);

  final SharedPreferences _prefs;

  static const onboardingCompletedKey = 'onboarding_completed';
  static const legacyWelcomeHandledKey = 'legacy_welcome_handled_v1';
  static const legacyEntryChoiceKey = 'legacy_entry_choice_v1';
  static const restorePromptHandledKey = 'restore_prompt_handled';
  static const themeModeKey = 'theme_mode';
  static const localeKey = 'locale';
  static const localAuthEnabledKey = 'local_auth_enabled';
  static const hapticsEnabledKey = 'haptics_enabled';
  static const soundEnabledKey = 'sound_enabled';
  static const lastSelectedTabKey = 'last_selected_tab';
  static const startupMaintenanceVersionKey = 'startup_maintenance_version';
  static const importPickerGuideDismissedKey = 'import_picker_guide_dismissed';
  static const importFlowDraftSessionKey = 'import_flow_draft_session_v1';
  static const importPickerGrantReleasesKey = 'import_picker_grant_releases_v1';

  static const libraryTabIndex = 0;
  static const homeTabIndex = 1;

  bool get importPickerGuideDismissed =>
      _prefs.getBool(importPickerGuideDismissedKey) ?? false;
  Future<void> setImportPickerGuideDismissed(bool value) =>
      _prefs.setBool(importPickerGuideDismissedKey, value);

  bool get onboardingCompleted =>
      _prefs.getBool(onboardingCompletedKey) ?? false;
  Future<void> setOnboardingCompleted(bool value) =>
      _prefs.setBool(onboardingCompletedKey, value);

  ThemeMode get themeMode {
    final index = _prefs.getInt(themeModeKey) ?? ThemeMode.system.index;
    return ThemeMode.values[index.clamp(0, ThemeMode.values.length - 1)];
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setInt(themeModeKey, mode.index);

  String get locale => _prefs.getString(localeKey) ?? 'ja';
  Future<void> setLocale(String value) => _prefs.setString(localeKey, value);

  bool get localAuthEnabled => _prefs.getBool(localAuthEnabledKey) ?? false;
  Future<void> setLocalAuthEnabled(bool value) =>
      _prefs.setBool(localAuthEnabledKey, value);

  bool get hapticsEnabled => _prefs.getBool(hapticsEnabledKey) ?? true;
  Future<void> setHapticsEnabled(bool value) =>
      _prefs.setBool(hapticsEnabledKey, value);

  bool get soundEnabled => _prefs.getBool(soundEnabledKey) ?? true;
  Future<void> setSoundEnabled(bool value) =>
      _prefs.setBool(soundEnabledKey, value);

  int get lastSelectedTab {
    final value = _prefs.getInt(lastSelectedTabKey) ?? libraryTabIndex;
    return value == homeTabIndex ? homeTabIndex : libraryTabIndex;
  }

  Future<void> setLastSelectedTab(int value) => _prefs.setInt(
    lastSelectedTabKey,
    value == homeTabIndex ? homeTabIndex : libraryTabIndex,
  );
}
