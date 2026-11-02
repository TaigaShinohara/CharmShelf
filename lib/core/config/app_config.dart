import 'package:flutter/widgets.dart';

/// アプリ設定（GENERATED）
///
/// このファイルは `scripts/update_config.dart` または `scripts/create_app.dart` が
/// `template_config.yaml` から生成します。
///
/// 量産時の「切り替えスイッチ」は template_config.yaml です。
class AppConfig {
  static const String appName = 'CharmShelf';
  static const String packageName = 'com.tsmusic.privateshelf.opensource';
  static const int minAge = 0;
  static const String externalLegalUrl = '';

  static const Features features = Features(
    webEnabled: false,
    watchOsEnabled: false,
    wearOsEnabled: false,
    tabBarEnabled: true,
    localAuthEnabled: true,
    onboardingEnabled: true,
    appReviewEnabled: false,
    tutorialEnabled: true,
    forceUpdateEnabled: false,
    deepLinkEnabled: false,
    deepLinkScheme: 'charmshelf',
    darkModeEnabled: true,
    i18nEnabled: true,
    hapticsEnabled: true,
    soundEnabled: false,
    dipEnabled: true,
    libraryFabAutoHide: true,
    uiShowcaseEnabled: false,
    uiShowcaseChatEnabled: false,
    uiShowcaseTimelineEnabled: false,
    uiShowcaseVideoEnabled: false,
    uiShowcaseShortsEnabled: false,
    uiShowcaseSwipeCardEnabled: false,
  );

  static const ThemeConfig theme = ThemeConfig(
    primaryColor: 0xFF5578A8,
    secondaryColor: 0xFF55749F,
    successColor: 0xFF059669,
    warningColor: 0xFFD97706,
    errorColor: 0xFFDC2626,
    infoColor: 0xFF4F719D,
    backgroundColor: 0xFFFFFFFF,
    surfaceColor: 0xFFF8FAFF,
    scaffoldColor: 0xFFF1F5FB,
    shadowColor: 0xFF1E3A5F,
    overlayColor: 0xFF0F172A,
    borderColor: 0xFFCBD5E8,
    textPrimaryColor: 0xFF0F172A,
    textSecondaryColor: 0xFF475569,
    textDisabledColor: 0xFF94A3B8,
    useMaterial3: true,
  );

  static const AnimationConfig animation = AnimationConfig(
    enabled: true,
    preset: 'standard',
    instant: Duration(milliseconds: 100),
    fast: Duration(milliseconds: 200),
    normal: Duration(milliseconds: 300),
    slow: Duration(milliseconds: 500),
    page: Duration(milliseconds: 350),
    staggerDelay: Duration(milliseconds: 50),
  );

  static const List<Locale> supportedLocales = <Locale>[
    Locale('ja'),
    Locale('en'),
  ];

  static const String defaultLocale = 'ja';

  static const TierConfig tiers = TierConfig(
    s: 'S',
    a: 'A',
    b: 'B',
    c: 'C',
    d: 'D',
  );

  static const double textScaleMax = 2.0;
  static const String orientation = 'portrait';
}

class TierConfig {
  const TierConfig({
    required this.s,
    required this.a,
    required this.b,
    required this.c,
    required this.d,
  });

  final String s;
  final String a;
  final String b;
  final String c;
  final String d;
}

class Features {
  const Features({
    required this.webEnabled,
    required this.watchOsEnabled,
    required this.wearOsEnabled,
    required this.tabBarEnabled,
    required this.localAuthEnabled,
    required this.onboardingEnabled,
    required this.appReviewEnabled,
    required this.tutorialEnabled,
    required this.forceUpdateEnabled,
    required this.deepLinkEnabled,
    required this.deepLinkScheme,
    required this.darkModeEnabled,
    required this.i18nEnabled,
    required this.hapticsEnabled,
    required this.soundEnabled,
    required this.dipEnabled,
    required this.libraryFabAutoHide,

    required this.uiShowcaseEnabled,
    required this.uiShowcaseChatEnabled,
    required this.uiShowcaseTimelineEnabled,
    required this.uiShowcaseVideoEnabled,
    required this.uiShowcaseShortsEnabled,
    required this.uiShowcaseSwipeCardEnabled,
  });

  final bool webEnabled;
  final bool watchOsEnabled;
  final bool wearOsEnabled;
  final bool tabBarEnabled;
  final bool localAuthEnabled;
  final bool onboardingEnabled;
  final bool appReviewEnabled;
  final bool tutorialEnabled;
  final bool forceUpdateEnabled;
  final bool deepLinkEnabled;
  final String deepLinkScheme;
  final bool darkModeEnabled;
  final bool i18nEnabled;
  final bool hapticsEnabled;
  final bool soundEnabled;
  final bool dipEnabled;
  final bool libraryFabAutoHide;

  final bool uiShowcaseEnabled;
  final bool uiShowcaseChatEnabled;
  final bool uiShowcaseTimelineEnabled;
  final bool uiShowcaseVideoEnabled;
  final bool uiShowcaseShortsEnabled;
  final bool uiShowcaseSwipeCardEnabled;
}

class ThemeConfig {
  const ThemeConfig({
    required this.primaryColor,
    required this.secondaryColor,
    required this.successColor,
    required this.warningColor,
    required this.errorColor,
    required this.infoColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.scaffoldColor,
    required this.shadowColor,
    required this.overlayColor,
    required this.borderColor,
    required this.textPrimaryColor,
    required this.textSecondaryColor,
    required this.textDisabledColor,
    required this.useMaterial3,
  });

  final int primaryColor;
  final int secondaryColor;
  final int successColor;
  final int warningColor;
  final int errorColor;
  final int infoColor;
  final int backgroundColor;
  final int surfaceColor;
  final int scaffoldColor;
  final int shadowColor;
  final int overlayColor;
  final int borderColor;
  final int textPrimaryColor;
  final int textSecondaryColor;
  final int textDisabledColor;
  final bool useMaterial3;
}

class AnimationConfig {
  const AnimationConfig({
    required this.enabled,
    required this.preset,
    required this.instant,
    required this.fast,
    required this.normal,
    required this.slow,
    required this.page,
    required this.staggerDelay,
  });

  final bool enabled;
  final String preset;
  final Duration instant;
  final Duration fast;
  final Duration normal;
  final Duration slow;
  final Duration page;
  final Duration staggerDelay;

  /// プリセットに基づく標準カーブ
  Curve get defaultCurve => switch (preset) {
        'subtle' => Curves.easeOut,
        'dynamic' => Curves.easeOutBack,
        _ => Curves.easeOutCubic,
      };

  /// 少し強調したい場面向け（バウンス寄り）
  Curve get emphasizedCurve => switch (preset) {
        'subtle' => Curves.easeOutCubic,
        _ => Curves.easeOutBack,
      };
}
