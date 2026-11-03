import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// A small round marker with a full finger target, anchored at the text edge.
class PdfSelectionHandle extends StatelessWidget {
  const PdfSelectionHandle({
    super.key,
    required this.isStart,
    required this.color,
  });

  final bool isStart;
  final Color color;
  static const targetSize = 48.0;

  static Offset offset(
    BuildContext context,
    PdfTextSelectionAnchor anchor,
    PdfViewerTextSelectionAnchorHandleState state,
  ) {
    final isStart = anchor.type == PdfTextSelectionAnchorType.a;
    final reversed =
        anchor.direction == PdfTextDirection.rtl ||
        anchor.direction == PdfTextDirection.vrtl;
    return Offset((isStart != reversed ? 1 : -1) * targetSize / 2, 0);
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: targetSize,
    child: ColoredBox(
      color: Colors.transparent,
      child: CustomPaint(painter: _HandlePainter(isStart, color)),
    ),
  );
}

class _HandlePainter extends CustomPainter {
  const _HandlePainter(this.isStart, this.color);
  final bool isStart;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx, isStart ? size.height : 0),
      center,
      paint,
    );
    canvas.drawCircle(center, 7, paint);
  }

  @override
  bool shouldRepaint(covariant _HandlePainter oldDelegate) =>
      isStart != oldDelegate.isStart || color != oldDelegate.color;
}
