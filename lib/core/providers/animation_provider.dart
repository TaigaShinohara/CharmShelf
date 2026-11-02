import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'shared_preferences_provider.dart';

const String _prefsKey = 'animation_enabled';

/// ユーザー設定としての「アニメーションON/OFF」状態（SharedPreferences）
///
/// 注意:
/// - `AppConfig.animation.enabled` が false の場合、この設定は常に false 扱い
/// - OSの「視差効果を減らす / アニメーションを減らす」は、Widget側で `MediaQuery.disableAnimations` を見て最終判断します
final animationEnabledAsyncProvider =
    AsyncNotifierProvider<AnimationEnabledNotifier, bool>(
      AnimationEnabledNotifier.new,
    );

class AnimationEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    final yamlDefault = AppConfig.animation.enabled;

    // YAMLで無効なら常に無効
    if (!yamlDefault) return false;

    return prefs.getBool(_prefsKey) ?? true;
  }

  Future<bool> setValue(bool value) async {
    // YAMLで無効なら、ユーザーがONにしても無効
    if (!AppConfig.animation.enabled) {
      state = const AsyncData(false);
      return false;
    }

    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(_prefsKey, value);
    state = AsyncData(value);
    return true;
  }
}

/// 現在のユーザー設定（ローディング中は true 扱い）
final animationEnabledProvider = Provider<bool>((ref) {
  final v = ref.watch(animationEnabledAsyncProvider);
  return v.value ?? true;
});

/// UIで使う「最終的にアニメーションしてよいか」の判定
///
/// - YAMLで無効 → false
/// - ユーザー設定で無効 → false
/// - OSで disableAnimations → false
bool animationsAllowed(BuildContext context, WidgetRef ref) {
  if (!AppConfig.animation.enabled) return false;
  if (!ref.watch(animationEnabledProvider)) return false;
  final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  return !reduceMotion;
}
