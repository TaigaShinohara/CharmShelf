import 'package:flutter/material.dart';

/// DESIGN.md「エレベーション & Liquid Glass」に基づくエレベーション & 深度システム
///
/// 5段階のエレベーションレベルを定義し、
/// サーフェスの浮遊感を統一的に表現する。
///
/// 使用例:
/// ```dart
/// Container(
///   decoration: BoxDecoration(
///     boxShadow: AppElevations.level2(context),
///     borderRadius: BorderRadius.circular(16),
///   ),
/// )
/// ```
class AppElevations {
  AppElevations._();

  // ===== エレベーションレベル =====

  /// Level 0: 影なし。インライン要素、テキスト
  static List<BoxShadow> level0(BuildContext context) => const [];

  /// Level 1: ボーダーのみ（影なし）。標準カード
  /// ※ ボーダーは BoxDecoration.border で指定するため、ここでは空リスト
  static List<BoxShadow> level1(BuildContext context) => const [];

  /// Level 2: 軽い影。浮遊カード、ドロップダウン
  static List<BoxShadow> level2(BuildContext context) {
    final theme = Theme.of(context);
    return level2ForTheme(theme);
  }

  /// Level 2: ThemeData を受ける純関数版
  static List<BoxShadow> level2ForTheme(ThemeData theme) {
    final shadowColor = _shadowColor(theme);
    return [
      BoxShadow(
        color: shadowColor.withValues(alpha: _alphaBase(theme)),
        blurRadius: 8,
        spreadRadius: 0,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// Level 3: 中程度の影。BottomSheet, ダイアログ
  static List<BoxShadow> level3(BuildContext context) {
    final theme = Theme.of(context);
    return level3ForTheme(theme);
  }

  /// Level 3: ThemeData を受ける純関数版
  static List<BoxShadow> level3ForTheme(ThemeData theme) {
    final shadowColor = _shadowColor(theme);
    return [
      BoxShadow(
        color: shadowColor.withValues(alpha: _alphaBase(theme) * 1.5),
        blurRadius: 16,
        spreadRadius: 2,
        offset: const Offset(0, 4),
      ),
    ];
  }

  /// Level 4: 強い影。モーダル、オーバーレイ
  static List<BoxShadow> level4(BuildContext context) {
    final theme = Theme.of(context);
    return level4ForTheme(theme);
  }

  /// Level 4: ThemeData を受ける純関数版
  static List<BoxShadow> level4ForTheme(ThemeData theme) {
    final shadowColor = _shadowColor(theme);
    return [
      BoxShadow(
        color: shadowColor.withValues(alpha: _alphaBase(theme) * 2),
        blurRadius: 24,
        spreadRadius: 4,
        offset: const Offset(0, 8),
      ),
    ];
  }

  /// Liquid Glass: プレミアムな多重影。DESIGN.md「Liquid Glass」準拠
  /// AppCard 側の物理構造（オフセット配置）により、上部への漏れを防ぎつつ豊かな影を実現します。
  static List<BoxShadow> liquidGlassShadow(BuildContext context) {
    final theme = Theme.of(context);
    return liquidGlassShadowForTheme(theme);
  }

  /// Liquid Glass: ThemeData を受ける純関数版
  static List<BoxShadow> liquidGlassShadowForTheme(ThemeData theme) {
    final shadowColor = _shadowColor(theme);
    final a = _alphaBase(theme);
    final isDark = theme.brightness == Brightness.dark;
    final glow = theme.colorScheme.primary;
    return [
      // 基礎層 (Base): 深く柔らかな影
      BoxShadow(
        color: shadowColor.withValues(alpha: a * 1.5),
        blurRadius: 32,
        spreadRadius: -4,
        offset: const Offset(0, 16),
      ),
      // 詳細層 (Detail): 輪郭を強調する影
      BoxShadow(
        color: shadowColor.withValues(alpha: a),
        blurRadius: 12,
        spreadRadius: -2,
        offset: const Offset(0, 4),
      ),
      // 深海: シアン系の外縁グロー（ダークで強め）
      if (isDark)
        BoxShadow(
          color: glow.withValues(alpha: 0.22),
          blurRadius: 24,
          spreadRadius: -2,
          offset: const Offset(0, 8),
        ),
    ];
  }

  /// Hero要素用のプレミアムな多重影（カラーグロー）。
  /// ボタンの色味（primary/secondary）を反映し、背景から強く浮かび上がらせます。
  static List<BoxShadow> heroGlowShadow(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return [
      // 1. 基礎（深い影）
      BoxShadow(
        color: theme.shadowColor.withValues(alpha: isDark ? 0.4 : 0.15),
        blurRadius: 32,
        spreadRadius: -4,
        offset: const Offset(0, 16),
      ),
      // 2. カラーグロー（現在の Theme ColorScheme で発光。パレット切替でも追従する）
      BoxShadow(
        color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.42 : 0.2),
        blurRadius: isDark ? 28 : 24,
        spreadRadius: isDark ? 1 : 2,
        offset: const Offset(-8, 4),
      ),
      BoxShadow(
        color: theme.colorScheme.secondary.withValues(
          alpha: isDark ? 0.32 : 0.2,
        ),
        blurRadius: isDark ? 28 : 24,
        spreadRadius: isDark ? 1 : 2,
        offset: const Offset(8, 4),
      ),
    ];
  }

  // ===== グラスモーフィズム =====

  /// グラスモーフィズム用の半透明背景色
  /// DESIGN.md「Liquid Glass」: 薄い半透明背景の基本ユーティリティ
  static Color glassBackground(BuildContext context, {double opacity = 0.8}) {
    return glassBackgroundFromColorScheme(
      Theme.of(context).colorScheme,
      opacity: opacity,
    );
  }

  /// グラスモーフィズム用の半透明背景色（ColorScheme を受ける純関数版）
  static Color glassBackgroundFromColorScheme(
    ColorScheme colorScheme, {
    double opacity = 0.8,
  }) {
    final base = colorScheme.surface.withValues(alpha: opacity);
    if (colorScheme.brightness == Brightness.dark) {
      // ガラス面: 白を薄く重ね、Figmaボード寄りのフロスト感に
      return Color.alphaBlend(
        const Color(0xFFFFFFFF).withValues(alpha: 0.08),
        base,
      );
    }
    return base;
  }

  /// グラスモーフィズム推奨の blur sigma
  /// DESIGN.md「Liquid Glass」: 薄ガラスの推奨 sigma 値
  /// プレミアムガラス向けにやや強め（背景のぼかしがはっきり見える）
  static const double glassBlurSigma = 14.0;

  /// グラスモーフィズム用の標準的な透過度（サーフェス用）
  static const double glassSurfaceOpacity = 0.40;

  /// グラスモーフィズム用の標準的な透過度（オーバーレイ用/薄め）
  static const double glassThinOpacity = 0.20;

  /// Liquid Glass 共通の装飾スタイルを取得
  ///
  /// ヘッダーやカードなど、アプリ全体で統一されたガラス質感を適用するために使用します。
  static BoxDecoration glassDecoration(
    BuildContext context, {
    double opacity = glassSurfaceOpacity,
    double? borderRadius,
    bool showBorder = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: glassBackground(context, opacity: opacity),
      borderRadius: borderRadius != null
          ? BorderRadius.circular(borderRadius)
          : null,
      border: showBorder
          ? Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 0.5,
            )
          : null,
    );
  }

  // ===== ヘルパー =====

  /// 影の基本不透明度。ダークモードでは濃くする
  /// DESIGN.md「ダークモード方針」: Light / Dark で影の濃さを調整
  static double _alphaBase(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return isDark ? 0.24 : 0.08;
  }

  /// 影のベース色
  static Color _shadowColor(ThemeData theme) {
    return theme.shadowColor;
  }
}

/// Level 1 カード用のボーダーを取得するヘルパー
/// DESIGN.md「エレベーション」: Level 1 カード境界
BorderSide cardBorder(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return cardBorderFromColorScheme(colorScheme);
}

/// Level 1 カード用のボーダー（ColorScheme を受ける純関数版）
BorderSide cardBorderFromColorScheme(ColorScheme colorScheme) {
  return BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5));
}
