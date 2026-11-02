import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/utils/date_time_utils.dart';

void main() {
  group('DateTimeUtils.formatCompactDate', () {
    testWidgets('今年の日付は M/d HH:mm 形式でフォーマットされること', (tester) async {
      late BuildContext testContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              testContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final now = DateTime(2026, 8, 20, 14, 30);
      final targetDate = DateTime(2026, 8, 5, 9, 15);

      final result = DateTimeUtils.formatCompactDate(
        testContext,
        targetDate,
        now: now,
      );
      expect(result, '8/5 09:15');
    });

    testWidgets('過去年の日付は yyyy/M/d HH:mm 形式でフォーマットされること', (tester) async {
      late BuildContext testContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              testContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final now = DateTime(2026, 8, 20, 14, 30);
      final targetDate = DateTime(2025, 12, 31, 23, 59);

      final result = DateTimeUtils.formatCompactDate(
        testContext,
        targetDate,
        now: now,
      );
      expect(result, '2025/12/31 23:59');
    });
  });
}
