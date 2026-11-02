import 'package:flutter/material.dart';

import '../config/app_config.dart';

/// アプリ全体で使用する色定義
///
/// `template_config.yaml` の `theme` セクションから読み込まれた色を使用します。
/// 色を変更する場合は `template_config.yaml` を編集してください。
class AppColors {
  static Color get primary => Color(AppConfig.theme.primaryColor);
  static Color get secondary => Color(AppConfig.theme.secondaryColor);

  static Color get success => Color(AppConfig.theme.successColor);
  static Color get warning => Color(AppConfig.theme.warningColor);
  static Color get error => Color(AppConfig.theme.errorColor);
  static Color get info => Color(AppConfig.theme.infoColor);

  // ===== 追加色（背景・表面など）=====

  /// 画面全体の背景（ベース）
  static Color get background => Color(AppConfig.theme.backgroundColor);

  /// カード/パネルなどの表面色
  static Color get surface => Color(AppConfig.theme.surfaceColor);

  /// Scaffold背景
  static Color get scaffold => Color(AppConfig.theme.scaffoldColor);

  /// 影のベース色（不透明度は利用側で調整）
  static Color get shadow => Color(AppConfig.theme.shadowColor);

  /// オーバーレイのベース色（不透明度は利用側で調整）
  static Color get overlay => Color(AppConfig.theme.overlayColor);

  /// ボーダー/区切り線
  static Color get border => Color(AppConfig.theme.borderColor);

  // ===== テキスト色 =====

  static Color get textPrimary => Color(AppConfig.theme.textPrimaryColor);
  static Color get textSecondary => Color(AppConfig.theme.textSecondaryColor);
  static Color get textDisabled => Color(AppConfig.theme.textDisabledColor);

  // ===== タグ用カラーパレット =====
  static const List<Color> tagColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];
}
