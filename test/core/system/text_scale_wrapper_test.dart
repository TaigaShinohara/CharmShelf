import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/system/text_scale_wrapper.dart';

void main() {
  testWidgets('TextScaleWrapper clamps text scale to the configured range', (
    tester,
  ) async {
    double? observedScale;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
        child: TextScaleWrapper(
          child: Builder(
            builder: (context) {
              observedScale = MediaQuery.of(context).textScaler.scale(1.0);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(observedScale, 2.0);
  });

  testWidgets('TextScaleWrapper preserves smaller scales above minimum', (
    tester,
  ) async {
    double? observedScale;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(0.8)),
        child: TextScaleWrapper(
          child: Builder(
            builder: (context) {
              observedScale = MediaQuery.of(context).textScaler.scale(1.0);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(observedScale, 1.0);
  });
}
