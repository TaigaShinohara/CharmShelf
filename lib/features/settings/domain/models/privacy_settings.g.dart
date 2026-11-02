// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'privacy_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PrivacySettings _$PrivacySettingsFromJson(Map<String, dynamic> json) =>
    _PrivacySettings(
      isAppLockEnabled: json['isAppLockEnabled'] as bool? ?? false,
      isBiometricEnabled: json['isBiometricEnabled'] as bool? ?? false,
      autoLockTimeout:
          $enumDecodeNullable(
            _$AutoLockTimeoutEnumMap,
            json['autoLockTimeout'],
          ) ??
          AutoLockTimeout.immediately,
      hideContentInMultitasking:
          json['hideContentInMultitasking'] as bool? ?? false,
      enableScreenshotProtection:
          json['enableScreenshotProtection'] as bool? ?? true,
      useSecretThumbnailMode: json['useSecretThumbnailMode'] as bool? ?? false,
    );

Map<String, dynamic> _$PrivacySettingsToJson(_PrivacySettings instance) =>
    <String, dynamic>{
      'isAppLockEnabled': instance.isAppLockEnabled,
      'isBiometricEnabled': instance.isBiometricEnabled,
      'autoLockTimeout': _$AutoLockTimeoutEnumMap[instance.autoLockTimeout]!,
      'hideContentInMultitasking': instance.hideContentInMultitasking,
      'enableScreenshotProtection': instance.enableScreenshotProtection,
      'useSecretThumbnailMode': instance.useSecretThumbnailMode,
    };

const _$AutoLockTimeoutEnumMap = {
  AutoLockTimeout.immediately: 'immediately',
  AutoLockTimeout.oneMinute: 'oneMinute',
  AutoLockTimeout.fiveMinutes: 'fiveMinutes',
  AutoLockTimeout.tenMinutes: 'tenMinutes',
  AutoLockTimeout.thirtyMinutes: 'thirtyMinutes',
  AutoLockTimeout.never: 'never',
};
