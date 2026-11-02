import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

export 'facet_chip.dart';

enum AppTagSize {
  small(fontSize: 9),
  medium(fontSize: 11),
  large(fontSize: 13),
  xLarge(fontSize: 15);

  final double fontSize;

  const AppTagSize({required this.fontSize});

  /// 文字サイズを基準にした余白。サイズ間でチップの密度を揃える。
  EdgeInsets get padding => EdgeInsets.symmetric(
    horizontal: fontSize * 0.58,
    vertical: fontSize * 0.27,
  );

  /// 文字サイズに比例した角丸。拡大・縮小時も輪郭が崩れにくい。
  double get borderRadius => fontSize * 0.9;
}

enum AppTagVariant { filled, outline }

enum AppTagActionType { plus, minus }

/// チャームを利用可能な横幅の左端から並べ、収まらない分を次の行へ送る。
class AppTagWrap extends StatelessWidget {
  const AppTagWrap({
    super.key,
    required this.children,
    this.spacing = 8,
    this.runSpacing = 8,
    this.crossAxisAlignment = WrapCrossAlignment.start,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final WrapCrossAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.topStart,
      heightFactor: 1,
      child: Wrap(
        alignment: WrapAlignment.start,
        spacing: spacing,
        runSpacing: runSpacing,
        crossAxisAlignment: crossAxisAlignment,
        children: children,
      ),
    );
  }
}

class AppTag extends StatelessWidget {
  final String label;

  /// 一覧は1行、詳細表示ではnullを指定して全文を折り返す。
  final int? maxLines;
  final Color? color;
  final AppTagSize size;
  final AppTagVariant variant;
  final String? count;
  final num? value;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? longPressHint;

  /// 色情報を無視してシンプルにする
  final bool colorless;

  /// 先頭に表示するアイコン
  final IconData? icon;

  /// 末尾に表示するアクションボタンの種類
  final AppTagActionType? actionType;

  /// アクションボタンがタップされた時のコールバック
  final VoidCallback? onAction;

  /// 非表示タグなど、目立たなくするために半透明にするフラグ
  final bool isDimmed;

  /// 選択状態フラグ
  final bool isSelected;
  final bool emphasizeSelectionStyle;

  /// カウントが0のときにバッジを非表示にするかどうか（デフォルト: true）
  final bool hideZeroCount;

