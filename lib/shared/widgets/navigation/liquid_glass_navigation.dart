import 'dart:ui';

import 'package:flutter/material.dart';
import '../widgets.dart';

import '../../../core/theme/app_colors.dart';
import 'app_bottom_navigation.dart';

/// iOS 26の "Liquid Glass" **風** なフローティングボトムバー。
///
/// ねらい:
/// - コンテンツの上に“浮く”見た目
/// - 半透明 + 背景ぼかし
/// - 角丸、影
///
/// 注意:
/// - **公式のLiquid Glassを完全再現するものではありません**（あくまで“風”）
/// - **タブバーの表示/非表示**はここでは扱いません（MainTabPage側の責務）
/// - スクロール連動のコンパクト化は、まずは「見た目の2種類」を優先して最小実装にしています
class LiquidGlassNavigation extends StatelessWidget {
  const LiquidGlassNavigation({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 16),
    this.borderRadius = 24,
    this.blurSigma = 18,
    this.backgroundColor,
    this.elevation = 10,
    this.height = 72,
  });

  final int currentIndex;
  final List<TabItem> items;
  final ValueChanged<int> onTap;

  /// 画面端からの余白（フローティング感）
  final EdgeInsets margin;

  /// 角丸
  final double borderRadius;

  /// ぼかし強度
  final double blurSigma;

  /// 背景色（未指定ならテーマから自動）
  final Color? backgroundColor;

  /// 影の強さ
  final double elevation;

  /// バーの高さ（SafeAreaの内側）
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg =
        backgroundColor ??
        scheme.surface.withValues(alpha: isDark ? 0.34 : 0.62);

    return SafeArea(
      top: false,
      child: Padding(
        padding: margin,
        child: Material(
          color: Colors.transparent,
          elevation: elevation,
          shadowColor: AppColors.shadow.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(borderRadius),
          clipBehavior: Clip.antiAlias,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: DecoratedBox(
              decoration: BoxDecoration(
                // ちょい本物寄せ: ガラスっぽいグラデーション + 薄い縁のハイライト
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    bg.withValues(alpha: bg.a * 1.00),
                    bg.withValues(alpha: bg.a * 0.88),
                  ],
                ),
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(
                    alpha: isDark ? 0.16 : 0.22,
                  ),
                ),
                boxShadow: [
                  // 内側の上ハイライトっぽさ
                  BoxShadow(
                    color: AppColors.background.withValues(
                      alpha: isDark ? 0.05 : 0.10,
                    ),
                    blurRadius: 0,
                    spreadRadius: 0,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: SizedBox(
                height: height,
                child: _LiquidGlassBar(
                  currentIndex: currentIndex,
                  items: items,
                  onTap: onTap,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidGlassBar extends StatelessWidget {
  const _LiquidGlassBar({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  final int currentIndex;
  final List<TabItem> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = items.length.clamp(1, 8);

    // 選択ピル（背景）の見た目
    // Bug 6 fix: ダークモードでは scheme.surface（ダーク用に計算済み）を使う
    final pillGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        (isDark ? scheme.surface : scheme.primary).withValues(
          alpha: isDark ? 0.18 : 0.16,
        ),
        scheme.primary.withValues(alpha: isDark ? 0.22 : 0.18),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final per = w / count;
        final safeIndex = currentIndex.clamp(0, count - 1);

        // 少し内側に余白を入れて“浮いてるピル”感を出す
        const pillInset = EdgeInsets.fromLTRB(6, 10, 6, 10);
        final pillLeft = per * safeIndex + pillInset.left;
        final pillWidth = per - pillInset.horizontal;
        final pillRadius = (constraints.maxHeight - pillInset.vertical) / 2;

        return Stack(
          alignment: Alignment.center,
          children: [
            // 選択中ピルがスライドする（Liquidっぽい “ヌルッ” 動き）
            AnimatedPositioned(
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              left: pillLeft,
              width: pillWidth,
              top: pillInset.top,
              bottom: pillInset.bottom,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: pillGradient,
                  borderRadius: BorderRadius.circular(pillRadius),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(
                      alpha: isDark ? 0.18 : 0.22,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow.withValues(
                        alpha: isDark ? 0.28 : 0.12,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
              ),
            ),

            // アイテム本体
            Row(
              children: [
                for (var i = 0; i < count; i++)
                  Expanded(
                    child: _LiquidGlassItem(
                      item: items[i],
                      isSelected: i == safeIndex,
                      onTap: () => onTap(i),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _LiquidGlassItem extends StatelessWidget {
  const _LiquidGlassItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final TabItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // テーマカラーに準拠したコントラストの確保
    final selectedColor = isDark ? scheme.onSurface : scheme.primary;
    final unselectedColor = scheme.onSurfaceVariant.withValues(
      alpha: isDark ? 0.75 : 0.80,
    );

    final currentIcon = (isSelected && item.selectedIcon != null)
        ? item.selectedIcon!
        : item.icon;

    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        splashColor: scheme.primary.withValues(alpha: 0.18),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                currentIcon,
                color: isSelected ? selectedColor : unselectedColor,
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                  color: isSelected ? selectedColor : unselectedColor,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.2,
                ),
                child: AppText(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
