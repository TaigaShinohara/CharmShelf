import 'package:shared_preferences/shared_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/feature_flags.dart';
import '../providers/setting_notifier.dart';
import 'feedback_service.dart';
import 'haptics_service.dart';
import 'sound_service.dart';

part 'feedback_providers.g.dart';

@riverpod
class HapticsEnabledAsync extends _$HapticsEnabledAsync
    with SettingNotifierMixin<bool> {
  @override
  Future<bool> build() async {
    final value = await buildSetting();
    HapticsService.updateUserEnabled(value);
    return value;
  }

  @override
  String get key => 'haptics_enabled';

  @override
  bool get defaultValue => FeatureFlags.enableHaptics ? true : false;

  @override
  bool readFromPrefs(SharedPreferences prefs) {
    // Webなどで触覚が無効な場合は常にfalse
    if (!FeatureFlags.enableHaptics) {
      HapticsService.updateUserEnabled(false);
      return false;
    }
    final value = prefs.getBool(key) ?? defaultValue;
    HapticsService.updateUserEnabled(value);
    return value;
  }

  @override
  Future<void> writeToPrefs(SharedPreferences prefs, bool value) async {
    final effectiveValue = FeatureFlags.enableHaptics ? value : false;
    HapticsService.updateUserEnabled(effectiveValue);
    await prefs.setBool(key, effectiveValue);
  }
}

@riverpod
bool hapticsEnabled(Ref ref) {
  final isEnabled =
      ref.watch(hapticsEnabledAsyncProvider).value ??
      FeatureFlags.enableHaptics;
  HapticsService.updateUserEnabled(isEnabled);
  return isEnabled;
}

@riverpod
class SoundEnabledAsync extends _$SoundEnabledAsync
    with SettingNotifierMixin<bool> {
  @override
  Future<bool> build() => buildSetting();

  @override
  String get key => 'sound_enabled';

  @override
  bool get defaultValue => true;

  @override
  bool readFromPrefs(SharedPreferences prefs) =>
      prefs.getBool(key) ?? defaultValue;

  @override
  Future<void> writeToPrefs(SharedPreferences prefs, bool value) async {
    await prefs.setBool(key, value);
  }
}

@riverpod
bool soundEnabled(Ref ref) {
  return ref.watch(soundEnabledAsyncProvider).value ?? true;
}

@Riverpod(keepAlive: true)
SoundService soundService(Ref ref) {
  final service = SoundService();
  ref.onDispose(service.dispose);
  return service;
}

@Riverpod(keepAlive: true)
FeedbackService feedbackService(Ref ref) {
  return FeedbackService(ref);
}
