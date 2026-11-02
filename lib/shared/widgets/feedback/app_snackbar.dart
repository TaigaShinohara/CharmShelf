import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/feedback/snackbar_config.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets.dart';

final _inactiveAppSnackBarOverlayKey = GlobalKey<OverlayState>(
  debugLabel: 'inactive-app-snackbar-overlay',
);
GlobalKey<OverlayState> _currentAppSnackBarOverlayKey =
    _inactiveAppSnackBarOverlayKey;

GlobalKey<OverlayState> get appSnackBarOverlayKey =>
    _currentAppSnackBarOverlayKey;

/// 画面遷移やモーダルより上にSnackBarを表示するための最前面Overlay。
class AppSnackBarOverlayHost extends StatefulWidget {
  const AppSnackBarOverlayHost({required this.child, super.key});

  final Widget child;

  @override
  State<AppSnackBarOverlayHost> createState() => _AppSnackBarOverlayHostState();
}

class _AppSnackBarOverlayHostState extends State<AppSnackBarOverlayHost> {
  final _overlayKey = GlobalKey<OverlayState>(
    debugLabel: 'app-snackbar-overlay',
  );
  late final OverlayEntry _contentEntry = OverlayEntry(
    builder: (context) => widget.child,
  );

  @override
  void initState() {
    super.initState();
    _currentAppSnackBarOverlayKey = _overlayKey;
  }

  @override
  void didUpdateWidget(AppSnackBarOverlayHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _contentEntry.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(key: _overlayKey, initialEntries: [_contentEntry]);
  }

  @override
  void dispose() {
    _contentEntry
      ..remove()
      ..dispose();
    if (identical(_currentAppSnackBarOverlayKey, _overlayKey)) {
      _currentAppSnackBarOverlayKey = _inactiveAppSnackBarOverlayKey;
    }
    super.dispose();
  }
}

/// [ScaffoldMessenger]と同じ呼び出し方で、常に最前面へ表示する窓口。
class AppSnackBarMessenger {
  const AppSnackBarMessenger._(this._context);

  final BuildContext _context;

  static AppSnackBarMessenger of(BuildContext context) {
    assert(
      appSnackBarOverlayKey.currentState != null ||
          Overlay.maybeOf(context, rootOverlay: true) != null,
      'SnackBarを表示できるOverlayがありません。',
    );
    return AppSnackBarMessenger._(context);
  }

  static AppSnackBarMessenger? maybeOf(BuildContext context) {
    final overlay =
        appSnackBarOverlayKey.currentState ??
        Overlay.maybeOf(context, rootOverlay: true);
    return overlay == null ? null : AppSnackBarMessenger._(context);
  }

  static void showGlobal(SnackBar snackBar) {
    _FrontSnackBarOverlay.show(snackBar: snackBar);
  }

  static void hideGlobal() {
    _FrontSnackBarOverlay.hide();
  }

  static void clearGlobal() {
    _FrontSnackBarOverlay.remove();
  }

  void showSnackBar(SnackBar snackBar) {
    _FrontSnackBarOverlay.show(context: _context, snackBar: snackBar);
  }

  void hideCurrentSnackBar({
    SnackBarClosedReason reason = SnackBarClosedReason.hide,
  }) {
    _FrontSnackBarOverlay.hide();
  }

  void removeCurrentSnackBar({
    SnackBarClosedReason reason = SnackBarClosedReason.remove,
  }) {
    _FrontSnackBarOverlay.remove();
  }

  void clearSnackBars() {
    _FrontSnackBarOverlay.remove();
  }
}

class _FrontSnackBarOverlay {
  static OverlayEntry? _currentEntry;

  static void show({BuildContext? context, required SnackBar snackBar}) {
    remove();
    final overlay =
        appSnackBarOverlayKey.currentState ??
        (context != null ? Overlay.maybeOf(context, rootOverlay: true) : null);
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _FrontSnackBarWidget(
        snackBar: snackBar,
        onDismiss: () {
          if (identical(_currentEntry, entry)) {
            remove();
          }
        },
      ),
    );
    _currentEntry = entry;
    overlay.insert(entry);
  }

  static void hide() {
    final entry = _currentEntry;
    _currentEntry = null;
    entry?.remove();
    entry?.dispose();
  }

  static void remove() => hide();
}

