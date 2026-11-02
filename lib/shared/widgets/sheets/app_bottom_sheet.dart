import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:private_shelf/core/theme/app_tokens.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import '../widgets.dart';
import 'sheet_handle.dart';

/// カスタムコンテンツ対応の汎用ボトムシート。
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    super.key,
    this.title,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      0,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
    required this.child,
    this.scrollController,
    this.useSingleChildScrollView = true,
    this.headerAction,
    this.showCloseButton = false,
    this.dismissBlocked = false,
  });

  final String? title;
  final EdgeInsets padding;
  final Widget child;
  final ScrollController? scrollController;
  final bool useSingleChildScrollView;
  final Widget? headerAction;
  final bool showCloseButton;
  final bool dismissBlocked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: AppRadius.topXl,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          if (title != null || headerAction != null || showCloseButton) ...[
            Padding(
              padding: AppSpacing.horizontalLg,
              child: Row(
                children: [
                  if (title != null)
                    Expanded(
                      child: AppText(
                        title!,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (title == null) const Spacer(),
                  if (headerAction != null) ...[
                    headerAction!,
                    const SizedBox(width: 4),
                  ],
                  if (title != null || showCloseButton)
                    IconButton(
                      tooltip: l10n.tooltipClose,
                      icon: const Icon(Icons.close),
                      onPressed: dismissBlocked
                          ? null
                          : () => Navigator.maybePop(context),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (useSingleChildScrollView)
            Flexible(
              fit: FlexFit.loose,
              child: scrollController == null
                  ? SingleChildScrollView(
                      padding: padding,
                      physics: const ClampingScrollPhysics(),
                      child: child,
                    )
                  : PrimaryScrollController(
                      controller: scrollController!,
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: padding,
                        physics: const ClampingScrollPhysics(),
                        child: child,
                      ),
                    ),
            )
          else
            Flexible(
              fit: FlexFit.loose,
              child: scrollController == null
                  ? child
                  : PrimaryScrollController(
                      controller: scrollController!,
                      child: child,
                    ),
            ),
        ],
      ),
    );
  }
}

class _AdaptiveBottomSheetContent extends StatelessWidget {
  const _AdaptiveBottomSheetContent({
    required this.title,
    required this.useSingleChildScrollView,
    required this.scrollController,
    this.headerAction,
    required this.showCloseButton,
    this.dismissBlocked = false,
    this.child,
    this.builder,
  });

  final String? title;
  final bool useSingleChildScrollView;
  final ScrollController scrollController;
  final Widget? headerAction;
  final bool showCloseButton;
  final bool dismissBlocked;
  final Widget? child;
  final Widget Function(BuildContext, ScrollController)? builder;

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: title,
      scrollController: scrollController,
      useSingleChildScrollView: useSingleChildScrollView,
      headerAction: headerAction,
      showCloseButton: showCloseButton,
      dismissBlocked: dismissBlocked,
      child: builder != null ? builder!(context, scrollController) : child!,
    );
  }
}

Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  String? title,
  Widget? child,
  Widget Function(BuildContext, ScrollController)? builder,
  bool isScrollControlled = true,
  bool showDragHandle = false,
  bool useSafeArea = true,
  Color? backgroundColor,
  double initialChildSize = 0.95,
  double minChildSize = 0.0,
  double maxChildSize = 0.95,
  bool useSingleChildScrollView = true,
  Widget? headerAction,
  bool showCloseButton = false,
  bool useRootNavigator = true,
  ValueListenable<bool>? dismissBlocked,
}) {
  assert(child != null || builder != null);
  assert(minChildSize >= 0 && minChildSize <= 1);
  assert(initialChildSize >= 0 && initialChildSize <= 1);
  assert(maxChildSize >= 0 && maxChildSize <= 1);
  assert(minChildSize <= maxChildSize);
  assert(initialChildSize <= 1);

  // 最小位置でモーダルの終了アニメーションへ自然につなげるため、
  // 画面上にシートが残る中間サイズを挟まない。
  final effectiveMinChildSize = minChildSize;
  final effectiveMaxChildSize = maxChildSize < effectiveMinChildSize
      ? effectiveMinChildSize
      : maxChildSize;
  final effectiveInitialChildSize = initialChildSize
      .clamp(effectiveMinChildSize, effectiveMaxChildSize)
      .toDouble();

  var currentExtent = effectiveInitialChildSize;
  Widget buildSheet(BuildContext context, bool blocked) {
    final extent = currentExtent.clamp(
      effectiveMinChildSize,
      effectiveMaxChildSize,
    );
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        currentExtent = notification.extent;
        return false;
      },
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: blocked ? extent : effectiveInitialChildSize,
        minChildSize: blocked ? extent : effectiveMinChildSize,
        maxChildSize: blocked ? extent : effectiveMaxChildSize,
        snap: true,
        shouldCloseOnMinExtent: !blocked,
        builder: (context, scrollController) {
          return _AdaptiveBottomSheetContent(
            title: title,
            useSingleChildScrollView: useSingleChildScrollView,
            scrollController: scrollController,
            headerAction: headerAction,
            showCloseButton: showCloseButton,
            dismissBlocked: blocked,
            builder: builder,
            child: child,
          );
        },
      ),
    );
  }

  Widget sheetBuilder(BuildContext context) => dismissBlocked == null
      ? buildSheet(context, false)
      : ValueListenableBuilder<bool>(
          valueListenable: dismissBlocked,
          builder: (context, blocked, _) => buildSheet(context, blocked),
        );

  if (dismissBlocked != null) {
    final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
    final localizations = MaterialLocalizations.of(context);
    return navigator.push(
      _SaveAwareBottomSheetRoute<T>(
        dismissBlocked: dismissBlocked,
        builder: sheetBuilder,
        capturedThemes: InheritedTheme.capture(
          from: context,
          to: navigator.context,
        ),
        isScrollControlled: isScrollControlled,
        showDragHandle: showDragHandle,
        useSafeArea: useSafeArea,
        backgroundColor: Colors.transparent,
        constraints: const BoxConstraints(maxWidth: 640),
        barrierLabel: localizations.scrimLabel,
        barrierOnTapHint: localizations.scrimOnTapHint(
          localizations.bottomSheetLabel,
        ),
        modalBarrierColor: Theme.of(context).bottomSheetTheme.modalBarrierColor,
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    useSafeArea: useSafeArea,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 640),
    enableDrag: true,
    builder: sheetBuilder,
  );
}

