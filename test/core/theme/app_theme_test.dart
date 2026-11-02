import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('lightテーマを生成できる', () {
      final theme = AppTheme.light;

      expect(theme, isA<ThemeData>());
      expect(theme.brightness, Brightness.light);
      expect(
        theme.appBarTheme.systemOverlayStyle?.statusBarIconBrightness,
        Brightness.dark,
      );
    });

    test('darkテーマを生成できる', () {
      final theme = AppTheme.dark;

      expect(theme, isA<ThemeData>());
      expect(theme.brightness, Brightness.dark);
      expect(
        theme.appBarTheme.systemOverlayStyle?.statusBarIconBrightness,
        Brightness.light,
      );
      expect(theme.colorScheme.onPrimary, Colors.white);
      expect(
        _contrastRatio(theme.colorScheme.primary, theme.colorScheme.onPrimary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('カスタム色でlightテーマを生成できる', () {
      const customPrimary = Colors.purple;
      const customSecondary = Colors.orange;

      final theme = AppTheme.lightWith(
        primaryColor: customPrimary,
        secondaryColor: customSecondary,
      );

      expect(theme.colorScheme.secondary, customSecondary);
    });

    test('カスタム色でdarkテーマを生成できる', () {
      const customPrimary = Colors.teal;
      const customSecondary = Colors.amber;

      final theme = AppTheme.darkWith(
        primaryColor: customPrimary,
        secondaryColor: customSecondary,
      );

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.secondary, customSecondary);
    });

    test('AppColorsExtensionがテーマに含まれる', () {
      final theme = AppTheme.light;
      final appColors = theme.extension<AppColorsExtension>();

      expect(appColors, isNotNull);
      expect(appColors!.success, isA<Color>());
      expect(appColors.warning, isA<Color>());
      expect(appColors.info, isA<Color>());
    });

    test('lightテーマにDialogThemeが適用される', () {
      final theme = AppTheme.light;

      expect(theme.dialogTheme.elevation, 3);
      final shape = theme.dialogTheme.shape;
      expect(shape, isA<RoundedRectangleBorder>());
      final border = shape! as RoundedRectangleBorder;
      expect(border.borderRadius, BorderRadius.circular(24));
    });
  });

  group('AppColorsExtension', () {
    test('lightファクトリで明るいテーマ用の色を生成できる', () {
      final colors = AppColorsExtension.light();

      expect(colors.success, isA<Color>());
      expect(colors.warning, isA<Color>());
      expect(colors.info, isA<Color>());
      expect(colors.onSuccess, Colors.white);
      expect(colors.onWarning, Colors.white);
      expect(colors.onInfo, Colors.white);
    });

    test('darkファクトリでダークテーマ用の色を生成できる', () {
      final colors = AppColorsExtension.dark();

      expect(colors.success, isA<Color>());
      expect(colors.warning, isA<Color>());
      expect(colors.info, isA<Color>());
      // Bug 3 fix により on* 色は _onColor() で動的計算されるため、
      // 色が存在することのみを検証（輝度に応じて black/white のいずれかになる）
      expect(colors.onSuccess, anyOf(Colors.black, Colors.white));
      expect(colors.onWarning, anyOf(Colors.black, Colors.white));
      expect(colors.onInfo, anyOf(Colors.black, Colors.white));
    });

    test('copyWithで一部の色を変更できる', () {
      final original = AppColorsExtension.light();
      final modified = original.copyWith(success: Colors.green);

      expect(modified.success, Colors.green);
      expect(modified.warning, original.warning);
      expect(modified.info, original.info);
    });

    test('lerpで2つのAppColorsExtension間を補間できる', () {
      final light = AppColorsExtension.light();
      final dark = AppColorsExtension.dark();

      final interpolated = light.lerp(dark, 0.5);

      expect(interpolated, isA<AppColorsExtension>());
      // 補間された色が元の色と異なることを確認
      expect(interpolated.success, isNot(equals(light.success)));
      expect(interpolated.success, isNot(equals(dark.success)));
    });

    test('lerpのtが0の場合は元の値を返す', () {
      final light = AppColorsExtension.light();
      final dark = AppColorsExtension.dark();

      final interpolated = light.lerp(dark, 0.0);

      expect(interpolated.success, light.success);
    });

    test('lerpのtが1の場合はターゲットの値を返す', () {
      final light = AppColorsExtension.light();
      final dark = AppColorsExtension.dark();

      final interpolated = light.lerp(dark, 1.0);

      expect(interpolated.success, dark.success);
    });
  });

  group('AppColorsExtensionGetter', () {
    test('ThemeDataからappColorsにアクセスできる', () {
      final theme = AppTheme.light;
      final appColors = theme.appColors;

      expect(appColors, isA<AppColorsExtension>());
      expect(appColors.success, isA<Color>());
    });

    test('拡張がない場合はデフォルト（light）を返す', () {
      final theme = ThemeData();
      final appColors = theme.appColors;

      // デフォルトのlight extensionが返される
      expect(appColors, isA<AppColorsExtension>());
    });
  });
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
