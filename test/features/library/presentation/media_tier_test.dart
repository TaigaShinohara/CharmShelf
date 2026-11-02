import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/styles/media_tier_styles.dart';

void main() {
  group('MediaTierExt Color Tests', () {
    testWidgets('MediaTier returns expected colors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(MediaTier.s.color(context), const Color(0xFFE57373));
              expect(MediaTier.a.color(context), const Color(0xFFFFB74D));
              expect(MediaTier.b.color(context), const Color(0xFF9575CD));
              expect(MediaTier.c.color(context), const Color(0xFF64B5F6));
              expect(MediaTier.d.color(context), const Color(0xFF81C784));
              expect(MediaTier.none.color(context), const Color(0xFFB0BEC5));
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });
}
