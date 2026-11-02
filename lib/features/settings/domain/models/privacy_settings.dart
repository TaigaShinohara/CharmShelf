import 'package:freezed_annotation/freezed_annotation.dart';

part 'privacy_settings.freezed.dart';
part 'privacy_settings.g.dart';

enum AutoLockTimeout {
  immediately,
  oneMinute,
  fiveMinutes,
  tenMinutes,
  thirtyMinutes,
  never;

  int? get milliseconds {
    switch (this) {
      case AutoLockTimeout.immediately:
        return 0;
      case AutoLockTimeout.oneMinute:
        return 60 * 1000;
      case AutoLockTimeout.fiveMinutes:
        return 5 * 60 * 1000;
      case AutoLockTimeout.tenMinutes:
        return 10 * 60 * 1000;
      case AutoLockTimeout.thirtyMinutes:
        return 30 * 60 * 1000;
      case AutoLockTimeout.never:
        return null;
    }
  }
}

@freezed
abstract class PrivacySettings with _$PrivacySettings {
  const factory PrivacySettings({
    @Default(false) bool isAppLockEnabled,
    @Default(false) bool isBiometricEnabled,
    @Default(AutoLockTimeout.immediately) AutoLockTimeout autoLockTimeout,
    @Default(false) bool hideContentInMultitasking,
    @Default(true) bool enableScreenshotProtection, // Android only
    @Default(false) bool useSecretThumbnailMode,
  }) = _PrivacySettings;

  factory PrivacySettings.fromJson(Map<String, dynamic> json) =>
      _$PrivacySettingsFromJson(json);
}
