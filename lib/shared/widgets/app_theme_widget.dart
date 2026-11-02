import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';

/// Wear OS アプリ用のテーマ適用ウィジェット
///
/// `MaterialApp` を構築し、アプリ全体のテーマを設定します。
class AppThemeWidget extends StatelessWidget {
  const AppThemeWidget({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system, // Wear OS は通常ダークモードだが、システム設定に従う
      home: child,
    );
  }
}
