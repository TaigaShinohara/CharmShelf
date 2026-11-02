import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../system/system_ui_service.dart';
import 'app_colors.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

/// アプリテーマ定義
///
/// ライト/ダークモードの両方に対応。
/// カスタム色（success, warning, info）は `AppColorsExtension` で管理。
/// タイポグラフィは `AppTypography` で管理。
class AppTheme {
  static ThemeData get light => lightWith();

  static ThemeData get dark => darkWith();

  /// カスタム色を指定してライトテーマを生成
  static ThemeData lightWith({
    Color? primaryColor,
    Color? secondaryColor,
    bool isExternalMode = false,
  }) {
    // 外部参照モードの場合はオレンジ、それ以外は引数またはデフォルト
    final primary = isExternalMode
        ? Colors.orange
        : (primaryColor ?? AppColors.primary);
    final secondary = secondaryColor ?? AppColors.secondary;

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          secondary: secondary,
          brightness: Brightness.light,
        ).copyWith(
          // プライマリ系を青で統一
          primary: primary,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFDCE5F0), // 彩度を抑えた青灰コンテナ
          onPrimaryContainer: const Color(0xFF29415F),
          // セカンダリ系
          secondary: secondary,
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFE1E8F0), // 彩度を抑えた青灰セカンダリ
          onSecondaryContainer: const Color(0xFF29415F),
          // ターシャリも青系で揃える（紫に振れないように）
          tertiary: const Color(0xFF4F719D),
          tertiaryContainer: const Color(0xFFDCE5F0),
          onTertiaryContainer: const Color(0xFF29415F),
          // サーフェス系
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          onSurfaceVariant: AppColors.textSecondary,
          surfaceContainerHighest: const Color(0xFFE8EDF8),
          // エラー・アウトライン
          error: AppColors.error,
          outline: AppColors.border,
          outlineVariant: AppColors.border.withValues(alpha: 0.5),
          shadow: AppColors.shadow,
          scrim: AppColors.overlay,
        );

    final textTheme = AppTypography.textTheme(colorScheme);

    return ThemeData(
      useMaterial3: AppConfig.theme.useMaterial3,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.scaffold,
      shadowColor: AppColors.shadow,
      textTheme: textTheme,
      extensions: [AppColorsExtension.light()],
      // ボタンスタイル
      filledButtonTheme: _filledButtonTheme(colorScheme),
      outlinedButtonTheme: _outlinedButtonTheme(colorScheme),
      textButtonTheme: _textButtonTheme(colorScheme),
      elevatedButtonTheme: _elevatedButtonTheme(colorScheme),
      // カードスタイル
      cardTheme: _cardTheme(colorScheme),
      // 入力フィールドスタイル
      inputDecorationTheme: _inputDecorationTheme(colorScheme),
      // AppBarスタイル
      appBarTheme: _appBarTheme(colorScheme, Brightness.light),
      // BottomNavigationBarスタイル
      bottomNavigationBarTheme: _bottomNavigationBarTheme(colorScheme),
      // NavigationBarスタイル（Material3）
      navigationBarTheme: _navigationBarTheme(colorScheme),
      // ListTileスタイル
      listTileTheme: _listTileTheme(colorScheme),
      // Dividerスタイル
      dividerTheme: _dividerTheme(colorScheme),
      // SnackBarスタイル
      snackBarTheme: _snackBarTheme(colorScheme),
      // Dialogスタイル
      dialogTheme: _dialogTheme(colorScheme),
      // Chipスタイル
      chipTheme: _chipTheme(colorScheme),
      // ポップアップメニュースタイル
      popupMenuTheme: _popupMenuTheme(colorScheme),
      // 画面遷移アニメーションの最適化
      pageTransitionsTheme: _pageTransitionsTheme(),
    );
  }

  /// カスタム色を指定してダークテーマを生成
  static ThemeData darkWith({
    Color? primaryColor,
    Color? secondaryColor,
    bool isExternalMode = false,
  }) {
    // 外部参照モードの場合はオレンジ、それ以外は引数またはデフォルト
    final primary = isExternalMode
        ? Colors.orange
        : (primaryColor ?? AppColors.primary);
    final secondary = secondaryColor ?? AppColors.secondary;

    Color darkSurface(Color light, {required double amount}) {
      // amount: 0.0(黒)〜1.0(元の色)
      return Color.lerp(Colors.black, light, amount) ?? light;
    }

    Color lightText(Color light, {required double amount}) {
      // amount: 0.0(白)〜1.0(元の色)
      return Color.lerp(Colors.white, light, amount) ?? light;
    }

    final surface = darkSurface(AppColors.surface, amount: 0.10);
    final scaffold = darkSurface(AppColors.scaffold, amount: 0.06);
    final border = darkSurface(AppColors.border, amount: 0.15);
    final textPrimary = lightText(AppColors.textPrimary, amount: 0.20);
    final textSecondary = lightText(AppColors.textSecondary, amount: 0.35);

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          secondary: secondary,
          brightness: Brightness.dark,
        ).copyWith(
          // プライマリ系を青で統一
          primary: primary,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFF29415F),
          onPrimaryContainer: const Color(0xFFDCE5F0),
          // セカンダリ系
          secondary: secondary,
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFF2D405A),
          onSecondaryContainer: const Color(0xFFE1E8F0),
          // ターシャリも青系で揃える
          tertiary: const Color(0xFF82A1C9),
          tertiaryContainer: const Color(0xFF29415F),
          onTertiaryContainer: const Color(0xFFDCE5F0),
          // サーフェス系
          error: AppColors.error,
          surface: surface,
          onSurface: textPrimary,
          onSurfaceVariant: textSecondary,
          outline: border,
          outlineVariant: border.withValues(alpha: 0.7),
          shadow: AppColors.shadow,
          scrim: AppColors.overlay,
        );

    final textTheme = AppTypography.textTheme(colorScheme);

    return ThemeData(
      useMaterial3: AppConfig.theme.useMaterial3,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffold,
      shadowColor: AppColors.shadow,
      textTheme: textTheme,
      extensions: [AppColorsExtension.dark()],
      // ボタンスタイル
      filledButtonTheme: _filledButtonTheme(colorScheme),
      outlinedButtonTheme: _outlinedButtonTheme(colorScheme),
      textButtonTheme: _textButtonTheme(colorScheme),
      elevatedButtonTheme: _elevatedButtonTheme(colorScheme),
      // カードスタイル
      cardTheme: _cardTheme(colorScheme),
      // 入力フィールドスタイル
      inputDecorationTheme: _inputDecorationTheme(colorScheme),
      // AppBarスタイル
      appBarTheme: _appBarTheme(colorScheme, Brightness.dark),
      // BottomNavigationBarスタイル
      bottomNavigationBarTheme: _bottomNavigationBarTheme(colorScheme),
      // NavigationBarスタイル（Material3）
      navigationBarTheme: _navigationBarTheme(colorScheme),
      // ListTileスタイル
      listTileTheme: _listTileTheme(colorScheme),
      // Dividerスタイル
      dividerTheme: _dividerTheme(colorScheme),
      // SnackBarスタイル
      snackBarTheme: _snackBarTheme(colorScheme),
      // Dialogスタイル
      dialogTheme: _dialogTheme(colorScheme),
      // Chipスタイル
      chipTheme: _chipTheme(colorScheme),
      // ポップアップメニュースタイル
      popupMenuTheme: _popupMenuTheme(colorScheme),
      // 画面遷移アニメーションの最適化
      pageTransitionsTheme: _pageTransitionsTheme(),
    );
  }

  // ===== 画面遷移スタイル =====

  static PageTransitionsTheme _pageTransitionsTheme() {
    return const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
      },
    );
  }

  // ===== ボタンスタイル =====

  static FilledButtonThemeData _filledButtonTheme(ColorScheme colorScheme) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(ColorScheme colorScheme) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
        side: BorderSide(color: colorScheme.outline),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme(ColorScheme colorScheme) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusSm),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme(ColorScheme colorScheme) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
        elevation: 2,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ===== カードスタイル =====

  static CardThemeData _cardTheme(ColorScheme colorScheme) {
    return CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.radiusLg,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      color: colorScheme.surface,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      shadowColor: colorScheme.shadow.withValues(alpha: 0.1),
    );
  }

  // ===== 入力フィールドスタイル =====

  static InputDecorationTheme _inputDecorationTheme(ColorScheme colorScheme) {
    return InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      border: const OutlineInputBorder(
        borderRadius: AppRadius.radiusMd,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.radiusMd,
        borderSide: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.radiusMd,
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.radiusMd,
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.radiusMd,
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      hintStyle: TextStyle(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      floatingLabelStyle: TextStyle(
        color: colorScheme.primary,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // ===== AppBarスタイル =====

  static AppBarTheme _appBarTheme(
    ColorScheme colorScheme,
    Brightness brightness,
  ) {
    return AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: true,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      // AppBar itself creates an AnnotatedRegion and therefore takes priority
      // over the app-level System UI style. Keep the platform icons in sync
      // here as well so light AppBars never retain white status-bar icons.
      systemOverlayStyle: SystemUIService.overlayStyleFor(
        brightness,
        navigationBarColor: colorScheme.surface,
      ),
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurface),
    );
  }

  // ===== BottomNavigationBarスタイル =====

  static BottomNavigationBarThemeData _bottomNavigationBarTheme(
    ColorScheme colorScheme,
  ) {
    return BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      backgroundColor: colorScheme.surface,
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: colorScheme.onSurfaceVariant,
      elevation: 8,
      selectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  // ===== NavigationBarスタイル（Material3）=====

  static NavigationBarThemeData _navigationBarTheme(ColorScheme colorScheme) {
    return NavigationBarThemeData(
      indicatorColor: colorScheme.primaryContainer,
      backgroundColor: colorScheme.surface,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: colorScheme.onPrimaryContainer);
        }
        return IconThemeData(color: colorScheme.onSurfaceVariant);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSecondaryContainer,
          );
        }
        return TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurfaceVariant,
        );
      }),
    );
  }

  // ===== ListTileスタイル =====

  static ListTileThemeData _listTileTheme(ColorScheme colorScheme) {
    return ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
      titleTextStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      subtitleTextStyle: TextStyle(
        fontSize: 14,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }

  // ===== Dividerスタイル =====

  static DividerThemeData _dividerTheme(ColorScheme colorScheme) {
    return DividerThemeData(
      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
      thickness: 1,
      space: 1,
    );
  }

  // ===== SnackBarスタイル =====

  static SnackBarThemeData _snackBarTheme(ColorScheme colorScheme) {
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
      actionTextColor: colorScheme.inversePrimary,
    );
  }

  // ===== Dialogスタイル =====

  static DialogThemeData _dialogTheme(ColorScheme colorScheme) {
    return DialogThemeData(
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
      backgroundColor: colorScheme.surface,
      elevation: 3,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      contentTextStyle: TextStyle(
        fontSize: 14,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }

  // ===== Chipスタイル =====

  static ChipThemeData _chipTheme(ColorScheme colorScheme) {
    return ChipThemeData(
      backgroundColor: colorScheme.surfaceContainerHighest,
      selectedColor: colorScheme.secondaryContainer,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusSm),
      labelStyle: TextStyle(fontSize: 14, color: colorScheme.onSurface),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
    );
  }

  // ===== ポップアップメニュースタイル =====

  static PopupMenuThemeData _popupMenuTheme(ColorScheme colorScheme) {
    return PopupMenuThemeData(
      color: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.radiusLg,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: 0.5,
        ),
      ),
      textStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      iconColor: colorScheme.onSurfaceVariant,
      iconSize: AppIconSize.md,
    );
  }
}

