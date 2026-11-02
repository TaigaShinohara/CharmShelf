import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

/// アプリ全体で統一されたプレミアムなヘッダー
///
/// 特徴:
/// - グラスモーフィズム (12px blur)
/// - グラデーション背景
/// - 装飾的な浮遊円
/// - SliverAppBar ベースで伸縮・ピン留めに対応
class PremiumSliverAppBar extends StatelessWidget {
  const PremiumSliverAppBar({
    super.key,
    this.title,
    this.titleText,
    this.subtitleText,
    this.subtitle,
    this.actions,
    this.expandedHeight,
    this.pinned = true,
    this.floating = true,
    this.snap = true,
    this.stretch = true,
    this.gradient,
    this.background,
    this.showDecoration = true,
    this.centerTitle = false,
    this.titlePadding,
    this.leading,
    this.bottom,
    this.toolbarHeight,
    this.inlineTitle = false,
    this.automaticallyImplyLeading = true,
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
  final double? expandedHeight;
  final bool pinned;
  final bool floating;
  final bool snap;
  final bool stretch;
  final Gradient? gradient;
  final Widget? background;
  final bool showDecoration;
  final bool centerTitle;
  final EdgeInsetsGeometry? titlePadding;
  final PreferredSizeWidget? bottom;
  final double? toolbarHeight;
  final bool inlineTitle;
  final bool automaticallyImplyLeading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onPrimary = colorScheme.onPrimary;

    // 定数
    const glassBlurSigma = 12.0;
    const glassSurfaceOpacity = 0.94;
    const titleStartInset = 20.0;
    const leadingWidth = 48.0;

    // flexibleSpace内部では removePadding(removeTop: true) されるため、
    // SliverAppBar 外側の context または viewPaddingOf から安全にステータスバー高さを取得する
    final statusBarHeight = MediaQuery.viewPaddingOf(context).top > 0
        ? MediaQuery.viewPaddingOf(context).top
        : MediaQuery.paddingOf(context).top;
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    final actualToolbarHeight = toolbarHeight ?? kToolbarHeight;
    final minRequiredHeight = actualToolbarHeight + bottomHeight;
    final effectiveContentHeight = expandedHeight != null
        ? math.max(expandedHeight!, minRequiredHeight)
        : (inlineTitle ? minRequiredHeight : (minRequiredHeight + 56.0));
    final effectiveExpandedHeight = expandedHeight != null
        ? statusBarHeight + effectiveContentHeight
        : (inlineTitle ? null : statusBarHeight + effectiveContentHeight);

    return SliverAppBar(
      expandedHeight: effectiveExpandedHeight,
      pinned: pinned,
      floating: floating,
      snap: snap,
      stretch: stretch,
      // スクロール時に背景が透けて見えるように透明に設定
      backgroundColor: const Color(0x00000000),
      elevation: 0,
      scrolledUnderElevation: 0,
      forceElevated: false,
      titleSpacing: 0,
      toolbarHeight: actualToolbarHeight,
      // 標準の actions は使用せず、LayoutBuilder 内で動的に色付けして配置する
      automaticallyImplyLeading: false,
      bottom: switch (bottom) {
        final b? => PreferredSize(
          preferredSize: b.preferredSize,
          child: const SizedBox.shrink(),
        ),
        _ => null,
      },
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final maxHeight = constraints.biggest.height;
          final minHeight =
              statusBarHeight + actualToolbarHeight + bottomHeight;
          final hasToolbarLeading =
              leading != null ||
              (automaticallyImplyLeading && Navigator.canPop(context));

          final scrollableRange =
              ((effectiveExpandedHeight ?? minHeight) - minHeight).clamp(
                1.0,
                double.infinity,
              );

          final t = ((maxHeight - minHeight) / scrollableRange).clamp(0.0, 1.0);
          final curvedT = Curves.easeInCubic.transform(t);

          final titleColor = inlineTitle
              ? colorScheme.onSurface
              : (Color.lerp(
                      colorScheme.primary,
                      colorScheme.onSurface,
                      curvedT,
                    ) ??
                    colorScheme.onSurface);

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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null);

          final currentTitleWidget = titleText != null
              ? Text(
                  titleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.35,
                    shadows: inlineTitle
                        ? null
                        : [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              offset: const Offset(0, 1),
                              blurRadius: 4,
                            ),
                          ],
                  ),
                )
              : (title ?? const SizedBox.shrink());

