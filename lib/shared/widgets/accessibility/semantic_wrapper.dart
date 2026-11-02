import 'package:flutter/material.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

/// アクセシビリティ用のセマンティクスラッパー
///
/// ウィジェットにセマンティクス情報を追加し、
/// スクリーンリーダーでの読み上げを改善します。
///
/// 使用例:
/// ```dart
/// SemanticWrapper(
///   label: '設定メニューを開く',
///   hint: 'ダブルタップで開きます',
///   isButton: true,
///   child: IconButton(
///     onPressed: () {},
///     icon: Icon(Icons.settings),
///   ),
/// )
/// ```
class SemanticWrapper extends StatelessWidget {
  const SemanticWrapper({
    super.key,
    required this.child,
    this.label,
    this.hint,
    this.value,
    this.isButton = false,
    this.isLink = false,
    this.isHeader = false,
    this.isImage = false,
    this.isSlider = false,
    this.isTextField = false,
    this.isReadOnly = false,
    this.isHidden = false,
    this.onTap,
    this.onLongPress,
    this.excludeSemantics = false,
  });

  /// 子ウィジェット
  final Widget child;

  /// ラベル（読み上げられる内容）
  final String? label;

  /// ヒント（操作方法の説明）
  final String? hint;

  /// 現在の値（スライダーなど）
  final String? value;

  /// ボタンとして識別
  final bool isButton;

  /// リンクとして識別
  final bool isLink;

  /// ヘッダーとして識別
  final bool isHeader;

  /// 画像として識別
  final bool isImage;

  /// スライダーとして識別
  final bool isSlider;

  /// テキストフィールドとして識別
  final bool isTextField;

  /// 読み取り専用
  final bool isReadOnly;

  /// スクリーンリーダーから隠す
  final bool isHidden;

  /// タップ時のアクション
  final VoidCallback? onTap;

  /// 長押し時のアクション
  final VoidCallback? onLongPress;

  /// 子のセマンティクスを除外
  final bool excludeSemantics;

  @override
  Widget build(BuildContext context) {
    if (isHidden) {
      return ExcludeSemantics(child: child);
    }

    return Semantics(
      label: label,
      hint: hint,
      value: value,
      button: isButton,
      link: isLink,
      header: isHeader,
      image: isImage,
      slider: isSlider,
      textField: isTextField,
      readOnly: isReadOnly,
      onTap: onTap,
      onLongPress: onLongPress,
      excludeSemantics: excludeSemantics,
      child: child,
    );
  }
}

/// ボタン用セマンティクス
class SemanticButton extends StatelessWidget {
  const SemanticButton({
    super.key,
    required this.child,
    required this.label,
    this.hint,
    this.onTap,
  });

  final Widget child;
  final String label;
  final String? hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SemanticWrapper(
      isButton: true,
      label: label,
      hint: hint ?? AppLocalizations.of(context)?.commonDoubleTapToActivate,
      onTap: onTap,
      child: child,
    );
  }
}

/// 画像用セマンティクス
class SemanticImage extends StatelessWidget {
  const SemanticImage({super.key, required this.child, required this.label});

  final Widget child;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SemanticWrapper(isImage: true, label: label, child: child);
  }
}

/// ヘッダー用セマンティクス
class SemanticHeader extends StatelessWidget {
  const SemanticHeader({super.key, required this.child, this.label});

  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return SemanticWrapper(isHeader: true, label: label, child: child);
  }
}

/// セマンティクスを除外（装飾的な要素用）
class ExcludeFromSemantics extends StatelessWidget {
  const ExcludeFromSemantics({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(child: child);
  }
}

/// アクセシビリティヘルパー
abstract class AccessibilityHelper {
  /// 最小タップターゲットサイズ（Material Design準拠）
  static const double minTapTargetSize = 48.0;

  /// コントラスト比のチェック
  ///
  /// WCAG AA基準: 通常テキスト 4.5:1、大きいテキスト 3:1
  /// WCAG AAA基準: 通常テキスト 7:1、大きいテキスト 4.5:1
  static double calculateContrastRatio(Color foreground, Color background) {
    final luminance1 = foreground.computeLuminance();
    final luminance2 = background.computeLuminance();

    final lighter = luminance1 > luminance2 ? luminance1 : luminance2;
    final darker = luminance1 > luminance2 ? luminance2 : luminance1;

    return (lighter + 0.05) / (darker + 0.05);
  }

  /// AA基準を満たしているか
  static bool meetsWcagAA(
    Color foreground,
    Color background, {
    bool isLargeText = false,
  }) {
    final ratio = calculateContrastRatio(foreground, background);
    return isLargeText ? ratio >= 3.0 : ratio >= 4.5;
  }

  /// AAA基準を満たしているか
  static bool meetsWcagAAA(
    Color foreground,
    Color background, {
    bool isLargeText = false,
  }) {
    final ratio = calculateContrastRatio(foreground, background);
    return isLargeText ? ratio >= 4.5 : ratio >= 7.0;
  }

  /// タップターゲットが適切なサイズかチェック
  static bool isValidTapTarget(double width, double height) {
    return width >= minTapTargetSize && height >= minTapTargetSize;
  }
}
