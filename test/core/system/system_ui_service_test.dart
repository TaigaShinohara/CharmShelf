import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/system/system_ui_service.dart';

void main() {
  group('SystemUIService.overlayStyleFor', () {
    test('ライトテーマでは暗いシステムアイコンを使う', () {
      const navigationBarColor = Color(0xFFF8FAFC);

      final style = SystemUIService.overlayStyleFor(
        Brightness.light,
        navigationBarColor: navigationBarColor,
      );

      expect(style.statusBarIconBrightness, Brightness.dark);
      expect(style.statusBarBrightness, Brightness.light);
      expect(style.systemNavigationBarIconBrightness, Brightness.dark);
      expect(style.systemNavigationBarColor, navigationBarColor);
    });

    test('ダークテーマでは明るいシステムアイコンを使う', () {
      const navigationBarColor = Color(0xFF101318);

      final style = SystemUIService.overlayStyleFor(
        Brightness.dark,
        navigationBarColor: navigationBarColor,
      );

      expect(style.statusBarIconBrightness, Brightness.light);
      expect(style.statusBarBrightness, Brightness.dark);
      expect(style.systemNavigationBarIconBrightness, Brightness.light);
      expect(style.systemNavigationBarColor, navigationBarColor);
    });
  });
}
