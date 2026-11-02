/// DIP (Developer In-App Panel) システム
///
/// 開発者向けのデバッグメニューを提供します。
/// 3本指ダブルタップまたは設定画面から呼び出すことができます。
library;

export 'dip_action_log.dart';
export 'dip_controller.dart';
export 'dip_feature.dart';
export 'dip_feature_registry.dart';
export 'dip_gesture_wrapper.dart';
export 'dip_initializer.dart';
export 'dip_menu.dart';
export 'dip_overlay.dart';
export 'dip_app_configurator.dart';

// Features
export 'features/performance_feature.dart' show performanceOverlayProvider;
export 'features/text_scale_feature.dart' show textScaleProvider;
export 'features/locale_switch_feature.dart' show localeProvider;
export 'features/widget_inspector_feature.dart'
    show widgetInspectorProvider, WidgetInspectorState;
export 'features/env_switch_feature.dart'
    show appEnvironmentProvider, AppEnvironment;
export 'features/theme_color_feature.dart'
    show customThemeColorsProvider, CustomThemeColors;