/// カスタム色のための ThemeExtension
///
/// success, warning, info などの色をテーマに組み込み、
/// ライト/ダークモードで適切な色調整を行う。
@immutable
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  const AppColorsExtension({
    required this.background,
    required this.surface,
    required this.scaffold,
    required this.shadow,
    required this.overlay,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.success,
    required this.warning,
    required this.info,
    required this.successContainer,
    required this.warningContainer,
    required this.infoContainer,
    required this.onSuccess,
    required this.onWarning,
    required this.onInfo,
    required this.glass,
    required this.glassBorder,
  });

  final Color background;
  final Color surface;
  final Color scaffold;
  final Color shadow;
  final Color overlay;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;

  // グラスモフィズム用
  final Color glass;
  final Color glassBorder;

  /// ライトモード用のカスタム色
  factory AppColorsExtension.light() {
    final onSuccess = _onColor(AppColors.success);
    final onWarning = _onColor(AppColors.warning);
    final onInfo = _onColor(AppColors.info);

    return AppColorsExtension(
      background: AppColors.background,
      surface: AppColors.surface,
      scaffold: AppColors.scaffold,
      shadow: AppColors.shadow,
      overlay: AppColors.overlay,
      border: AppColors.border,
      textPrimary: AppColors.textPrimary,
      textSecondary: AppColors.textSecondary,
      textDisabled: AppColors.textDisabled,
      success: AppColors.success,
      warning: AppColors.warning,
      info: AppColors.info,
      successContainer: AppColors.success.withValues(alpha: 0.12),
      warningContainer: AppColors.warning.withValues(alpha: 0.12),
      infoContainer: AppColors.info.withValues(alpha: 0.12),
      onSuccess: onSuccess,
      onWarning: onWarning,
      onInfo: onInfo,
      glass: Colors.white.withValues(alpha: 0.7),
      glassBorder: Colors.white.withValues(alpha: 0.2),
    );
  }

  /// ダークモード用のカスタム色（明度を調整）
  factory AppColorsExtension.dark() {
    // ダークモードでは色を少し明るくして視認性を確保
    final success = _brightenForDark(AppColors.success);
    final warning = _brightenForDark(AppColors.warning);
    final info = _brightenForDark(AppColors.info);

    final background = _darkSurfaceFromLight(
      AppColors.background,
      amount: 0.08,
    );
    final surface = _darkSurfaceFromLight(AppColors.surface, amount: 0.10);
    final scaffold = _darkSurfaceFromLight(AppColors.scaffold, amount: 0.06);
    final border = _darkSurfaceFromLight(AppColors.border, amount: 0.15);
    final textPrimary = _lightTextFromLight(
      AppColors.textPrimary,
      amount: 0.20,
    );
    final textSecondary = _lightTextFromLight(
      AppColors.textSecondary,
      amount: 0.35,
    );
    final textDisabled = _lightTextFromLight(
      AppColors.textDisabled,
      amount: 0.55,
    );

    // Bug 3 fix: light側と同様に _onColor() で動的に計算する
    final onSuccess = _onColor(success);
    final onWarning = _onColor(warning);
    final onInfo = _onColor(info);

    return AppColorsExtension(
      background: background,
      surface: surface,
      scaffold: scaffold,
      shadow: AppColors.shadow,
      overlay: AppColors.overlay,
      border: border,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      textDisabled: textDisabled,
      success: success,
      warning: warning,
      info: info,
      successContainer: success.withValues(alpha: 0.24),
      warningContainer: warning.withValues(alpha: 0.24),
      infoContainer: info.withValues(alpha: 0.24),
      onSuccess: onSuccess,
      onWarning: onWarning,
      onInfo: onInfo,
      glass: Colors.black.withValues(alpha: 0.3),
      glassBorder: Colors.white.withValues(alpha: 0.1),
    );
  }

  /// ダークモード用に（アクセント色の）明度を調整
  static Color _brightenForDark(Color color) {
    final hsl = HSLColor.fromColor(color);
    // 明度を少し上げる（最大0.85まで）
    final adjustedLightness = (hsl.lightness + 0.15).clamp(0.0, 0.85);
    return hsl.withLightness(adjustedLightness).toColor();
  }

  /// light側のサーフェス色を、ダークテーマ用に「黒へ寄せる」ことで自動生成
  ///
  /// - amount: 0.0(黒)〜1.0(元の色)
  static Color _darkSurfaceFromLight(Color light, {required double amount}) {
    return Color.lerp(Colors.black, light, amount) ?? light;
  }

  /// light側のテキスト色を、ダークテーマ用に「白へ寄せる」ことで自動生成
  ///
  /// - amount: 0.0(白)〜1.0(元の色)
  static Color _lightTextFromLight(Color light, {required double amount}) {
    return Color.lerp(Colors.white, light, amount) ?? light;
  }

  static Color _onColor(Color bg) {
    return bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  final Color success;
  final Color warning;
  final Color info;
  final Color successContainer;
  final Color warningContainer;
  final Color infoContainer;
  final Color onSuccess;
  final Color onWarning;
  final Color onInfo;

  @override
  AppColorsExtension copyWith({
    Color? background,
    Color? surface,
    Color? scaffold,
    Color? shadow,
    Color? overlay,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? success,
    Color? warning,
    Color? info,
    Color? successContainer,
    Color? warningContainer,
    Color? infoContainer,
    Color? onSuccess,
    Color? onWarning,
    Color? onInfo,
    Color? glass,
    Color? glassBorder,
  }) {
    return AppColorsExtension(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      scaffold: scaffold ?? this.scaffold,
      shadow: shadow ?? this.shadow,
      overlay: overlay ?? this.overlay,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      successContainer: successContainer ?? this.successContainer,
      warningContainer: warningContainer ?? this.warningContainer,
      infoContainer: infoContainer ?? this.infoContainer,
      onSuccess: onSuccess ?? this.onSuccess,
      onWarning: onWarning ?? this.onWarning,
      onInfo: onInfo ?? this.onInfo,
      glass: glass ?? this.glass,
      glassBorder: glassBorder ?? this.glassBorder,
    );
  }

  @override
  AppColorsExtension lerp(AppColorsExtension? other, double t) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      scaffold: Color.lerp(scaffold, other.scaffold, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
    );
  }
}

/// ThemeData から AppColorsExtension に簡単にアクセスするための拡張
///
/// 使用例:
/// ```dart
/// // テーマカラー
/// Theme.of(context).colorScheme.primary
/// Theme.of(context).colorScheme.secondary
///
/// // カスタム色
/// Theme.of(context).appColors.success
/// Theme.of(context).appColors.warning
/// Theme.of(context).appColors.info
/// ```
extension AppColorsExtensionGetter on ThemeData {
  AppColorsExtension get appColors =>
      extension<AppColorsExtension>() ?? AppColorsExtension.light();
}