          return Stack(
            fit: StackFit.expand,
            children: [
              if (!inlineTitle)
                Opacity(
                  opacity: t,
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
                                  colorScheme.primary.withValues(alpha: 0.8),
                                  colorScheme.primaryContainer.withValues(
                                    alpha: 0.8,
                                  ),
                                ],
                              ),
                        ),
                      ),
                      if (showDecoration)
                        Stack(
                          children: [
                            Positioned(
                              right: -40,
                              top: -30,
                              child: _DecorationCircle(
                                size: 160,
                                color: onPrimary.withValues(alpha: 0.12),
                              ),
                            ),
                            Positioned(
                              left: -20,
                              top: 40,
                              child: _DecorationCircle(
                                size: 100,
                                color: onPrimary.withValues(alpha: 0.08),
                              ),
                            ),
                          ],
                        ),
                      if (background != null) ...[background!],
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0x00000000),
                              colorScheme.surface.withValues(alpha: 0.4),
                            ],
                            begin: const Alignment(0, 0.5),
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Positioned.fill(
                child: ClipRect(
                  child: Stack(
                    children: [
                      if (!inlineTitle)
                        BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: glassBlurSigma * (1 - t),
                            sigmaY: glassBlurSigma * (1 - t),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      Container(
                        decoration: BoxDecoration(
                          color: inlineTitle
                              ? colorScheme.surface
                              : colorScheme.surface.withValues(
                                  alpha:
                                      (0.1 +
                                              (1 - t) *
                                                  (glassSurfaceOpacity - 0.1))
                                          .clamp(0.0, glassSurfaceOpacity),
                                ),
                          border: Border(
                            bottom: BorderSide(
                              color: inlineTitle
                                  ? colorScheme.outlineVariant.withValues(
                                      alpha: 0.3,
                                    )
                                  : (Color.lerp(
                                          onPrimary.withValues(alpha: 0.12),
                                          colorScheme.outlineVariant.withValues(
                                            alpha: 0.3,
                                          ),
                                          1 - t,
                                        ) ??
                                        colorScheme.outlineVariant.withValues(
                                          alpha: 0.3,
                                        )),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: (!inlineTitle && t < 0.8)
                            ? Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      onPrimary.withValues(
                                        alpha: (1 - t) * 0.08,
                                      ),
                                      const Color(0x00000000),
                                      onPrimary.withValues(
                                        alpha: (1 - t) * 0.02,
                                      ),
                                    ],
                                    stops: const [0.0, 0.4, 0.9],
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              if (!inlineTitle)
                IconTheme(
                  data: IconThemeData(color: titleColor),
                  child: FlexibleSpaceBar(
                    centerTitle: centerTitle,
                    expandedTitleScale: 1.0,
                    titlePadding:
                        titlePadding ??
                        EdgeInsets.only(
                          left: centerTitle
                              ? 0
                              : (hasToolbarLeading ? titleStartInset : 20),
                          bottom: 10 + bottomHeight,
                          right: centerTitle
                              ? 0
                              : (actions != null && actions!.isNotEmpty
                                    ? (actions!.length * 44.0 + 12.0)
                                    : 24.0),
                        ),
                    stretchModes: const [
                      StretchMode.zoomBackground,
                      StretchMode.blurBackground,
                      StretchMode.fadeTitle,
                    ],
                    title: ClipRect(
                      child: OverflowBox(
                        alignment: centerTitle
                            ? Alignment.bottomCenter
                            : Alignment.bottomLeft,
                        minHeight: 0,
                        maxHeight: double.infinity,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: centerTitle
                              ? CrossAxisAlignment.center
                              : CrossAxisAlignment.start,
                          children: [
                            currentTitleWidget,
                            if (subtitleWidget case final sw?) ...[
                              const SizedBox(height: 2),
                              sw,
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: statusBarHeight,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: actualToolbarHeight,
                      child: IconTheme(
                        data: IconThemeData(color: titleColor),
                        child: Row(
                          children: [
                            if (leading case final l?)
                              SizedBox(
                                width: leadingWidth,
                                child: Align(
                                  alignment: Alignment.center,
                                  child: l,
                                ),
                              )
                            else if (automaticallyImplyLeading &&
                                Navigator.canPop(context))
                              SizedBox(
                                width: leadingWidth,
                                child: Align(
                                  alignment: Alignment.center,
                                  child: IconButton(
                                    icon: const Icon(Icons.arrow_back),
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    tooltip: MaterialLocalizations.of(
                                      context,
                                    ).backButtonTooltip,
                                  ),
                                ),
                              )
                            else if (inlineTitle)
                              const SizedBox(width: 16),
                            if (inlineTitle)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 2,
                                    right: 6,
                                  ),
                                  child: currentTitleWidget,
                                ),
                              )
                            else
                              const Spacer(),
                            ...?actions,
                            if (inlineTitle &&
                                (actions == null || actions!.isEmpty))
                              const SizedBox(width: 16)
                            else if (inlineTitle)
                              const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
                    if (bottom case final b?)
                      Theme(
                        data: theme.copyWith(
                          tabBarTheme: TabBarThemeData(
                            labelColor: titleColor,
                            unselectedLabelColor: titleColor.withValues(
                              alpha: 0.7,
                            ),
                            indicatorColor: titleColor,
                            labelStyle: theme.tabBarTheme.labelStyle,
                            unselectedLabelStyle:
                                theme.tabBarTheme.unselectedLabelStyle,
                          ),
                        ),
                        child: DefaultTextStyle(
                          style:
                              (theme.textTheme.labelLarge ?? const TextStyle())
                                  .copyWith(color: titleColor),
                          child: b,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
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
