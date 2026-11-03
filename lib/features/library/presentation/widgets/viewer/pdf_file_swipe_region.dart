import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Gives file paging only a permitted, single-finger horizontal drag. The
/// permission is checked at pointer-down, so a newly selected PDF range is
/// protected immediately without waiting for a selection-change notification.
class PdfFileSwipeRegion extends StatefulWidget {
  const PdfFileSwipeRegion({
    super.key,
    required this.canStart,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
    required this.child,
  });

  final bool Function() canStart;
  final GestureDragStartCallback onStart;
  final GestureDragUpdateCallback onUpdate;
  final GestureDragEndCallback onEnd;
  final GestureDragCancelCallback onCancel;
  final Widget child;

  @override
  State<PdfFileSwipeRegion> createState() => _PdfFileSwipeRegionState();
}

class _PdfFileSwipeRegionState extends State<PdfFileSwipeRegion> {
  final _recognizer = _PdfFileSwipeRecognizer();

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _recognizer
      ..canStart = widget.canStart
      ..onStart = widget.onStart
      ..onUpdate = widget.onUpdate
      ..onEnd = widget.onEnd
      ..onCancel = widget.onCancel
      ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context)
      ..velocityTrackerBuilder = ScrollConfiguration.of(context)
          .velocityTrackerBuilder(context);
    return _SwipeHitTarget(
      onPointerDown: _recognizer.addPointer,
      child: widget.child,
    );
  }
}

class _SwipeHitTarget extends SingleChildRenderObjectWidget {
  const _SwipeHitTarget({required this.onPointerDown, required super.child});
  final void Function(PointerDownEvent) onPointerDown;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSwipeHitTarget(onPointerDown);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSwipeHitTarget renderObject,
  ) {
    renderObject.onPointerDown = onPointerDown;
  }
}

class _RenderSwipeHitTarget extends RenderProxyBox {
  _RenderSwipeHitTarget(this.onPointerDown);
  void Function(PointerDownEvent) onPointerDown;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    // Register before the PDF scale recognizer, including when the first move
    // crosses both recognizers' thresholds. Still hit-test the entire child so
    // vertical scroll, long presses, handles, taps and pinches stay native.
    result.add(BoxHitTestEntry(this, position));
    hitTestChildren(result, position: position);
    return true;
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (event is PointerDownEvent) onPointerDown(event);
  }
}

class _PdfFileSwipeRecognizer extends HorizontalDragGestureRecognizer {
  _PdfFileSwipeRecognizer()
    : super(supportedDevices: const {PointerDeviceKind.touch});

  late bool Function() canStart;
  final _pointers = <int>{};

  @override
  bool isPointerAllowed(PointerEvent event) =>
      (_pointers.isNotEmpty || canStart()) && super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _pointers.add(event.pointer);
    super.addAllowedPointer(event);
    if (_pointers.length > 1) {
      // Also cancel an already forwarded drag if a second finger joins it.
      onCancel?.call();
      resolve(GestureDisposition.rejected);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    super.handleEvent(event);
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointers.remove(event.pointer);
    }
  }

  @override
  void rejectGesture(int pointer) {
    _pointers.remove(pointer);
    super.rejectGesture(pointer);
  }

  @override
  void dispose() {
    _pointers.clear();
    super.dispose();
  }
}
