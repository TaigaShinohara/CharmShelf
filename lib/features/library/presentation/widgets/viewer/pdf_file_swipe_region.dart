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
    required this.onPinchEvent,
    required this.child,
  });

  final bool Function() canStart;
  final GestureDragStartCallback onStart;
  final GestureDragUpdateCallback onUpdate;
  final GestureDragEndCallback onEnd;
  final GestureDragCancelCallback onCancel;

  /// Overlay-owned pan/zoom events in this viewport's local coordinates.
  final ValueChanged<PointerEvent> onPinchEvent;
  final Widget child;

  @override
  State<PdfFileSwipeRegion> createState() => _PdfFileSwipeRegionState();
}

class _PdfFileSwipeRegionState extends State<PdfFileSwipeRegion> {
  final _recognizer = _PdfFileSwipeRecognizer();
  final _additionalPointerRecognizer = EagerGestureRecognizer(
    supportedDevices: const {PointerDeviceKind.touch},
  );
  final _positions = <int, Offset>{};
  final _outsidePointers = <int>{};
  bool _capturing = false;
  bool _fileDragActive = false;
  bool _pinching = false;
  Offset _viewportOrigin = Offset.zero;
  Offset _pinchOrigin = Offset.zero;
  Offset _lastPan = Offset.zero;
  double _initialSpan = 0;

  void _captureAdditionalPointers() {
    if (_capturing) return;
    _capturing = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handleOutsidePointer);
  }

  void _releaseAdditionalPointers() {
    if (!_capturing) return;
    _capturing = false;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(
      _handleOutsidePointer,
    );
    _outsidePointers.clear();
  }

  void _handleOutsidePointer(PointerEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    if (event is PointerDownEvent &&
        (_fileDragActive || _pinching) &&
        !_positions.containsKey(event.pointer)) {
      // The PDF slides with its file page. A new finger can land outside its
      // current hit rectangle, so capture it before the new arena closes.
      _outsidePointers.add(event.pointer);
      _additionalPointerRecognizer.addPointer(event);
      _handlePointer(event);
    } else if (_outsidePointers.contains(event.pointer)) {
      _handlePointer(event);
      if (event is PointerUpEvent || event is PointerCancelEvent) {
        _outsidePointers.remove(event.pointer);
      }
    }
  }

  Offset get _focalPoint =>
      _positions.values.reduce((a, b) => a + b) / _positions.length.toDouble() -
      _viewportOrigin;

  double get _span => _positions.length < 2
      ? 0
      : (_positions.values.first - _positions.values.last).distance;

  void _startPinch(Duration timeStamp) {
    _pinchOrigin = _focalPoint;
    _lastPan = Offset.zero;
    _initialSpan = _span;
    widget.onPinchEvent(
      PointerPanZoomStartEvent(timeStamp: timeStamp, position: _pinchOrigin),
    );
  }

  void _endPinch(Duration timeStamp) {
    widget.onPinchEvent(
      PointerPanZoomEndEvent(timeStamp: timeStamp, position: _pinchOrigin),
    );
  }

  void _handlePointer(PointerEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    if (event is PointerDownEvent) {
      if (_positions.isEmpty) {
        _viewportOrigin = (context.findRenderObject()! as RenderBox)
            .localToGlobal(Offset.zero);
      }
      if (_pinching) _endPinch(event.timeStamp);
      _positions[event.pointer] = event.position;
      if (_fileDragActive) {
        // The PDF scale recognizer already lost the first pointer's arena.
        // Keep both touches here and use pdfrx's overlay pan/zoom API instead
        // of trying to give an accepted pointer back to another recognizer.
        _fileDragActive = false;
        _pinching = true;
        widget.onCancel();
      }
      if (_pinching) {
        _startPinch(event.timeStamp);
      } else {
        _recognizer.addPointer(event);
      }
    } else if (event is PointerMoveEvent &&
        _positions.containsKey(event.pointer)) {
      _positions[event.pointer] = event.position;
      if (!_pinching) return;
      final pan = _focalPoint - _pinchOrigin;
      widget.onPinchEvent(
        PointerPanZoomUpdateEvent(
          timeStamp: event.timeStamp,
          position: _pinchOrigin,
          pan: pan,
          panDelta: pan - _lastPan,
          scale: _initialSpan > 0 ? _span / _initialSpan : 1,
        ),
      );
      _lastPan = pan;
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      if (_pinching) _endPinch(event.timeStamp);
      _positions.remove(event.pointer);
      if (_pinching && _positions.isNotEmpty) {
        // Reset the scale baseline when a finger lifts, preserving the PDF's
        // current transform and allowing the remaining finger to keep panning.
        _startPinch(event.timeStamp);
      } else if (_positions.isEmpty) {
        _pinching = false;
        if (!_fileDragActive) _releaseAdditionalPointers();
      }
    }
  }

  @override
  void dispose() {
    _releaseAdditionalPointers();
    _additionalPointerRecognizer.dispose();
    _recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _recognizer
      ..dragStartBehavior = DragStartBehavior.down
      ..canStart = widget.canStart
      ..onStart = (details) {
        _fileDragActive = true;
        _captureAdditionalPointers();
        widget.onStart(details);
      }
      ..onUpdate = (details) {
        if (_fileDragActive) widget.onUpdate(details);
      }
      ..onEnd = (details) {
        if (!_fileDragActive) return;
        _fileDragActive = false;
        _releaseAdditionalPointers();
        widget.onEnd(details);
      }
      ..onCancel = () {
        if (!_fileDragActive) return;
        _fileDragActive = false;
        _releaseAdditionalPointers();
        widget.onCancel();
      }
      ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context)
      ..velocityTrackerBuilder = ScrollConfiguration.of(context)
          .velocityTrackerBuilder(context);
    return _SwipeHitTarget(
      onPointer: _handlePointer,
      ownsAdditionalPointers: () => _fileDragActive || _pinching,
      child: widget.child,
    );
  }
}

