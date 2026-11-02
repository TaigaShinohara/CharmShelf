import 'package:flutter/material.dart';
import '../widgets.dart';

import '../../../core/theme/app_colors.dart';

/// アプリ内通知バー（上部バナー）。
///
/// 目的:
/// - プッシュ通知のような「重要だが、画面遷移やダイアログほど強制ではない」通知を表示
/// - カスタムWidgetで柔軟に表示できる
/// - スワイプで消せる / タップでアクション
class InAppNotification {
  InAppNotification._();

  static OverlayEntry? _entry;

  static void hide() {
    _entry?.remove();
    _entry = null;
  }

  static void show(
    BuildContext context, {
    required Widget child,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onTap,
    VoidCallback? onDismiss,
  }) {
    hide();

    final overlay = Overlay.of(context, rootOverlay: true);

    _entry = OverlayEntry(
      builder: (context) => _InAppNotificationWidget(
        duration: duration,
        onTap: onTap,
        onDismiss: () {
          hide();
          onDismiss?.call();
        },
        child: child,
      ),
    );

    overlay.insert(_entry!);
  }

  /// 標準の通知（タイトル/本文）を表示します。
  static void showNotification(
    BuildContext context, {
    required String title,
    String? body,
    Widget? leading,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onTap,
    VoidCallback? onDismiss,
  }) {
    show(
      context,
      duration: duration,
      onTap: onTap,
      onDismiss: onDismiss,
      child: _DefaultNotificationCard(
        title: title,
        body: body,
        leading: leading,
      ),
    );
  }
}

class _InAppNotificationWidget extends StatefulWidget {
  const _InAppNotificationWidget({
    required this.child,
    required this.duration,
    required this.onDismiss,
    this.onTap,
  });

  final Widget child;
  final Duration duration;
  final VoidCallback onDismiss;
  final VoidCallback? onTap;

  @override
  State<_InAppNotificationWidget> createState() =>
      _InAppNotificationWidgetState();
}

class _InAppNotificationWidgetState extends State<_InAppNotificationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 260),
      vsync: this,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _controller.forward();

    Future.delayed(widget.duration, () async {
      if (!mounted) return;
      await _dismiss();
    });
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Positioned(
      top: mediaQuery.padding.top + 8,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: widget.onTap == null
                  ? null
                  : () {
                      widget.onTap?.call();
                      _dismiss();
                    },
              onVerticalDragEnd: (details) {
                // 上方向にスワイプで閉じる
                if ((details.primaryVelocity ?? 0) < 0) {
                  _dismiss();
                }
              },
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _DefaultNotificationCard extends StatelessWidget {
  const _DefaultNotificationCard({
    required this.title,
    this.body,
    this.leading,
  });

  final String title;
  final String? body;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(title, style: Theme.of(context).textTheme.titleSmall),
                if (body != null && body!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  AppText(
                    body!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
