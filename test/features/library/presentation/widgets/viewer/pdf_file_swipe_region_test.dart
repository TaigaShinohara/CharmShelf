import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/presentation/widgets/viewer/pdf_file_swipe_region.dart';

import '../../../../../helpers/test_helpers.dart';

void main() {
  testWidgets('late pinch captures a finger outside the moving PDF hit area', (
    tester,
  ) async {
    var outsideTaps = 0;
    var cancels = 0;
    final events = <PointerEvent>[];
    await tester.pumpWidget(
      createLocalizedApp(
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => outsideTaps++,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 240,
              height: 300,
              child: PdfFileSwipeRegion(
                canStart: () => true,
                onStart: (_) {},
                onUpdate: (_) {},
                onEnd: (_) {},
                onCancel: () => cancels++,
                onPinchEvent: events.add,
                child: const ColoredBox(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
    final center = tester.getCenter(find.byType(PdfFileSwipeRegion));
    final a = await tester.startGesture(center, pointer: 51);
    await a.moveBy(const Offset(-60, 0));
    await tester.pump();
    final outside = center + const Offset(300, 0);
    final b = await tester.startGesture(outside, pointer: 52);
    await a.moveBy(const Offset(-20, 0));
    await b.moveBy(const Offset(20, 0));
    await tester.pump();
    expect(cancels, 1);
    expect(
      events.whereType<PointerPanZoomUpdateEvent>().last.scale,
      greaterThan(1),
    );
    await b.up();
    await a.up();
    await tester.pumpAndSettle();
    expect(outsideTaps, 0);
    await tester.tapAt(outside);
    await tester.pumpAndSettle();
    expect(
      outsideTaps,
      1,
      reason: 'Pointer capture must end with this gesture',
    );
  });

  for (final liftFirstFingerFirst in [true, false]) {
    testWidgets('a late second finger hands an accepted file drag to pinch '
        '(first finger lifts first: $liftFirstFingerFirst)', (tester) async {
      var starts = 0;
      var cancels = 0;
      var ends = 0;
      var nativeStarts = 0;
      final events = <PointerEvent>[];
      await tester.pumpWidget(
        createLocalizedApp(
          PdfFileSwipeRegion(
            canStart: () => true,
            onStart: (_) => starts++,
            onUpdate: (_) {},
            onEnd: (_) => ends++,
            onCancel: () => cancels++,
            onPinchEvent: events.add,
            child: GestureDetector(
              onScaleStart: (_) => nativeStarts++,
              child: const ColoredBox(
                color: Colors.white,
                child: SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      final center = tester.getCenter(find.byType(PdfFileSwipeRegion));
      final a = await tester.startGesture(center, pointer: 41);
      await a.moveBy(const Offset(-180, 0));
      await tester.pump();
      expect(starts, 1);
      final b = await tester.startGesture(
        center + const Offset(40, 0),
        pointer: 42,
      );
      await a.moveBy(const Offset(-70, 0));
      await b.moveBy(const Offset(70, 0));
      await tester.pump();
      expect(cancels, 1);
      expect(ends, 0);
      expect(nativeStarts, 0, reason: 'Do not also pan the PDF natively');
      expect(events.first, isA<PointerPanZoomStartEvent>());
      expect(
        events.whereType<PointerPanZoomUpdateEvent>().last.scale,
        greaterThan(1),
      );
      final firstToLift = liftFirstFingerFirst ? a : b;
      final remaining = liftFirstFingerFirst ? b : a;
      await firstToLift.up();
      await remaining.moveBy(const Offset(0, -30));
      await tester.pump();
      final pan = events.whereType<PointerPanZoomUpdateEvent>().last;
      expect(pan.scale, 1);
      expect(pan.pan, const Offset(0, -30));
      await remaining.up();
      await tester.pumpAndSettle();
      expect(events.whereType<PointerPanZoomStartEvent>().length, 2);
      expect(events.whereType<PointerPanZoomEndEvent>().length, 2);
      expect(ends, 0);
      await tester.drag(find.byType(PdfFileSwipeRegion), const Offset(-180, 0));
      await tester.pumpAndSettle();
      expect(starts, 2);
      expect(ends, 1);
    });
  }

  testWidgets('vertical intent releases the PDF before the larger pan slop', (
    tester,
  ) async {
    var nativeStarts = 0;
    var forwarded = 0;
    await tester.pumpWidget(
      createLocalizedApp(
        MediaQuery(
          data: const MediaQueryData(
            gestureSettings: DeviceGestureSettings(touchSlop: 18),
          ),
          child: PdfFileSwipeRegion(
            canStart: () => true,
            onStart: (_) => forwarded++,
            onUpdate: (_) {},
            onEnd: (_) {},
            onCancel: () {},
            onPinchEvent: (_) {},
            child: GestureDetector(
              onScaleStart: (_) => nativeStarts++,
              child: const ColoredBox(
                color: Colors.white,
                child: SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PdfFileSwipeRegion)),
    );
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    expect(nativeStarts, 1);
    expect(forwarded, 0);
    await gesture.moveBy(const Offset(0, -80));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'a coarse first horizontal move still beats the PDF pan recognizer',
    (tester) async {
      var forwarded = 0;
      var horizontalDistance = 0.0;
      await tester.pumpWidget(
        createLocalizedApp(
          PdfFileSwipeRegion(
            canStart: () => true,
            onStart: (_) => forwarded++,
            onUpdate: (details) => horizontalDistance += details.delta.dx,
            onEnd: (_) {},
            onCancel: () {},
            onPinchEvent: (_) {},
            child: GestureDetector(
              onScaleStart: (_) {},
              child: const ColoredBox(
                color: Colors.white,
                child: SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PdfFileSwipeRegion)),
      );
      await gesture.moveBy(const Offset(-180, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(forwarded, 1);
      expect(
        horizontalDistance,
        -180,
        reason: 'The accepted first move must also move the file page',
      );
    },
  );

  for (final allowed in [true, false]) {
    testWidgets(
      'horizontal file drag permission $allowed is checked at touch-down',
      (tester) async {
        var permitted = allowed;
        var forwarded = 0;
        var pdfPans = 0;
        await tester.pumpWidget(
          createLocalizedApp(
            PdfFileSwipeRegion(
              canStart: () => permitted,
              onStart: (_) => forwarded++,
              onUpdate: (_) {},
              onEnd: (_) {},
              onCancel: () {},
              onPinchEvent: (_) {},
              child: GestureDetector(
                onScaleStart: (_) => pdfPans++,
                child: const ColoredBox(
                  color: Colors.white,
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ),
        );
        await tester.drag(
          find.byType(PdfFileSwipeRegion),
          const Offset(-180, 0),
        );
        await tester.pumpAndSettle();
        expect(forwarded, allowed ? 1 : 0);
        expect(pdfPans, allowed ? 0 : 1);
        // Selection/zoom can change without rebuilding the gesture widget.
        permitted = !allowed;
        await tester.drag(
          find.byType(PdfFileSwipeRegion),
          const Offset(-180, 0),
        );
        await tester.pumpAndSettle();
        expect(forwarded, 1);
        expect(pdfPans, 1);
      },
    );
  }

  testWidgets(
    'vertical scroll, long press and two-finger pinch stay with the PDF',
    (tester) async {
      var forwarded = 0;
      var scales = 0;
      var longPresses = 0;
      await tester.pumpWidget(
        createLocalizedApp(
          PdfFileSwipeRegion(
            canStart: () => true,
            onStart: (_) => forwarded++,
            onUpdate: (_) {},
            onEnd: (_) {},
            onCancel: () {},
            onPinchEvent: (_) {},
            child: GestureDetector(
              onScaleStart: (_) => scales++,
              onLongPressStart: (_) => longPresses++,
              child: const ColoredBox(
                color: Colors.white,
                child: SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      await tester.drag(find.byType(PdfFileSwipeRegion), const Offset(0, -140));
      await tester.pumpAndSettle();
      expect(scales, 1);
      await tester.longPress(find.byType(PdfFileSwipeRegion));
      expect(longPresses, 1);
      final center = tester.getCenter(find.byType(PdfFileSwipeRegion));
      final a = await tester.startGesture(
        center - const Offset(30, 0),
        pointer: 11,
      );
      final b = await tester.startGesture(
        center + const Offset(30, 0),
        pointer: 12,
      );
      await a.moveBy(const Offset(-80, 0));
      await b.moveBy(const Offset(80, 0));
      await tester.pump();
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      expect(scales, 2);
      expect(forwarded, 0);
    },
  );

  testWidgets('mouse text drags are never file swipes', (tester) async {
    var forwarded = 0;
    await tester.pumpWidget(
      createLocalizedApp(
        PdfFileSwipeRegion(
          canStart: () => true,
          onStart: (_) => forwarded++,
          onUpdate: (_) {},
          onEnd: (_) {},
          onCancel: () {},
          onPinchEvent: (_) {},
          child: const ColoredBox(
            color: Colors.white,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PdfFileSwipeRegion)),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(-180, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(forwarded, 0);
  });
}