class _SwipeHitTarget extends SingleChildRenderObjectWidget {
  const _SwipeHitTarget({
    required this.onPointer,
    required this.ownsAdditionalPointers,
    required super.child,
  });
  final ValueChanged<PointerEvent> onPointer;
  final bool Function() ownsAdditionalPointers;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSwipeHitTarget(onPointer, ownsAdditionalPointers);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSwipeHitTarget renderObject,
  ) {
    renderObject
      ..onPointer = onPointer
      ..ownsAdditionalPointers = ownsAdditionalPointers;
  }
}

class _RenderSwipeHitTarget extends RenderProxyBox {
  _RenderSwipeHitTarget(this.onPointer, this.ownsAdditionalPointers);
  ValueChanged<PointerEvent> onPointer;
  bool Function() ownsAdditionalPointers;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    // Register before the PDF scale recognizer, including when the first move
    // crosses both recognizers' thresholds. Normally the child also receives
    // every touch. Once a file drag wins, additional fingers belong to the
    // overlay handoff; letting the PDF see only the new finger would pan twice.
    result.add(BoxHitTestEntry(this, position));
    if (!ownsAdditionalPointers()) {
      hitTestChildren(result, position: position);
    }
    return true;
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    onPointer(event);
  }
}

class _PdfFileSwipeRecognizer extends HorizontalDragGestureRecognizer {
  _PdfFileSwipeRecognizer()
    : super(supportedDevices: const {PointerDeviceKind.touch});

  late bool Function() canStart;
  final _pointers = <int>{};
  Offset? _origin;
  bool _accepted = false;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      (_pointers.isNotEmpty || canStart()) && super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_pointers.isEmpty) {
      _origin = event.position;
      _accepted = false;
    }
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
    final origin = _origin;
    if (!_accepted && event is PointerMoveEvent && origin != null) {
      final delta = event.position - origin;
      if (delta.dy.abs() > (gestureSettings?.touchSlop ?? kTouchSlop) &&
          delta.dy.abs() > delta.dx.abs()) {
        // A pending horizontal recognizer must not force native scale/pan to
        // wait for its larger pan slop before a vertical scroll can start.
        resolve(GestureDisposition.rejected);
        return;
      }
    }
    super.handleEvent(event);
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointers.remove(event.pointer);
    }
  }

  @override
  void acceptGesture(int pointer) {
    _accepted = true;
    super.acceptGesture(pointer);
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
