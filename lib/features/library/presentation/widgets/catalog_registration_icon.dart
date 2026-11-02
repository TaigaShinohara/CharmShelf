import 'package:flutter/material.dart';

import '../../../../shared/widgets/icon/catalogize_icon.dart';

/// 元のフォルダ・ファイルがカタログになることを示すアイコン。
class CatalogRegistrationIcon extends StatelessWidget {
  const CatalogRegistrationIcon.folder({super.key, this.color})
    : isFolder = true;
  const CatalogRegistrationIcon.file({super.key, this.color})
    : isFolder = false;

  final bool isFolder;

  /// 塗りつぶしボタン等では、その面に対応する前景色で両方の図形を描く。
  /// 未指定なら、追加メニューで使う既存の配色を保つ。
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 48,
      height: 28,
      child: Stack(
        children: [
          CustomPaint(
            size: const Size(48, 28),
            painter: _CatalogRegistrationPainter(
              isFolder: isFolder,
              sourceColor: color ?? scheme.onSurfaceVariant,
              catalogColor: color ?? scheme.primary,
            ),
          ),
          Positioned(
            right: 0,
            top: 2,
            child: CatalogizeIcon.outlined(
              size: 22,
              color: color ?? scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogRegistrationPainter extends CustomPainter {
  const _CatalogRegistrationPainter({
    required this.isFolder,
    required this.sourceColor,
    required this.catalogColor,
  });

  final bool isFolder;
  final Color sourceColor;
  final Color catalogColor;

  @override
  void paint(Canvas canvas, Size size) {
    final source = Paint()
      ..color = sourceColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeJoin = StrokeJoin.round;
    final catalog = Paint()
      ..color = catalogColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeJoin = StrokeJoin.round;

    if (isFolder) {
      final folder = Path()
        ..moveTo(2, 9)
        ..lineTo(2, 21)
        ..quadraticBezierTo(2, 23, 4, 23)
        ..lineTo(16, 23)
        ..quadraticBezierTo(18, 23, 18, 21)
        ..lineTo(18, 10)
        ..quadraticBezierTo(18, 8, 16, 8)
        ..lineTo(10, 8)
        ..lineTo(8, 5)
        ..lineTo(4, 5)
        ..quadraticBezierTo(2, 5, 2, 9)
        ..close();
      canvas.drawPath(folder, source);
    } else {
      final file = Path()
        ..moveTo(4, 4)
        ..lineTo(12, 4)
        ..lineTo(18, 10)
        ..lineTo(18, 22)
        ..quadraticBezierTo(18, 24, 16, 24)
        ..lineTo(4, 24)
        ..quadraticBezierTo(2, 24, 2, 22)
        ..lineTo(2, 6)
        ..quadraticBezierTo(2, 4, 4, 4)
        ..close();
      canvas.drawPath(file, source);
      canvas.drawLine(const Offset(12, 4), const Offset(12, 10), source);
      canvas.drawLine(const Offset(12, 10), const Offset(18, 10), source);
      canvas.drawLine(const Offset(5, 15), const Offset(14, 15), source);
      canvas.drawLine(const Offset(5, 19), const Offset(12, 19), source);
    }

    // 取り込み対象を保ち、同じ共有記号のカタログへ進む矢印を添える。
    canvas.drawLine(const Offset(20, 14), const Offset(25, 14), catalog);
    canvas.drawLine(const Offset(22, 11), const Offset(25, 14), catalog);
    canvas.drawLine(const Offset(22, 17), const Offset(25, 14), catalog);
  }

  @override
  bool shouldRepaint(covariant _CatalogRegistrationPainter oldDelegate) =>
      isFolder != oldDelegate.isFolder ||
      sourceColor != oldDelegate.sourceColor ||
      catalogColor != oldDelegate.catalogColor;
}
