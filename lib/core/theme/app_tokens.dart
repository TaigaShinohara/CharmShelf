import 'package:flutter/material.dart';

/// アプリ全体で統一されたUIトークン定義
///
/// デザインシステム（DESIGN.md / CODING_GUIDELINES.md）に基づき、
/// 角丸、余白、アイコンサイズなどを一元管理します。
class AppTokens {
  AppTokens._();
}

/// 角丸トークン (Border Radius)
///
/// スケール:
/// - xs: 4.0 (バッジ、極小タグ)
/// - sm: 8.0 (Chip、小型ボタン、小サムネイル)
/// - md: 12.0 (Button、TextField、ListTile、一般的な入力要素)
/// - lg: 16.0 (Card、セクション枠、標準コンテナ)
/// - xl: 24.0 (Dialog、BottomSheet、フローティングバー)
/// - full: 999.0 (ピル形状、完全な円形)
class AppRadius {
  AppRadius._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 999.0;

  // BorderRadius 定数
  static const BorderRadius radiusXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius radiusSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius radiusXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius radiusFull = BorderRadius.all(
    Radius.circular(full),
  );

  // Top/Bottom等の方向別定数（BottomSheet等用）
  static const BorderRadius topXl = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
  static const BorderRadius topLg = BorderRadius.vertical(
    top: Radius.circular(lg),
  );
}

/// 余白トークン (Spacing / Padding / Margin)
///
/// 8pxグリッドを基本とするスケール:
/// - xs: 4.0
/// - sm: 8.0
/// - md: 12.0 (サブグリッド)
/// - lg: 16.0 (標準画面パディング)
/// - xl: 24.0 (セクション間・ダイアログ内余白)
/// - xxl: 32.0 (大区切り)
/// - xxxl: 40.0 (ヘッダー等の特大余白)
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 40.0;

  // EdgeInsets 定数（オール）
  static const EdgeInsets edgeInsetsXs = EdgeInsets.all(xs);
  static const EdgeInsets edgeInsetsSm = EdgeInsets.all(sm);
  static const EdgeInsets edgeInsetsMd = EdgeInsets.all(md);
  static const EdgeInsets edgeInsetsLg = EdgeInsets.all(lg);
  static const EdgeInsets edgeInsetsXl = EdgeInsets.all(xl);
  static const EdgeInsets edgeInsetsXxl = EdgeInsets.all(xxl);

  // 画面・セクション用パディング
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: sm,
  );
  static const EdgeInsets dialogPadding = EdgeInsets.fromLTRB(xl, xl, xl, lg);
  static const EdgeInsets bottomSheetPadding = EdgeInsets.fromLTRB(
    lg,
    sm,
    lg,
    xl,
  );

  // 水平パディング
  static const EdgeInsets horizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  // 垂直パディング
  static const EdgeInsets verticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);

  // SizedBox ギャップ用
  static const SizedBox gapXs = SizedBox(width: xs, height: xs);
  static const SizedBox gapSm = SizedBox(width: sm, height: sm);
  static const SizedBox gapMd = SizedBox(width: md, height: md);
  static const SizedBox gapLg = SizedBox(width: lg, height: lg);
  static const SizedBox gapXl = SizedBox(width: xl, height: xl);
  static const SizedBox gapXxl = SizedBox(width: xxl, height: xxl);

  // 横方向ギャップ
  static const SizedBox gapHorizontalXs = SizedBox(width: xs);
  static const SizedBox gapHorizontalSm = SizedBox(width: sm);
  static const SizedBox gapHorizontalMd = SizedBox(width: md);
  static const SizedBox gapHorizontalLg = SizedBox(width: lg);
  static const SizedBox gapHorizontalXl = SizedBox(width: xl);

  // 縦方向ギャップ
  static const SizedBox gapVerticalXs = SizedBox(height: xs);
  static const SizedBox gapVerticalSm = SizedBox(height: sm);
  static const SizedBox gapVerticalMd = SizedBox(height: md);
  static const SizedBox gapVerticalLg = SizedBox(height: lg);
  static const SizedBox gapVerticalXl = SizedBox(height: xl);
  static const SizedBox gapVerticalXxl = SizedBox(height: xxl);
}

/// アイコンサイズトークン
class AppIconSize {
  AppIconSize._();

  static const double sm = 16.0;
  static const double md = 20.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double emptyState = 64.0;
}