class _FrontSnackBarWidget extends StatefulWidget {
  const _FrontSnackBarWidget({required this.snackBar, required this.onDismiss});

  final SnackBar snackBar;
  final VoidCallback onDismiss;

  @override
  State<_FrontSnackBarWidget> createState() => _FrontSnackBarWidgetState();
}

class _FrontSnackBarWidgetState extends State<_FrontSnackBarWidget>
    with SingleTickerProviderStateMixin {
  Timer? _dismissTimer;
  bool _dismissing = false;
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 250),
    reverseDuration: const Duration(milliseconds: 200),
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    if (!widget.snackBar.persist) {
      _dismissTimer = Timer(widget.snackBar.duration, _dismiss);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.snackBar.onVisible?.call();
    });
  }

  Future<void> _dismiss() async {
    if (!mounted || _dismissing) return;
    _dismissing = true;
    _dismissTimer?.cancel();
    try {
      await _controller.reverse().orCancel;
      if (mounted) widget.onDismiss();
    } on TickerCanceled {
      // The overlay may be replaced or disposed during its exit animation.
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snackTheme = theme.snackBarTheme;
    final behavior =
        widget.snackBar.behavior ??
        snackTheme.behavior ??
        SnackBarBehavior.fixed;
    final isFloating = behavior == SnackBarBehavior.floating;
    final backgroundColor =
        widget.snackBar.backgroundColor ??
        snackTheme.backgroundColor ??
        theme.colorScheme.inverseSurface;
    final contentStyle =
        snackTheme.contentTextStyle ??
        TextStyle(color: theme.colorScheme.onInverseSurface);
    final shape =
        widget.snackBar.shape ??
        snackTheme.shape ??
        (isFloating
            ? const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(4)),
              )
            : null);
    final margin = isFloating
        ? (widget.snackBar.margin ??
              snackTheme.insetPadding ??
              const EdgeInsets.fromLTRB(16, 5, 16, 16))
        : EdgeInsets.zero;
    final padding =
        widget.snackBar.padding ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14);

    Widget content = Row(
      children: [
        Expanded(
          child: DefaultTextStyle(
            style: contentStyle,
            child: widget.snackBar.content,
          ),
        ),
        if (widget.snackBar.action case final action?) ...[
          const SizedBox(width: 8),
          SnackBarAction(
            label: action.label,
            textColor: action.textColor,
            disabledTextColor: action.disabledTextColor,
            backgroundColor: action.backgroundColor,
            disabledBackgroundColor: action.disabledBackgroundColor,
            onPressed: () {
              if (_dismissing) return;
              action.onPressed();
              _dismiss();
            },
          ),
        ],
        if (widget.snackBar.showCloseIcon ?? snackTheme.showCloseIcon ?? false)
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            color: widget.snackBar.closeIconColor ?? snackTheme.closeIconColor,
            onPressed: _dismiss,
            icon: const Icon(Icons.close),
          ),
      ],
    );

    content = Material(
      color: backgroundColor,
      elevation: widget.snackBar.elevation ?? snackTheme.elevation ?? 6,
      shape: shape,
      clipBehavior: widget.snackBar.clipBehavior,
      child: Padding(padding: padding, child: content),
    );

    return Positioned(
      left: 0,
      right: 0,
      bottom: MediaQuery.paddingOf(context).bottom,
      child: Dismissible(
        key: UniqueKey(),
        direction: widget.snackBar.dismissDirection ?? DismissDirection.down,
        resizeDuration: null,
        onDismissed: (_) => widget.onDismiss(),
        child: FadeTransition(
          opacity: _controller,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: _controller,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: Padding(padding: margin, child: content),
          ),
        ),
      ),
    );
  }
}

