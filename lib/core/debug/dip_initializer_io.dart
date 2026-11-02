import 'dip_feature_registry.dart';
import 'features/action_log_toggle_feature.dart';
import 'features/app_icon_feature.dart';
import 'features/cache_clear_feature.dart';
import 'features/crash_log_viewer_feature.dart';
import 'features/crash_test_feature.dart';
import 'features/db_viewer_feature.dart';
import 'features/dip_reset_feature.dart';
import 'features/env_info_feature.dart';
import 'features/env_switch_feature.dart';
import 'features/feature_flags_feature.dart';
import 'features/locale_switch_feature.dart';
import 'features/log_viewer_feature.dart';
import 'features/mock_data_feature.dart';
import 'features/network_inspector_feature.dart';
import 'features/performance_feature.dart';
import 'features/push_test_feature.dart';
import 'features/route_info_feature.dart';
import 'features/shared_prefs_feature.dart';
import 'features/slow_animations_feature.dart';
import 'features/snackbar_feature.dart';
import 'features/text_scale_feature.dart';
import 'features/theme_color_feature.dart';
import 'features/theme_switch_feature.dart';
import 'features/ui_preview_feature.dart';
import 'features/widget_inspector_feature.dart';

/// DIPのデフォルト機能を初期化する（iOS/Android/desktop用）
///
/// アプリ起動時に呼び出してください。
void initializeDip() {
  if (DipFeatureRegistry.instance.isInitialized) return;

  DipFeatureRegistry.instance.initializeDefaults([
    // === 情報表示系 ===
    EnvInfoFeature(),
    RouteInfoFeature(),
    LogViewerFeature(),
    CrashLogViewerFeature(),

    // === データ操作系 ===
    CacheClearFeature(),
    SharedPrefsFeature(),
    DbViewerFeature(),
    MockDataFeature(),

    // === UI/UX調整系 ===
    ThemeSwitchFeature(),
    ThemeColorFeature(),
    TextScaleFeature(),
    AppIconFeature(),
    LocaleSwitchFeature(),
    SlowAnimationsFeature(),
    SnackBarFeature(),
    UiPreviewFeature(),

    // === 開発・デバッグ系 ===
    ActionLogToggleFeature(),
    PerformanceFeature(),
    WidgetInspectorFeature(),
    NetworkInspectorFeature(),
    FeatureFlagsFeature(),
    EnvSwitchFeature(),
    DipResetFeature(),

    // === テスト系 ===
    CrashTestFeature(),
    PushTestFeature(),
  ]);
}
