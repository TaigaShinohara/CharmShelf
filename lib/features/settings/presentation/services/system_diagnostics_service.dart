// Presentation-facing diagnostic report composed from current UI settings.
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/feedback/feedback_providers.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/logger/log_tag.dart';
import '../../../../core/providers/package_info_provider.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../permission/data/repositories/permission_repository_impl.dart';
import '../providers/app_mode_provider.dart';
import '../providers/feature_customization_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/show_hidden_files_provider.dart';
import '../providers/privacy_settings_provider.dart';

part 'system_diagnostics_service.g.dart';

@riverpod
class SystemDiagnosticsService extends _$SystemDiagnosticsService {
  @override
  void build() {}

  /// システムおよびアプリの診断情報レポート文字列を生成する
  Future<String> generateReport() async {
    final now = DateTime.now().toUtc().toIso8601String();
    final themeMode = ref.read(themeModeProvider);
    final appMode = ref.read(appModeProvider);
    final hapticsEnabled = ref.read(hapticsEnabledProvider);
    final currentLocale = ref.read(appLocaleProvider);
    final version = ref.read(appVersionProvider);
    final build = ref.read(buildNumberProvider);
    final folderManagement = ref.read(folderManagementEnabledProvider);
    final showHidden = ref.read(showHiddenFilesProvider);
    final privacySettings = ref
        .read(privacySettingsNotifierProvider)
        .value;

    // パーミッション状況を安全に取得
    var notificationPermissionStr = 'unknown';
    try {
      final status = await ref
          .read(permissionRepositoryProvider)
          .getNotificationPermissionStatus();
      notificationPermissionStr = status.name;
    } catch (e, st) {
      AppLogger.w(LogTag.app, '診断情報取得: 通知権限の取得に失敗', e, st);
      notificationPermissionStr = 'error';
    }

    final platformName = _resolvePlatformName();

    const buildMode = kDebugMode
        ? 'debug'
        : kProfileMode
        ? 'profile'
        : 'release';

    final localeStr = currentLocale == null
        ? 'system'
        : currentLocale.toLanguageTag();

    final lines = [
      '=== System Diagnostics ===',
      'Generated At: $now',
      'Platform: $platformName',
      'App Version: $version ($build)',
      'Build Mode: $buildMode',
      'Storage Mode: ${appMode.name}',
      'Theme Mode: ${themeMode.name}',
      'Locale: $localeStr',
      'Haptics: $hapticsEnabled',
      'Folder Management: $folderManagement',
      'Show Hidden Files: $showHidden',
      'App Lock: ${privacySettings?.isAppLockEnabled == true}',
      'Biometrics: ${privacySettings?.isBiometricEnabled == true}',
      'Notification Permission: $notificationPermissionStr',
    ];

    return lines.join('\n');
  }

  String _resolvePlatformName() {
    if (kIsWeb) {
      return 'Web (${defaultTargetPlatform.name})';
    }
    try {
      if (Platform.isAndroid) {
        return 'Android ${Platform.operatingSystemVersion}';
      } else if (Platform.isIOS) {
        return 'iOS ${Platform.operatingSystemVersion}';
      } else {
        return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
      }
    } catch (_) {
      return defaultTargetPlatform.name;
    }
  }
}
