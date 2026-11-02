import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';
import '../text/app_text.dart';

/// モダンでプレミアムな質感を持つ汎用ダイアログ
class ModernDialog extends StatelessWidget {
  const ModernDialog({
    super.key,
    this.title,
    required this.child,
    this.actions,
    this.maxWidth = 600,
    this.contentPadding = const EdgeInsets.fromLTRB(24, 20, 24, 8),
    this.showBlur = true,
  });

  final String? title;
  final Widget child;
  final List<Widget>? actions;
  final double maxWidth;
  final EdgeInsets contentPadding;
  final bool showBlur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Widget dialogContent = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: AppText(
                  title!,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: contentPadding,
                child: child,
              ),
            ),
            if (actions != null && actions!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: actions!.map((action) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: action,
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 背景ぼかしと半透明のコンテナ
          if (showBlur)
            ClipRRect(
              borderRadius: AppRadius.radiusXl,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.85),
                    borderRadius: AppRadius.radiusXl,
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadowColor.withValues(alpha: 0.1),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: dialogContent,
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: AppRadius.radiusXl,
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
              child: dialogContent,
            ),
        ],
      ),
    );
  }
}

/// モダンなダイアログを表示する便利な関数
Future<T?> showModernDialog<T>(
  BuildContext context, {
  String? title,
  required Widget child,
  List<Widget>? actions,
  double maxWidth = 600,
  bool barrierDismissible = true,
  bool useRootNavigator = false,
  bool showBlur = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 200),
    useRootNavigator: useRootNavigator,
    pageBuilder: (context, animation, secondaryAnimation) {
      return ModernDialog(
        title: title,
        actions: actions,
        maxWidth: maxWidth,
        showBlur: showBlur,
        child: child,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curve = animation.status == AnimationStatus.reverse
          ? Curves.easeInCubic
          : Curves.easeOutCubic;

      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: curve),
        child: ScaleTransition(
          scale: Tween<double>(
            begin: 0.92,
            end: 1.0,
          ).animate(CurvedAnimation(parent: animation, curve: curve)),
          child: child,
        ),
      );
    },
  );
}
