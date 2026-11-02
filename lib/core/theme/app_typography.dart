import 'package:flutter/material.dart';

/// アプリのタイポグラフィ定義
///
/// Material Design 3 のタイプスケールに基づいた
/// フォントスタイルを定義します。
///
/// 使用例:
/// ```dart
/// // TextTheme 経由
/// Theme.of(context).textTheme.headlineLarge
/// Theme.of(context).textTheme.bodyMedium
///
/// // AppTypography の定数
/// AppTypography.displayLarge
/// ```
class AppTypography {
  AppTypography._();

  // ===== フォントファミリー =====
  // カスタムフォントを使用する場合はここを変更
  // pubspec.yaml にフォントを追加し、ファミリー名を指定
  static const String? _fontFamily = null; // null = システムデフォルト

  // ===== タイプスケール定義 =====
  // Material Design 3 Type Scale

  // Display
  static const TextStyle displayLarge = TextStyle(
    fontSize: 57,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.25,
    height: 1.12,
    fontFamily: _fontFamily,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 45,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.16,
    fontFamily: _fontFamily,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.22,
    fontFamily: _fontFamily,
  );

  // Headline
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.25,
    fontFamily: _fontFamily,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.29,
    fontFamily: _fontFamily,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.33,
    fontFamily: _fontFamily,
  );

  // Title
  static const TextStyle titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.27,
    fontFamily: _fontFamily,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
    height: 1.50,
    fontFamily: _fontFamily,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.43,
    fontFamily: _fontFamily,
  );

  // Label
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.43,
    fontFamily: _fontFamily,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.33,
    fontFamily: _fontFamily,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.45,
    fontFamily: _fontFamily,
  );

  // Body
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    height: 1.50,
    fontFamily: _fontFamily,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.43,
    fontFamily: _fontFamily,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.33,
    fontFamily: _fontFamily,
  );

  /// TextTheme を生成
  ///
  /// ColorScheme を受け取り、適切な色を設定した TextTheme を返します。
  static TextTheme textTheme(ColorScheme colorScheme) {
    return TextTheme(
      displayLarge: displayLarge.copyWith(color: colorScheme.onSurface),
      displayMedium: displayMedium.copyWith(color: colorScheme.onSurface),
      displaySmall: displaySmall.copyWith(color: colorScheme.onSurface),
      headlineLarge: headlineLarge.copyWith(color: colorScheme.onSurface),
      headlineMedium: headlineMedium.copyWith(color: colorScheme.onSurface),
      headlineSmall: headlineSmall.copyWith(color: colorScheme.onSurface),
      titleLarge: titleLarge.copyWith(color: colorScheme.onSurface),
      titleMedium: titleMedium.copyWith(color: colorScheme.onSurface),
      titleSmall: titleSmall.copyWith(color: colorScheme.onSurface),
      labelLarge: labelLarge.copyWith(color: colorScheme.onSurface),
      labelMedium: labelMedium.copyWith(color: colorScheme.onSurfaceVariant),
      labelSmall: labelSmall.copyWith(color: colorScheme.onSurfaceVariant),
      bodyLarge: bodyLarge.copyWith(color: colorScheme.onSurface),
      bodyMedium: bodyMedium.copyWith(color: colorScheme.onSurface),
      bodySmall: bodySmall.copyWith(color: colorScheme.onSurfaceVariant),
    );
  }
}

/// テキストスタイルの拡張
///
/// 使用例:
/// ```dart
/// Theme.of(context).textTheme.bodyMedium?.semiBold
/// Theme.of(context).textTheme.bodyMedium?.withOpacity(0.7)
/// ```
extension TextStyleExtensions on TextStyle {
  /// セミボールド
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);

  /// ボールド
  TextStyle get bold => copyWith(fontWeight: FontWeight.w700);

  /// イタリック
  TextStyle get italic => copyWith(fontStyle: FontStyle.italic);

  /// 下線
  TextStyle get underline => copyWith(decoration: TextDecoration.underline);

  /// 透明度を設定
  TextStyle withOpacity(double opacity) {
    return copyWith(color: color?.withValues(alpha: opacity));
  }

  /// 行の高さを設定
  TextStyle withHeight(double height) {
    return copyWith(height: height);
  }

  /// 字間を設定
  TextStyle withLetterSpacing(double letterSpacing) {
    return copyWith(letterSpacing: letterSpacing);
  }
}
