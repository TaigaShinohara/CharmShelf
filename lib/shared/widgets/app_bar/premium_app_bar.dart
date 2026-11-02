import 'dart:ui';
import 'package:flutter/material.dart';

/// アプリ全体で統一されたプレミアムな AppBar（PreferredSizeWidget版）
///
/// 特徴:
/// - グラスモーフィズム (12px blur)
/// - グラデーション背景
/// - 装飾的な浮遊円
/// - Scaffold の `appBar:` に直接設定可能
class PremiumAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PremiumAppBar({
    super.key,
    this.title,
    this.titleText,
    this.subtitleText,
    this.subtitle,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.centerTitle = false,
    this.gradient,
    this.showDecoration = true,
    this.toolbarHeight,
    this.bottom,
  }) : assert(
         title != null || titleText != null,
         'title または titleText のいずれかを指定する必要があります',
       );

  final Widget? title;
  final String? titleText;
  final String? subtitleText;
  final Widget? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final bool centerTitle;
  final Gradient? gradient;
  final bool showDecoration;
  final double? toolbarHeight;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize {
    final actualToolbarHeight = toolbarHeight ?? kToolbarHeight;
    final bottomHeight = bottom?.preferredSize.height ?? 0.0;
    return Size.fromHeight(actualToolbarHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onPrimary = colorScheme.onPrimary;

    const glassBlurSigma = 12.0;
    const glassSurfaceOpacity = 0.7;
    const leadingWidth = 48.0;

    final statusBarHeight = MediaQuery.viewPaddingOf(context).top > 0
        ? MediaQuery.viewPaddingOf(context).top
        : MediaQuery.paddingOf(context).top;
    final actualToolbarHeight = toolbarHeight ?? kToolbarHeight;
    final bottomHeight = bottom?.preferredSize.height ?? 0.0;
    final totalHeight = statusBarHeight + actualToolbarHeight + bottomHeight;

    final titleColor = colorScheme.primary;

    final titleText = this.titleText;
    final title = this.title;

    final subtitleWidget =
        subtitle ??
        (subtitleText != null
            ? Text(
                subtitleText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: titleColor.withValues(alpha: 0.88),
                  height: 1.25,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null);

    final currentTitleWidget = titleText != null
        ? Text(
            titleText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: titleColor,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          )
        : (title ?? const SizedBox.shrink());

    final canPop = Navigator.canPop(context);
    final showLeading =
        leading != null || (automaticallyImplyLeading && canPop);

    return SizedBox(
      height: totalHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. グラデーション背景と装飾
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient:
                        gradient ??
                        LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primary.withValues(alpha: 0.15),
                            colorScheme.primaryContainer.withValues(
                              alpha: 0.15,
                            ),
                          ],
                        ),
                  ),
                ),
                if (showDecoration)
                  Stack(
                    children: [
                      Positioned(
                        right: -30,
                        top: -20,
                        child: _DecorationCircle(
                          size: 120,
                          color: onPrimary.withValues(alpha: 0.08),
                        ),
                      ),
                      Positioned(
                        left: -15,
                        top: 20,
                        child: _DecorationCircle(
                          size: 80,
                          color: onPrimary.withValues(alpha: 0.05),
                        ),
                      ),
                    ],
                  ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0x00000000),
                        colorScheme.surface.withValues(alpha: 0.2),
                      ],
                      begin: const Alignment(0, 0.5),
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. グラスモーフィズム (すりガラスぼかし + 境界線)
          Positioned.fill(
            child: ClipRect(
              child: Stack(
                children: [
                  BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: glassBlurSigma,
                      sigmaY: glassBlurSigma,
                    ),
                    child: const SizedBox.expand(),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(
                        alpha: glassSurfaceOpacity,
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. ツールバー（Leading, Title, Actions）
          Positioned(
            top: statusBarHeight,
            left: 0,
            right: 0,
            height: actualToolbarHeight,
            child: IconTheme(
              data: IconThemeData(color: titleColor),
              child: Row(
                children: [
                  if (leading case final l?)
                    SizedBox(
                      width: leadingWidth,
                      child: Align(alignment: Alignment.center, child: l),
                    )
                  else if (showLeading)
                    SizedBox(
                      width: leadingWidth,
                      child: Align(
                        alignment: Alignment.center,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).backButtonTooltip,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 16),
                  Expanded(
                    child: Align(
                      alignment: centerTitle
                          ? Alignment.center
                          : Alignment.centerLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: centerTitle
                            ? CrossAxisAlignment.center
                            : CrossAxisAlignment.start,
                        children: [
                          currentTitleWidget,
                          if (subtitleWidget case final sw?) ...[
                            const SizedBox(height: 1),
                            sw,
                          ],
                        ],
                      ),
                    ),
                  ),
                  ...?actions,
                  if (actions == null || actions!.isEmpty)
                    const SizedBox(width: 16)
                  else
                    const SizedBox(width: 8),
                ],
              ),
            ),
          ),

          // 4. Bottom (TabBarなど)
          if (bottom case final b?)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Theme(
                data: theme.copyWith(
                  tabBarTheme: TabBarThemeData(
                    labelColor: titleColor,
                    unselectedLabelColor: titleColor.withValues(alpha: 0.7),
                    indicatorColor: titleColor,
                    labelStyle: theme.tabBarTheme.labelStyle,
                    unselectedLabelStyle:
                        theme.tabBarTheme.unselectedLabelStyle,
                  ),
                ),
                child: DefaultTextStyle(
                  style: (theme.textTheme.labelLarge ?? const TextStyle())
                      .copyWith(color: titleColor),
                  child: b,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DecorationCircle extends StatelessWidget {
  const _DecorationCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
