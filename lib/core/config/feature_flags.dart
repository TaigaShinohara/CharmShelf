import 'package:private_shelf/core/config/app_config.dart';
import 'package:flutter/foundation.dart';

/// 機能ON/OFFのためのフラグ
///
/// 量産時は `template_config.yaml` → `AppConfig`(自動生成) を経由して切り替えます。
class FeatureFlags {
  /// Enable only after configuring products for your own store application.
  static const bool enableSupportPurchases = bool.fromEnvironment(
    'CHARMSHELF_STORE_PURCHASES',
    defaultValue: false,
  );

  /// Webビルドを許可するフラグ（kIsWebの時に参照）
  static bool get enableWeb => AppConfig.features.webEnabled;

  /// WatchOS連携フラグ
  static bool get enableWatchOs => AppConfig.features.watchOsEnabled && !kIsWeb;

  static bool get enableTabBar => AppConfig.features.tabBarEnabled;
  static bool get enableLocalAuth =>
      AppConfig.features.localAuthEnabled && !kIsWeb;
  static bool get enableOnboarding => AppConfig.features.onboardingEnabled;
  static bool get enableAppReview =>
      AppConfig.features.appReviewEnabled && !kIsWeb;
  static bool get enableTutorial => AppConfig.features.tutorialEnabled;
  static bool get enableForceUpdate => AppConfig.features.forceUpdateEnabled;
  static bool get enableDeepLink =>
      AppConfig.features.deepLinkEnabled && !kIsWeb;
  static String get deepLinkScheme => AppConfig.features.deepLinkScheme;

  static bool get enableDarkMode => AppConfig.features.darkModeEnabled;
  static bool get enableI18n => AppConfig.features.i18nEnabled;

  static bool get enableHaptics => AppConfig.features.hapticsEnabled && !kIsWeb;
  static bool get enableSound => AppConfig.features.soundEnabled;

  /// UIアニメーション（テンプレートYAMLでの大枠ON/OFF）
  static bool get enableAnimation => AppConfig.animation.enabled;

  /// 開発者向けDIP（Developer In-App Panel）
  static bool get enableDip => AppConfig.features.dipEnabled && !kReleaseMode;

  /// ライブラリのFAB（追加ボタン）をスクロールで自動非表示にするか
  static bool get enableLibraryFabAutoHide =>
      AppConfig.features.libraryFabAutoHide;
}
