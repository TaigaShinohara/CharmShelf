import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/shared/icons/library_action_icons.dart';

void main() {
  testWidgets('catalog keeps its size in a larger thumbnail', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox.square(
            dimension: 96,
            child: CatalogizeIcon(size: 32),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(SvgPicture)), const Size(32, 32));
    expect(tester.takeException(), isNull);
  });

  for (final outlined in [false, true]) {
    for (final foreground in [Colors.black, Colors.white]) {
      testWidgets('catalog shapes survive tint: $outlined / $foreground', (
        tester,
      ) async {
        final boundaryKey = GlobalKey();
        const background = Color(0xFF326B92);
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: ColoredBox(
                  color: background,
                  child: IconTheme(
                    data: IconThemeData(size: 96, color: foreground),
                    child: outlined
                        ? const CatalogizeIcon.outlined()
                        : const CatalogizeIcon(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byKey(boundaryKey)), const Size(96, 96));
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          Color pixel(int x, int y) {
            final offset = (y * image.width + x) * 4;
            return Color.fromARGB(
              bytes.getUint8(offset + 3),
              bytes.getUint8(offset),
              bytes.getUint8(offset + 1),
              bytes.getUint8(offset + 2),
            );
          }

          // The folder and separate charm retain their rims in both variants.
          expect(pixel(10, 64), foreground);
          expect(pixel(41, 21), foreground);
          expect(pixel(63, 39), background);
          // Only the solid folder fills its center; the solid charm's sparkle
          // is a transparent cutout, while the outlined charm has a solid star.
          expect(pixel(48, 64), outlined ? background : foreground);
          expect(pixel(63, 21), outlined ? foreground : background);
          image.dispose();
        });
      });
    }
  }

  testWidgets('charm honors inherited sizing and disabled opacity', (
    tester,
  ) async {
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: const ColoredBox(
              color: Colors.white,
              child: IconTheme(
                data: IconThemeData(
                  size: 96,
                  color: Colors.black,
                  opacity: 0.5,
                ),
                child: CharmIcon(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(CharmIcon)), const Size(96, 96));
    await tester.runAsync(() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      // Fully inside the sparkle: half-opacity black over white is gray.
      final offset = (48 * image.width + 53) * 4;
      expect(bytes.getUint8(offset), closeTo(127, 1));
      expect(bytes.getUint8(offset + 1), closeTo(127, 1));
      expect(bytes.getUint8(offset + 2), closeTo(127, 1));
      image.dispose();
    });
  });
}