/// Navigator.pop (used by header and native sheet drags) bypasses PopScope.
/// Protect that path as well as system back while a form save is in flight.
class _SaveAwareBottomSheetRoute<T> extends ModalBottomSheetRoute<T> {
  _SaveAwareBottomSheetRoute({
    required this.dismissBlocked,
    required super.builder,
    required super.isScrollControlled,
    super.capturedThemes,
    super.showDragHandle,
    super.useSafeArea,
    super.backgroundColor,
    super.constraints,
    super.barrierLabel,
    super.barrierOnTapHint,
    super.modalBarrierColor,
  });

  final ValueListenable<bool> dismissBlocked;

  @override
  bool get enableDrag => !dismissBlocked.value;

  @override
  bool get barrierDismissible => !dismissBlocked.value;

  @override
  RoutePopDisposition get popDisposition => dismissBlocked.value
      ? RoutePopDisposition.doNotPop
      : super.popDisposition;

  @override
  bool didPop(T? result) {
    if (dismissBlocked.value) {
      // A drag begun in the same frame as save may already have reversed the
      // animation. Keep the protected sheet visible as well as on the stack.
      controller?.forward();
      return false;
    }
    return super.didPop(result);
  }

  @override
  void install() {
    super.install();
    dismissBlocked.addListener(_guardChanged);
  }

  void _guardChanged() {
    changedInternalState();
    // Rebuild the native BottomSheet so its drag affordance also follows save.
    changedExternalState();
  }

  @override
  void dispose() {
    dismissBlocked.removeListener(_guardChanged);
    super.dispose();
  }
}
