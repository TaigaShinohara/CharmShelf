import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SystemUIService {
  static SystemUiOverlayStyle overlayStyleFor(
    Brightness brightness, {
    Color? navigationBarColor,
  }) {
    final iconBrightness = brightness == Brightness.light
        ? Brightness.dark
        : Brightness.light;
    final iosStatusBarBrightness = brightness == Brightness.light
        ? Brightness.light
        : Brightness.dark;

    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: iconBrightness,
      statusBarBrightness: iosStatusBarBrightness,
      systemNavigationBarColor: navigationBarColor,
      systemNavigationBarIconBrightness: iconBrightness,
      systemNavigationBarDividerColor: navigationBarColor,
    );
  }

  static void setImmersiveStatusBar({
    Brightness brightness = Brightness.light,
    Color? navigationBarColor,
  }) {
    SystemChrome.setSystemUIOverlayStyle(
      overlayStyleFor(brightness, navigationBarColor: navigationBarColor),
    );
  }

  static Future<void> setPortraitOnly() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  static Future<void> setAllOrientations() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// デバイス種別（スマートフォン vs タブレット/iPad）に応じた画面向きを適用
  ///
  /// - タブレット（iPad/大画面）: 全方向（回転許可）
  /// - スマートフォン（iPhone/Android）: 縦向き固定
  static Future<void> setResponsiveOrientations() async {
    try {
      final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
      if (view != null) {
        final physicalSize = view.physicalSize;
        final devicePixelRatio = view.devicePixelRatio;
        final width = physicalSize.width / devicePixelRatio;
        final height = physicalSize.height / devicePixelRatio;
        final shortestSide = width < height ? width : height;

        // 一般的なタブレット基準（最短辺 600dp 以上）
        if (shortestSide >= 600) {
          await setAllOrientations();
          return;
        }
      }
    } catch (_) {
      // 取得失敗時はデフォルトでPortrait
    }
    await setPortraitOnly();
  }
}
