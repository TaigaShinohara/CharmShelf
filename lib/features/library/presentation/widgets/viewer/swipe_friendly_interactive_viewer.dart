import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class SwipeFriendlyInteractiveViewer extends StatefulWidget {
  final double minScale;
  final double maxScale;
  final Widget child;
  final VoidCallback? onTap;
  final GestureDragStartCallback? onUnscaledHorizontalDragStart;
  final GestureDragUpdateCallback? onUnscaledHorizontalDragUpdate;
  final GestureDragEndCallback? onUnscaledHorizontalDragEnd;
  final GestureDragCancelCallback? onUnscaledHorizontalDragCancel;

  const SwipeFriendlyInteractiveViewer({
    super.key,
    this.minScale = 1.0,
    this.maxScale = 4.0,
    required this.child,
    this.onTap,
    this.onUnscaledHorizontalDragStart,
    this.onUnscaledHorizontalDragUpdate,
    this.onUnscaledHorizontalDragEnd,
    this.onUnscaledHorizontalDragCancel,
  }) : assert(
         (onUnscaledHorizontalDragStart == null &&
                 onUnscaledHorizontalDragUpdate == null &&
                 onUnscaledHorizontalDragEnd == null &&
                 onUnscaledHorizontalDragCancel == null) ||
             (onUnscaledHorizontalDragStart != null &&
                 onUnscaledHorizontalDragUpdate != null &&
                 onUnscaledHorizontalDragEnd != null &&
                 onUnscaledHorizontalDragCancel != null),
         'Unscaled horizontal drag callbacks must be supplied together.',
       );

  @override
  State<SwipeFriendlyInteractiveViewer> createState() =>
      _SwipeFriendlyInteractiveViewerState();
}

class _SwipeFriendlyInteractiveViewerState
    extends State<SwipeFriendlyInteractiveViewer>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformationController;
  late final ValueNotifier<bool> _isScaledNotifier;
  late final AnimationController _animationController;
  Animation<Matrix4>? _zoomAnimation;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _isScaledNotifier = ValueNotifier<bool>(false);
    _transformationController.addListener(_onTransformChanged);
    _animationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 240),
        )..addListener(() {
          if (_zoomAnimation != null) {
            _transformationController.value = _zoomAnimation!.value;
          }
        });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformationController.removeListener(_onTransformChanged);
    _transformationController.dispose();
    _isScaledNotifier.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final isScaled = scale > 1.01;
    if (_isScaledNotifier.value != isScaled) {
      _isScaledNotifier.value = isScaled;
    }
  }

  void _handleDoubleTap(TapDownDetails details) {
    if (_animationController.isAnimating) return;

    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();

    final targetMatrix = Matrix4.identity();
    if (currentScale <= 1.05) {
      // 拡大 (2.5倍)
      const targetScale = 2.5;
      final position = details.localPosition;
      final x = -position.dx * (targetScale - 1);
      final y = -position.dy * (targetScale - 1);
      targetMatrix
        ..setTranslationRaw(x, y, 0.0)
        ..setEntry(0, 0, targetScale)
        ..setEntry(1, 1, targetScale);
    } // すでに拡大されている場合は targetMatrix (identity = 1.0) に戻る

    _zoomAnimation = Matrix4Tween(begin: currentMatrix, end: targetMatrix)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isScaledNotifier,
      builder: (context, isScaled, _) {
        final canForwardHorizontalDrag =
            widget.onUnscaledHorizontalDragStart != null &&
            widget.onUnscaledHorizontalDragUpdate != null &&
            widget.onUnscaledHorizontalDragEnd != null &&
            widget.onUnscaledHorizontalDragCancel != null;
        final scrollBehavior = ScrollConfiguration.of(context);
        final gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
        final interactiveChild = !canForwardHorizontalDrag
            ? widget.child
            : RawGestureDetector(
                behavior: HitTestBehavior.opaque,
                gestures: isScaled
                    ? const {}
                    : {
                        _SinglePointerHorizontalDragGestureRecognizer:
                            GestureRecognizerFactoryWithHandlers<
                              _SinglePointerHorizontalDragGestureRecognizer
                            >(
                              _SinglePointerHorizontalDragGestureRecognizer.new,
                              (recognizer) {
                                recognizer
                                  ..onStart =
                                      widget.onUnscaledHorizontalDragStart
                                  ..onUpdate =
                                      widget.onUnscaledHorizontalDragUpdate
                                  ..onEnd = widget.onUnscaledHorizontalDragEnd
                                  ..onCancel =
                                      widget.onUnscaledHorizontalDragCancel
                                  ..velocityTrackerBuilder = scrollBehavior
                                      .velocityTrackerBuilder(context)
                                  ..gestureSettings = gestureSettings
                                  ..supportedDevices =
                                      scrollBehavior.dragDevices;
                              },
                            ),
                      },
                child: widget.child,
              );
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onDoubleTapDown: _handleDoubleTap,
          onDoubleTap: () {},
          onTap: () {
            if (isScaled) return;
            widget.onTap?.call();
          },
          child: InteractiveViewer(
            transformationController: _transformationController,
            panEnabled: isScaled,
            scaleEnabled: true,
            minScale: widget.minScale,
            maxScale: widget.maxScale,
            clipBehavior: Clip.none,
            interactionEndFrictionCoefficient: 0.0000135,
            child: interactiveChild,
          ),
        );
      },
    );
  }
}

/// Gives an unscaled one-finger horizontal drag priority over
/// [InteractiveViewer]'s scale recognizer without taking two-finger pinches.
class _SinglePointerHorizontalDragGestureRecognizer
    extends HorizontalDragGestureRecognizer {
  final Set<int> _activePointers = <int>{};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _activePointers.add(event.pointer);
    if (_activePointers.length > 1) {
      resolve(GestureDisposition.rejected);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    super.handleEvent(event);
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _activePointers.remove(event.pointer);
    }
  }

  @override
  void rejectGesture(int pointer) {
    _activePointers.remove(pointer);
    super.rejectGesture(pointer);
  }

  @override
  void dispose() {
    _activePointers.clear();
    super.dispose();
  }
}
