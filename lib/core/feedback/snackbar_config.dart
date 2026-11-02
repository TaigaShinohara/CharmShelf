import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// SnackBarのタイプ
enum SnackBarType {
  success(Icons.check_circle_outline, 'success'),
  error(Icons.error_outline, 'error'),
  warning(Icons.warning_amber_outlined, 'warning'),
  info(Icons.info_outline, 'info'),
  defaultType(null, 'default');

  const SnackBarType(this.icon, this.name);
  final IconData? icon;
  final String name;
}

/// SnackBarの表示位置
enum SnackBarPosition { top, bottom }

/// SnackBarのアニメーションタイプ
enum SnackBarAnimation { slide, fade, scale, none }

/// タイプ別のSnackBar色設定
@immutable
class SnackBarTypeColors {
  const SnackBarTypeColors({
    required this.background,
    required this.text,
    required this.icon,
  });

  final Color background;
  final Color text;
  final Color icon;

  SnackBarTypeColors copyWith({Color? background, Color? text, Color? icon}) {
    return SnackBarTypeColors(
      background: background ?? this.background,
      text: text ?? this.text,
      icon: icon ?? this.icon,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SnackBarTypeColors &&
        other.background == background &&
        other.text == text &&
        other.icon == icon;
  }

  @override
  int get hashCode => Object.hash(background, text, icon);
}

/// SnackBarの全体設定
@immutable
class SnackBarConfig {
  const SnackBarConfig({
    required this.successColors,
    required this.errorColors,
    required this.warningColors,
    required this.infoColors,
    required this.defaultColors,
    this.behavior = SnackBarBehavior.floating,
    this.position = SnackBarPosition.bottom,
    this.animation = SnackBarAnimation.slide,
    this.duration = const Duration(seconds: 3),
    this.borderRadius = 8.0,
    this.elevation = 6.0,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 16),
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.showIcon = true,
    this.iconSize = 20.0,
  });

  /// デフォルト設定を生成
  factory SnackBarConfig.defaultConfig() {
    SnackBarTypeColors fromBg(Color bg) {
      final on = bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;
      return SnackBarTypeColors(background: bg, text: on, icon: on);
    }

    return SnackBarConfig(
      successColors: fromBg(AppColors.success),
      errorColors: fromBg(AppColors.error),
      warningColors: fromBg(AppColors.warning),
      infoColors: fromBg(AppColors.info),
      // 既存の見た目（暗め）を保つため、overlay色をベースにする
      defaultColors: fromBg(AppColors.overlay.withValues(alpha: 0.80)),
    );
  }

  /// タイプ別の色設定
  final SnackBarTypeColors successColors;
  final SnackBarTypeColors errorColors;
  final SnackBarTypeColors warningColors;
  final SnackBarTypeColors infoColors;
  final SnackBarTypeColors defaultColors;

  /// 表示動作（floating/fixed）
  final SnackBarBehavior behavior;

  /// 表示位置（top/bottom）
  final SnackBarPosition position;

  /// アニメーションタイプ
  final SnackBarAnimation animation;

  /// 表示時間
  final Duration duration;

  /// 角丸の半径
  final double borderRadius;

  /// 影の高さ
  final double elevation;

  /// 外側マージン
  final EdgeInsets margin;

  /// 内側パディング
  final EdgeInsets padding;

  /// アイコンを表示するか
  final bool showIcon;

  /// アイコンサイズ
  final double iconSize;

  /// タイプに応じた色設定を取得
  SnackBarTypeColors getColorsForType(SnackBarType type) {
    return switch (type) {
      SnackBarType.success => successColors,
      SnackBarType.error => errorColors,
      SnackBarType.warning => warningColors,
      SnackBarType.info => infoColors,
      SnackBarType.defaultType => defaultColors,
    };
  }

  SnackBarConfig copyWith({
    SnackBarTypeColors? successColors,
    SnackBarTypeColors? errorColors,
    SnackBarTypeColors? warningColors,
    SnackBarTypeColors? infoColors,
    SnackBarTypeColors? defaultColors,
    SnackBarBehavior? behavior,
    SnackBarPosition? position,
    SnackBarAnimation? animation,
    Duration? duration,
    double? borderRadius,
    double? elevation,
    EdgeInsets? margin,
    EdgeInsets? padding,
    bool? showIcon,
    double? iconSize,
  }) {
    return SnackBarConfig(
      successColors: successColors ?? this.successColors,
      errorColors: errorColors ?? this.errorColors,
      warningColors: warningColors ?? this.warningColors,
      infoColors: infoColors ?? this.infoColors,
      defaultColors: defaultColors ?? this.defaultColors,
      behavior: behavior ?? this.behavior,
      position: position ?? this.position,
      animation: animation ?? this.animation,
      duration: duration ?? this.duration,
      borderRadius: borderRadius ?? this.borderRadius,
      elevation: elevation ?? this.elevation,
      margin: margin ?? this.margin,
      padding: padding ?? this.padding,
      showIcon: showIcon ?? this.showIcon,
      iconSize: iconSize ?? this.iconSize,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SnackBarConfig &&
        other.successColors == successColors &&
        other.errorColors == errorColors &&
        other.warningColors == warningColors &&
        other.infoColors == infoColors &&
        other.defaultColors == defaultColors &&
        other.behavior == behavior &&
        other.position == position &&
        other.animation == animation &&
        other.duration == duration &&
        other.borderRadius == borderRadius &&
        other.elevation == elevation &&
        other.margin == margin &&
        other.padding == padding &&
        other.showIcon == showIcon &&
        other.iconSize == iconSize;
  }

  @override
  int get hashCode => Object.hash(
    successColors,
    errorColors,
    warningColors,
    infoColors,
    defaultColors,
    behavior,
    position,
    animation,
    duration,
    borderRadius,
    elevation,
    margin,
    padding,
    showIcon,
    iconSize,
  );
}
