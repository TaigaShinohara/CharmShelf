import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/shared/icons/library_action_icons.dart';

void main() {
  final cases = [
    (
      name: 'add',
      icon: const CharmIcon.add(),
      operation: const Offset(17.6, 14.9),
      gap: const Offset(15.4, 13.75),
    ),
    (
      name: 'bulk add',
      icon: const CharmIcon.bulkAdd(),
      operation: const Offset(17.6, 14.9),
      gap: const Offset(15.4, 13.75),
    ),
    (
      name: 'search',
      icon: const CharmIcon.search(),
      operation: const Offset(17.1, 10.8),
      gap: const Offset(17.1, 9.7),
    ),
    (
      name: 'filter',
      icon: const CharmIcon.filter(),
      operation: const Offset(18, 13),
      gap: const Offset(13.3, 13.5),
    ),
    (
      name: 'release',
      icon: const CatalogizeIcon.release(),
      operation: const Offset(15.75, 5.25),
      gap: const Offset(15.75, 6.5),
    ),
  ];

  for (final entry in cases) {
    for (final foreground in [Colors.black, Colors.white]) {
      testWidgets('${entry.name}: transparent gaps survive tint $foreground', (
        tester,
      ) async {
        final key = GlobalKey();
        const background = Color(0xFF326B92);
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: RepaintBoundary(
                key: key,
                child: ColoredBox(
                  color: background,
                  child: IconTheme(
                    data: IconThemeData(size: 384, color: foreground),
                    child: entry.icon,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          Color pixel(Offset point) {
            final x = (point.dx * image.width / 24).floor();
            final y = (point.dy * image.height / 24).floor();
            final offset = (y * image.width + x) * 4;
            return Color.fromARGB(
              bytes.getUint8(offset + 3),
              bytes.getUint8(offset),
              bytes.getUint8(offset + 1),
              bytes.getUint8(offset + 2),
            );
          }

          expect(
            pixel(entry.operation),
            foreground,
            reason: 'operation is visible',
          );
          expect(
            pixel(entry.gap),
            background,
            reason: 'cutout reveals background',
          );
          image.dispose();
        });
      });
    }
  }
}
