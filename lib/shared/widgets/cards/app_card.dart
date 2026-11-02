import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:private_shelf/core/feedback/haptics_service.dart';
import 'package:private_shelf/core/theme/app_theme.dart';
import 'package:private_shelf/core/theme/app_tokens.dart';

import '../../../core/theme/app_elevations.dart';
import '../../animations/press_animation.dart';

/// 共通カードウィジェット
///
/// 3つのバリエーション:
/// - 標準カード: Level 1 (ボーダー) or Level 2 (影)
/// - インタラクティブカード: タップ時 PressAnimation 付き
/// - フィーチャーカード: グラデーション背景
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = AppRadius.lg,
    this.elevation = AppCardElevation.bordered,
    this.color,
    this.onTap,
    this.border,
    this.gradient,
    this.useGlassmorphism = false,
    this.semanticsLabel,
  });

  /// フィーチャーカード（グラデーション背景）
  const AppCard.feature({
    super.key,
    required this.child,
    required this.gradient,
    this.padding,
    this.margin,
    this.borderRadius = AppRadius.lg,
    this.onTap,
    this.semanticsLabel,
  }) : elevation = AppCardElevation.shadow,
       color = null,
       border = null,
       useGlassmorphism = false;

  /// カードの中身
  final Widget child;

  /// 内部のパディング（デフォルトは 16.0 - AppSpacing.edgeInsetsLg）
  final EdgeInsetsGeometry? padding;

  /// 外部のマージン
  final EdgeInsetsGeometry? margin;

  /// 角丸の半径（標準 16dp - AppRadius.lg）
  final double borderRadius;

  /// エレベーションスタイル
  final AppCardElevation elevation;

  /// 背景色（nullの場合は surface カラー）
  final Color? color;

  /// タップ時の動作
  final VoidCallback? onTap;

  /// 枠線の設定
  final BorderSide? border;

  /// グラデーション背景（フィーチャーカード用）
  final Gradient? gradient;

  /// グラスモーフィズム（背景ぼかし）を適用するかどうか
  final bool useGlassmorphism;

  /// アクセシビリティラベル（スクリーンリーダー用。null のときは子の意味に委ねる）
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = color ?? theme.colorScheme.surface;

    Widget current = Padding(
      padding: padding ?? AppSpacing.edgeInsetsLg,
      child: child,
    );

    if (onTap != null) {
      current = PressAnimation(
        pressedScale: 0.97,
        child: Semantics(
          button: true,
          enabled: true,
          label: semanticsLabel,
          child: InkWell(
            enableFeedback: false,
            onTap: () {
              unawaited(HapticsService.lightTap());
              onTap?.call();
            },
            borderRadius: BorderRadius.circular(borderRadius),
            child: current,
          ),
        ),
      );
    }

    // グラデーション背景の場合は Container を使用
    if (gradient != null) {
      return Padding(
        padding: margin ?? EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: AppElevations.level2(context),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(type: MaterialType.transparency, child: current),
        ),
      );
    }

    // DESIGN.md「エレベーション」: Level 1 = ボーダー, Level 2 = 影
    final useShadow = elevation == AppCardElevation.shadow;

    final glassFillAlpha = theme.brightness == Brightness.dark ? 0.48 : 0.72;
    Widget cardBody = Container(
      decoration: BoxDecoration(
        color: useGlassmorphism
            ? (color ?? theme.colorScheme.surface).withValues(
                alpha: glassFillAlpha,
              )
            : cardColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: (useShadow || useGlassmorphism)
            ? null
            : Border.all(
                color:
                    border?.color ??
                    theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: border?.width ?? 1.0,
              ),
        boxShadow: (useShadow && !useGlassmorphism)
            ? AppElevations.level2(context)
            : null,
      ),
      clipBehavior: Clip.none, // 二重クリップを防ぐため、ここではクリップしない
      child: Material(type: MaterialType.transparency, child: current),
    );

    if (useGlassmorphism) {
      final isDark = theme.brightness == Brightness.dark;
      cardBody = Stack(
        clipBehavior: Clip.none,
        children: [
          // 【物理的解決】影レイヤー:
          // カードの上端から borderRadius (16-20px) 分ほど下げて開始することで、
          // 影の発生源自体を上部境界から遠ざけます。
          // これにより、たとえ深いぼかしを設定しても上部へ影が回り込むことを物理的に防ぎます。
          Positioned(
            top: borderRadius * 2, // 32-40px下げることで、上端へのぼかし干渉を完全に防ぐ
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                boxShadow: AppElevations.liquidGlassShadow(context),
              ),
            ),
          ),
          // 実体レイヤー: グラスモーフィズム効果
          ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Stack(
              children: [
                // 背景ぼかし（オーバーサイズ配置）:
                // ぼかしの計算誤差（ノイズ）が出やすい境界部を、
                // カードの実際のサイズより外側に追い出してからクリップします。
                Positioned(
                  top: -10,
                  left: -10,
                  right: -10,
                  bottom: -10,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: AppElevations.glassBlurSigma,
                      sigmaY: AppElevations.glassBlurSigma,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                // 本体レイヤー
                cardBody,
                // インナーグロウ（上部の反射効果）
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(borderRadius),
                        border: Border.all(
                          color: theme.appColors.glassBorder,
                          width: 0.5,
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(
                              alpha: isDark ? 0.08 : 0.15,
                            ),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.4],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Padding(padding: margin ?? EdgeInsets.zero, child: cardBody);
  }
}

/// カードのエレベーションスタイル
enum AppCardElevation {
  /// Level 1: ボーダーのみ（影なし）— デフォルト
  bordered,

  /// Level 2: 軽い影
  shadow,
}
