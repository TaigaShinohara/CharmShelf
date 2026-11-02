import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/core/providers/package_info_provider.dart';
import 'package:private_shelf/core/providers/shared_preferences_provider.dart';
import 'package:private_shelf/core/theme/theme_provider.dart';
import 'package:private_shelf/features/permission/data/repositories/permission_repository_impl.dart';
import 'package:private_shelf/features/permission/domain/repositories/permission_repository.dart';
import 'package:private_shelf/features/settings/data/repositories/privacy_repository.dart';
import 'package:private_shelf/features/settings/presentation/services/system_diagnostics_service.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/feature_customization_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/locale_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/show_hidden_files_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';

class _FakePermissionRepository implements PermissionRepository {
  _FakePermissionRepository({
    this.status = PermissionResult.granted,
    this.shouldThrow = false,
  });

  final PermissionResult status;
  final bool shouldThrow;

  @override
  Future<PermissionResult> getNotificationPermissionStatus() async {
    if (shouldThrow) {
      throw Exception('Permission query failed');
    }
    return status;
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<PermissionResult> requestNotificationPermission() async => status;

  @override
  Future<PermissionResult> requestStoragePermission() async => status;

  @override
  Future<PermissionResult> getManageStoragePermissionStatus() async => status;

  @override
  Future<PermissionResult> requestManageStoragePermission() async => status;
}

void main() {
  group('SystemDiagnosticsService', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('全項目が整形された固定フォーマットで生成される', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) async => prefs),
          privacyRepositoryProvider.overrideWithValue(PrivacyRepository(prefs)),
          appVersionProvider.overrideWithValue('1.2.3'),
          buildNumberProvider.overrideWithValue('45'),
          themeModeProvider.overrideWith((ref) => ThemeMode.dark),
          appModeProvider.overrideWith((ref) => AppMode.internal),
          hapticsEnabledProvider.overrideWith((ref) => true),
          appLocaleProvider.overrideWith((ref) => const Locale('ja')),
          folderManagementEnabledProvider.overrideWith((ref) => true),
          showHiddenFilesProvider.overrideWith((ref) => false),
          permissionRepositoryProvider.overrideWithValue(
            _FakePermissionRepository(status: PermissionResult.granted),
          ),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(systemDiagnosticsServiceProvider.notifier);
      final report = await service.generateReport();

      expect(report, contains('=== System Diagnostics ==='));
      expect(report, contains('Generated At: '));
      expect(report, contains('Platform: '));
      expect(report, contains('App Version: 1.2.3 (45)'));
      expect(report, contains('Storage Mode: internal'));
      expect(report, contains('Theme Mode: dark'));
      expect(report, contains('Locale: ja'));
      expect(report, contains('Haptics: true'));
      expect(report, contains('Folder Management: true'));
      expect(report, contains('Show Hidden Files: false'));
      expect(report, contains('Notification Permission: granted'));
    });

    test('Localeが未設定（システム言語）の場合は system と出力される', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) async => prefs),
          privacyRepositoryProvider.overrideWithValue(PrivacyRepository(prefs)),
          appVersionProvider.overrideWithValue('1.0.0'),
          buildNumberProvider.overrideWithValue('1'),
          appLocaleProvider.overrideWith((ref) => null),
          permissionRepositoryProvider.overrideWithValue(
            _FakePermissionRepository(status: PermissionResult.denied),
          ),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(systemDiagnosticsServiceProvider.notifier);
      final report = await service.generateReport();

      expect(report, contains('Locale: system'));
      expect(report, contains('Notification Permission: denied'));
    });

    test('パーミッション取得時に例外が発生してもクラッシュせず error と出力される', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) async => prefs),
          privacyRepositoryProvider.overrideWithValue(PrivacyRepository(prefs)),
          appVersionProvider.overrideWithValue('1.0.0'),
          buildNumberProvider.overrideWithValue('1'),
          permissionRepositoryProvider.overrideWithValue(
            _FakePermissionRepository(shouldThrow: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(systemDiagnosticsServiceProvider.notifier);
      final report = await service.generateReport();

      expect(report, contains('Notification Permission: error'));
    });
  });
}