  const AppTag({
    super.key,
    required this.label,
    this.maxLines = 1,
    this.color,
    this.size = AppTagSize.small,
    this.variant = AppTagVariant.filled,
    this.count,
    this.value,
    this.onTap,
    this.onLongPress,
    this.longPressHint,
    this.colorless = false,
    this.icon,
    this.actionType,
    this.onAction,
    this.isDimmed = false,
    this.isSelected = false,
    this.emphasizeSelectionStyle = false,
    this.hideZeroCount = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final opacity = isDimmed ? 0.4 : 1.0;
    final isFilled = variant == AppTagVariant.filled;
    final isSelectedMode =
        (isSelected || emphasizeSelectionStyle) && !colorless;
    final baseColor = colorless
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
        : (color ?? theme.colorScheme.secondary);

    final backgroundColor = colorless
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45)
        : (isSelectedMode
              ? Color.alphaBlend(
                  baseColor.withValues(alpha: 0.14),
                  theme.colorScheme.surface,
                )
              : (isFilled
                    ? Color.alphaBlend(
                        baseColor.withValues(alpha: 0.08),
                        theme.colorScheme.surface,
                      )
                    : theme.colorScheme.surface.withValues(alpha: 0.86)));

    final borderColor = colorless
        ? theme.colorScheme.outline.withValues(alpha: 0.24)
        : (isSelectedMode
              ? baseColor.withValues(alpha: 0.55)
              : (isFilled
                    ? baseColor.withValues(alpha: 0.22)
                    : baseColor.withValues(alpha: 0.35)));

    final l10n = AppLocalizations.of(context);
    final actionSemanticsLabel = actionType == null
        ? null
        : (actionType == AppTagActionType.plus
              ? (l10n?.tagActionAdd(label) ?? '$label を追加')
              : (l10n?.tagActionRemove(label) ?? '$label を削除'));
    final effectiveOnTap = onTap ?? onAction;
    final isInteractive =
        effectiveOnTap != null || onLongPress != null || onAction != null;
    final customSemanticsActions =
        onTap != null && onAction != null && actionSemanticsLabel != null
        ? <CustomSemanticsAction, VoidCallback>{
            CustomSemanticsAction(label: actionSemanticsLabel): onAction!,
          }
        : null;

    final textColor = () {
      if (colorless) return theme.colorScheme.onSurfaceVariant;
      final isDark = theme.brightness == Brightness.dark;
      final hsl = HSLColor.fromColor(baseColor);
      if (!isDark && hsl.lightness > 0.40) {
        return hsl
            .withLightness(0.34)
            .withSaturation((hsl.saturation * 1.15).clamp(0.0, 1.0))
            .toColor();
      } else if (isDark && hsl.lightness < 0.62) {
        return hsl.withLightness(0.74).toColor();
      }
      return isFilled ? baseColor.withValues(alpha: 0.95) : baseColor;
    }();

    // 削除ボタン等がある場合はチェックアイコンを重複して出さない
    final effectiveIcon =
        icon ?? (isSelectedMode && actionType == null ? Icons.check : null);

    final rawDisplayValue = value != null ? value.toString() : count;
    final shouldShowBadge =
        rawDisplayValue != null &&
        (!hideZeroCount ||
            (rawDisplayValue != '0' && rawDisplayValue.isNotEmpty));
    final displayValue = shouldShowBadge ? rawDisplayValue : null;
    final valueBadgeSize = size.fontSize * 1.55;
    final labelMinHeight = displayValue != null
        ? valueBadgeSize
        : size.fontSize * 1.35;

    final semanticsLabel = displayValue != null
        ? '$label, $displayValue'
        : label;
    final effectiveSemanticsLabel =
        onTap == null && onAction != null && actionSemanticsLabel != null
        ? actionSemanticsLabel
        : semanticsLabel;

    final contentPadding = actionType == null
        ? size.padding
        : EdgeInsets.only(left: size.padding.left, right: size.padding.right);
    final borderWidth = (size.fontSize * 0.06).clamp(0.6, 1.0).toDouble();
    final ribbonWidth = (size.fontSize * (isSelectedMode ? 0.27 : 0.22))
        .clamp(2.0, 4.0)
        .toDouble();

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      constraints: actionType == null
          ? null
          : const BoxConstraints(minHeight: 48),
      padding: contentPadding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(size.borderRadius),
        border: Border.all(
          color: borderColor,
          width: isSelectedMode ? borderWidth + 0.2 : borderWidth,
        ),
      ),
      // チャームの目印。前景に重ねるため、チップの横幅を増やさない。
      foregroundDecoration: colorless
          ? null
          : BoxDecoration(
              borderRadius: BorderRadius.circular(size.borderRadius),
              border: Border(
                left: BorderSide(
                  color: baseColor.withValues(
                    alpha: isSelectedMode ? 0.95 : 0.68,
                  ),
                  width: ribbonWidth,
                ),
              ),
            ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (effectiveIcon != null) ...[
            Icon(
              effectiveIcon,
              size: size.fontSize * 1.05,
              color: textColor.withValues(alpha: 0.85),
            ),
            SizedBox(width: size.fontSize * 0.35),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: labelMinHeight),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: maxLines,
                  softWrap: maxLines != 1,
                  overflow: maxLines == null
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: size.fontSize,
                    color: textColor,
                    fontWeight: isSelectedMode
                        ? FontWeight.w600
                        : FontWeight.w500,
                    height: 1.15,
                  ),
                ),
              ),
            ),
          ),
          if (displayValue != null) ...[
            SizedBox(width: size.fontSize * 0.35),
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size.fontSize * 0.55),
                color: textColor.withValues(alpha: 0.1),
              ),
              child: Text(
                displayValue,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: size.fontSize * 0.75,
                  color: textColor.withValues(alpha: 0.8),
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
            ),
          ],
          if (actionType != null) ...[
            SizedBox(width: size.fontSize * 0.35),
            Tooltip(
              message: actionSemanticsLabel!,
              child: SizedBox(
                key: ValueKey('app-tag-action-$label'),
                width: 48,
                height: 48,
                child: InkWell(
                  onTap: onAction,
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: ExcludeSemantics(
                      child: Icon(
                        actionType == AppTagActionType.plus
                            ? Icons.add
                            : Icons.close,
                        size: size.fontSize * 1.05,
                        color: textColor.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    content = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: isInteractive ? 48 : 0,
        minHeight: isInteractive ? 48 : 0,
      ),
      child: Semantics(
        container: true,
        button: effectiveOnTap != null,
        label: effectiveSemanticsLabel,
        hint: onLongPress == null ? null : longPressHint,
        selected: isSelectedMode,
        onTap: effectiveOnTap,
        onLongPress: onLongPress,
        customSemanticsActions: customSemanticsActions,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(size.borderRadius),
          child: InkWell(
            onTap: effectiveOnTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(size.borderRadius),
            // アクセシビリティ用のタップ領域は48dpを保ち、
            // 視覚的なチップ本体だけは文字サイズに合わせて縮める。
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 1,
              heightFactor: 1,
              child: ExcludeSemantics(child: content),
            ),
          ),
        ),
      ),
    );

    if (isDimmed) {
      content = Opacity(opacity: opacity, child: content);
    }

    return content;
  }
}
