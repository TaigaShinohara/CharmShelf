import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/config/feature_flags.dart';
import 'package:private_shelf/core/debug/dip.dart';

/// DIP（デバッグパネル）による実行時オーバーライド設定
class DipRuntimeOverrides {
  final bool showPerformanceOverlay;
  final bool showSemanticsDebugger;
  final double textScale;
  final Locale? locale;
  final CustomThemeColors? customColors;

  const DipRuntimeOverrides({
    this.showPerformanceOverlay = false,
    this.showSemanticsDebugger = false,
    this.textScale = 1.0,
    this.locale,
    this.customColors,
  });

  /// Riverpod から現在の DIP オーバーライド状態を解決する
  static DipRuntimeOverrides read(WidgetRef ref) {
    if (!FeatureFlags.enableDip) {
      return const DipRuntimeOverrides();
    }

    final inspector = ref.watch(widgetInspectorProvider);
    return DipRuntimeOverrides(
      showPerformanceOverlay: ref.watch(performanceOverlayProvider),
      showSemanticsDebugger: inspector.showSemanticsDebugger,
      textScale: ref.watch(textScaleProvider),
      locale: ref.watch(localeProvider),
      customColors: ref.watch(customThemeColorsProvider),
    );
  }
}

/// アプリ全体を DIP ジェスチャーおよびデバッグラッパーで囲むウィジェット
class DipAppWrapper extends StatelessWidget {
  final Widget child;

  const DipAppWrapper({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    if (!FeatureFlags.enableDip) {
      return child;
    }
    return DipGestureWrapper(child: child);
  }
}
