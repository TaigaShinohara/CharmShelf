import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'feedback/app_menu_action_feedback.dart';

/// 統一されたデザインのポップアップメニューアイテム
class AppPopupMenuItem<T> extends PopupMenuItem<T> {
  /// ウィジェット指定のコンストラクタ
  const AppPopupMenuItem({
    super.key,
    super.value,
    super.onTap,
    super.enabled = true,
    super.height = 44.0,
    super.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    this._icon,
    this._iconData,
    required this._title,
    this._trailing,
    this._iconColor,
    this._textColor,
    this.showSelectionFeedback = true,
  }) : _subtitle = null,
       super(child: const SizedBox.shrink());

  /// テキスト文字列を受け取る簡易コンストラクタ
  AppPopupMenuItem.text({
    super.key,
    super.value,
    super.onTap,
    super.enabled = true,
    super.height = 44.0,
    super.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    this._iconData,
    this._icon,
    required String text,
    String? description,
    this._trailing,
    this._iconColor,
    this._textColor,
    this.showSelectionFeedback = true,
  }) : _title = Text(text),
       _subtitle = description == null ? null : Text(description),
       super(child: const SizedBox.shrink());

  final Widget? _icon;
  final IconData? _iconData;
  final Widget _title;
  final Widget? _subtitle;
  final Widget? _trailing;
  final Color? _iconColor;
  final Color? _textColor;

  /// false の場合はチェック表示を挟まず、通常のポップアップ項目として即時選択する。
  final bool showSelectionFeedback;

  @override
  PopupMenuItemState<T, AppPopupMenuItem<T>> createState() =>
      _AppPopupMenuItemState<T>();
}

class _AppPopupMenuItemState<T>
    extends PopupMenuItemState<T, AppPopupMenuItem<T>> {
  VoidCallback? _startFeedback;

  @override
  Widget? buildChild() {
    final iconData = widget._iconData;
    if (iconData == null || !widget.showSelectionFeedback) {
      return _buildContent(
        widget._icon ??
            (iconData == null
                ? null
                : Icon(
                    iconData,
                    size: AppIconSize.md,
                    color: widget._iconColor,
                  )),
      );
    }

    return AppMenuActionFeedback(
      icon: iconData,
      iconColor: widget._iconColor,
      onPressed: () {},
      onFeedbackComplete: _completeSelection,
      builder: (context, animatedIcon, onPressed) {
        _startFeedback = onPressed;
        return _buildContent(animatedIcon);
      },
    );
  }

  Widget _buildContent(Widget? icon) {
    return _AppMenuItemContent(
      icon: icon,
      title: widget._title,
      subtitle: widget._subtitle,
      trailing: widget._trailing,
      textColor: widget._textColor,
    );
  }

  @override
  void handleTap() {
    if (widget._iconData == null || !widget.showSelectionFeedback) {
      _completeSelection();
      return;
    }
    _startFeedback?.call();
  }

  void _completeSelection() {
    Navigator.pop<T>(context, widget.value);
    widget.onTap?.call();
  }
}

/// ポップアップメニュー内で設定のオン・オフを示すアイコン。
class AppMenuToggleIndicator extends StatelessWidget {
  const AppMenuToggleIndicator({
    super.key,
    required this.isOn,
    required this.onLabel,
    required this.offLabel,
  });

  final bool isOn;
  final String onLabel;
  final String offLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor = isOn
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Semantics(
      label: isOn ? onLabel : offLabel,
      child: ExcludeSemantics(
        child: Icon(
          isOn ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: AppIconSize.md,
          color: foregroundColor,
        ),
      ),
    );
  }
}

class _AppMenuItemContent extends StatelessWidget {
  const _AppMenuItemContent({
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.textColor,
  });

  final Widget? icon;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconWidget = icon != null
        ? IconTheme.merge(
            data: IconThemeData(
              size: AppIconSize.md,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            child: icon!,
          )
        : null;

    final titleWidget = DefaultTextStyle.merge(
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textColor ?? theme.colorScheme.onSurface,
      ),
      child: title,
    );
    final subtitleWidget = subtitle == null
        ? null
        : DefaultTextStyle.merge(
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: textColor ?? theme.colorScheme.onSurfaceVariant,
            ),
            child: subtitle!,
          );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (iconWidget != null) ...[
          iconWidget,
          const SizedBox(width: AppSpacing.md),
        ],
        Expanded(
          child: subtitleWidget == null
              ? titleWidget
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    titleWidget,
                    const SizedBox(height: AppSpacing.xs),
                    subtitleWidget,
                  ],
                ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          trailing!,
        ],
      ],
    );
  }
}