/// カスタムSnackBarウィジェット
///
/// [SnackBarConfig]に基づいてスタイリングされたSnackBarを生成します。
class AppSnackBarWidget extends StatelessWidget {
  const AppSnackBarWidget({
    required this.message,
    required this.config,
    this.type = SnackBarType.defaultType,
    this.action,
    this.onDismissed,
    super.key,
  });

  final String message;
  final SnackBarConfig config;
  final SnackBarType type;
  final SnackBarAction? action;
  final VoidCallback? onDismissed;

  @override
  Widget build(BuildContext context) {
    final colors = config.getColorsForType(type);

    return Container(
      padding: config.padding,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(config.borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.2),
            blurRadius: config.elevation,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // アイコン
          if (config.showIcon && type.icon != null) ...[
            Icon(type.icon, color: colors.icon, size: config.iconSize),
            const SizedBox(width: 12),
          ],
          // メッセージ
          Expanded(
            child: AppText(
              message,
              style: TextStyle(color: colors.text, fontSize: 14),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // アクションボタン
          if (action != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: action!.onPressed,
              style: TextButton.styleFrom(
                foregroundColor: colors.text,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: AppText(
                action!.label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// SnackBarを生成するファクトリクラス
class AppSnackBar {
  AppSnackBar._();

  /// 設定に基づいてSnackBarを生成
  static SnackBar create({
    required String message,
    required SnackBarConfig config,
    SnackBarType type = SnackBarType.defaultType,
    SnackBarAction? action,
    VoidCallback? onDismissed,
  }) {
    final colors = config.getColorsForType(type);

    return SnackBar(
      content: Row(
        children: [
          // アイコン
          if (config.showIcon && type.icon != null) ...[
            Icon(type.icon, color: colors.icon, size: config.iconSize),
            const SizedBox(width: 12),
          ],
          // メッセージ
          Expanded(
            child: AppText(
              message,
              style: TextStyle(color: colors.text),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      backgroundColor: colors.background,
      behavior: config.behavior,
      duration: config.duration,
      margin: config.behavior == SnackBarBehavior.floating
          ? _getMarginForPosition(config)
          : null,
      padding: config.padding,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(config.borderRadius),
      ),
      elevation: config.elevation,
      action: action,
      dismissDirection: config.position == SnackBarPosition.top
          ? DismissDirection.up
          : DismissDirection.down,
      onVisible: onDismissed,
    );
  }

  /// 位置に応じたマージンを取得
  static EdgeInsets _getMarginForPosition(SnackBarConfig config) {
    if (config.position == SnackBarPosition.top) {
      // 上部表示の場合はマージンを反転
      return EdgeInsets.fromLTRB(
        config.margin.left,
        config.margin.bottom + 50, // ステータスバー分を考慮
        config.margin.right,
        0,
      );
    }
    return config.margin;
  }

  /// 成功SnackBar
  static SnackBar success({
    required String message,
    required SnackBarConfig config,
    SnackBarAction? action,
  }) {
    return create(
      message: message,
      config: config,
      type: SnackBarType.success,
      action: action,
    );
  }

  /// エラーSnackBar
  static SnackBar error({
    required String message,
    required SnackBarConfig config,
    SnackBarAction? action,
  }) {
    return create(
      message: message,
      config: config,
      type: SnackBarType.error,
      action: action,
    );
  }

  /// 警告SnackBar
  static SnackBar warning({
    required String message,
    required SnackBarConfig config,
    SnackBarAction? action,
  }) {
    return create(
      message: message,
      config: config,
      type: SnackBarType.warning,
      action: action,
    );
  }

  /// 情報SnackBar
  static SnackBar info({
    required String message,
    required SnackBarConfig config,
    SnackBarAction? action,
  }) {
    return create(
      message: message,
      config: config,
      type: SnackBarType.info,
      action: action,
    );
  }
}

/// 上部表示用のカスタムSnackBarオーバーレイ
///
/// 標準のSnackBarは下部表示のみのため、上部表示用にOverlayを使用します。
class TopSnackBarOverlay {
  static OverlayEntry? _currentEntry;

  /// 上部にSnackBarを表示
  static void show({
    required BuildContext context,
    required String message,
    required SnackBarConfig config,
    SnackBarType type = SnackBarType.defaultType,
    SnackBarAction? action,
  }) {
    // 既存のSnackBarを削除
    hide();

    final overlay =
        appSnackBarOverlayKey.currentState ??
        Overlay.of(context, rootOverlay: true);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _TopSnackBarWidget(
        message: message,
        config: config,
        type: type,
        action: action,
        onDismiss: () {
          if (identical(_currentEntry, entry)) hide();
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  /// SnackBarを非表示
  static void hide() {
    final entry = _currentEntry;
    _currentEntry = null;
    entry?.remove();
    entry?.dispose();
  }
}

/// 上部表示SnackBarのウィジェット
class _TopSnackBarWidget extends StatefulWidget {
  const _TopSnackBarWidget({
    required this.message,
    required this.config,
    required this.type,
    required this.onDismiss,
    this.action,
  });

  final String message;
  final SnackBarConfig config;
  final SnackBarType type;
  final SnackBarAction? action;
  final VoidCallback onDismiss;

  @override
  State<_TopSnackBarWidget> createState() => _TopSnackBarWidgetState();
}

class _TopSnackBarWidgetState extends State<_TopSnackBarWidget>
    with SingleTickerProviderStateMixin {
  Timer? _dismissTimer;
  bool _dismissing = false;
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _setupAnimations();

    _controller.forward();

    // 自動的に非表示
    _dismissTimer = Timer(widget.config.duration, _dismiss);
  }

  void _setupAnimations() {
    switch (widget.config.animation) {
      case SnackBarAnimation.slide:
        _slideAnimation =
            Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
            );
        _fadeAnimation = const AlwaysStoppedAnimation(1.0);
        _scaleAnimation = const AlwaysStoppedAnimation(1.0);
      case SnackBarAnimation.fade:
        _slideAnimation = const AlwaysStoppedAnimation(Offset.zero);
        _fadeAnimation = CurvedAnimation(
          parent: _controller,
          curve: Curves.easeIn,
        );
        _scaleAnimation = const AlwaysStoppedAnimation(1.0);
      case SnackBarAnimation.scale:
        _slideAnimation = const AlwaysStoppedAnimation(Offset.zero);
        _fadeAnimation = const AlwaysStoppedAnimation(1.0);
        _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
        );
      case SnackBarAnimation.none:
        _slideAnimation = const AlwaysStoppedAnimation(Offset.zero);
        _fadeAnimation = const AlwaysStoppedAnimation(1.0);
        _scaleAnimation = const AlwaysStoppedAnimation(1.0);
    }
  }

  Future<void> _dismiss() async {
    if (!mounted || _dismissing) return;
    _dismissing = true;
    _dismissTimer?.cancel();
    try {
      await _controller.reverse().orCancel;
      if (mounted) widget.onDismiss();
    } on TickerCanceled {
      // The overlay may be replaced or disposed during its exit animation.
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.config.getColorsForType(widget.type);
    final mediaQuery = MediaQuery.of(context);

    return Positioned(
      top: mediaQuery.padding.top + 8,
      left: widget.config.margin.left,
      right: widget.config.margin.right,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity != null &&
                      details.primaryVelocity! < 0) {
                    _dismiss();
                  }
                },
                child: Container(
                  padding: widget.config.padding,
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(
                      widget.config.borderRadius,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow.withValues(alpha: 0.2),
                        blurRadius: widget.config.elevation,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // アイコン
                      if (widget.config.showIcon &&
                          widget.type.icon != null) ...[
                        Icon(
                          widget.type.icon,
                          color: colors.icon,
                          size: widget.config.iconSize,
                        ),
                        const SizedBox(width: 12),
                      ],
                      // メッセージ
                      Expanded(
                        child: AppText(
                          widget.message,
                          style: TextStyle(color: colors.text, fontSize: 14),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // アクションボタン
                      if (widget.action != null) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            if (_dismissing) return;
                            widget.action!.onPressed();
                            _dismiss();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: colors.text,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: AppText(
                            widget.action!.label,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
