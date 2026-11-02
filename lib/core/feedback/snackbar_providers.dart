import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'snackbar_config.dart';

part 'snackbar_providers.g.dart';

/// SnackBar設定の状態管理
@Riverpod(keepAlive: true)
class SnackBarConfigNotifier extends _$SnackBarConfigNotifier {
  @override
  SnackBarConfig build() => SnackBarConfig.defaultConfig();

  /// 設定全体を更新
  void updateConfig(SnackBarConfig config) {
    state = config;
  }

  /// デフォルト設定にリセット
  void reset() {
    state = SnackBarConfig.defaultConfig();
  }

  /// 表示動作を変更
  void setBehavior(SnackBarBehavior behavior) {
    state = state.copyWith(behavior: behavior);
  }

  /// 表示位置を変更
  void setPosition(SnackBarPosition position) {
    state = state.copyWith(position: position);
  }

  /// アニメーションタイプを変更
  void setAnimation(SnackBarAnimation animation) {
    state = state.copyWith(animation: animation);
  }

  /// 表示時間を変更
  void setDuration(Duration duration) {
    state = state.copyWith(duration: duration);
  }

  /// 角丸半径を変更
  void setBorderRadius(double radius) {
    state = state.copyWith(borderRadius: radius);
  }

  /// 影の高さを変更
  void setElevation(double elevation) {
    state = state.copyWith(elevation: elevation);
  }

  /// マージンを変更
  void setMargin(EdgeInsets margin) {
    state = state.copyWith(margin: margin);
  }

  /// パディングを変更
  void setPadding(EdgeInsets padding) {
    state = state.copyWith(padding: padding);
  }

  /// アイコン表示の有無を変更
  void setShowIcon(bool show) {
    state = state.copyWith(showIcon: show);
  }

  /// アイコンサイズを変更
  void setIconSize(double size) {
    state = state.copyWith(iconSize: size);
  }

  /// タイプ別の色設定を変更
  void setTypeColors(SnackBarType type, SnackBarTypeColors colors) {
    state = switch (type) {
      SnackBarType.success => state.copyWith(successColors: colors),
      SnackBarType.error => state.copyWith(errorColors: colors),
      SnackBarType.warning => state.copyWith(warningColors: colors),
      SnackBarType.info => state.copyWith(infoColors: colors),
      SnackBarType.defaultType => state.copyWith(defaultColors: colors),
    };
  }

  /// タイプ別の背景色を変更
  void setBackgroundColor(SnackBarType type, Color color) {
    final currentColors = state.getColorsForType(type);
    setTypeColors(type, currentColors.copyWith(background: color));
  }

  /// タイプ別のテキスト色を変更
  void setTextColor(SnackBarType type, Color color) {
    final currentColors = state.getColorsForType(type);
    setTypeColors(type, currentColors.copyWith(text: color));
  }

  /// タイプ別のアイコン色を変更
  void setIconColor(SnackBarType type, Color color) {
    final currentColors = state.getColorsForType(type);
    setTypeColors(type, currentColors.copyWith(icon: color));
  }
}
