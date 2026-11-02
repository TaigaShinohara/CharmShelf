import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/theme/app_skeletonizer_config.dart';
import 'package:skeletonizer/skeletonizer.dart';

void main() {
  for (final platformBrightness in Brightness.values) {
    testWidgets(
      'loading shimmer follows app theme with $platformBrightness OS',
      (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue =
            platformBrightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        SkeletonizerConfigData? config;
        Future<void> show(ThemeMode mode) => tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: mode,
            themeAnimationDuration: Duration.zero,
            home: AppSkeletonizerConfig(
              child: Builder(
                builder: (context) {
                  config = SkeletonizerConfig.of(context);
                  return const Skeletonizer(child: Text('Loading'));
                },
              ),
            ),
          ),
        );

        await show(ThemeMode.dark);
        expect(config!.brightness, Brightness.dark);
        expect(
          config!.resolveEffect(config!.brightness!),
          const ShimmerEffect.dark(),
        );
        await show(ThemeMode.light);
        expect(config!.brightness, Brightness.light);
        expect(
          config!.resolveEffect(config!.brightness!),
          const ShimmerEffect(),
        );
        await show(ThemeMode.system);
        expect(config!.brightness, platformBrightness);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
