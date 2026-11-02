// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'privacy_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PrivacySettings {

 bool get isAppLockEnabled; bool get isBiometricEnabled; AutoLockTimeout get autoLockTimeout; bool get hideContentInMultitasking; bool get enableScreenshotProtection; bool get useSecretThumbnailMode;
/// Create a copy of PrivacySettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PrivacySettingsCopyWith<PrivacySettings> get copyWith => _$PrivacySettingsCopyWithImpl<PrivacySettings>(this as PrivacySettings, _$identity);

  /// Serializes this PrivacySettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PrivacySettings;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PrivacySettings&&(identical(other.isAppLockEnabled, _this.isAppLockEnabled) || other.isAppLockEnabled == _this.isAppLockEnabled)&&(identical(other.isBiometricEnabled, _this.isBiometricEnabled) || other.isBiometricEnabled == _this.isBiometricEnabled)&&(identical(other.autoLockTimeout, _this.autoLockTimeout) || other.autoLockTimeout == _this.autoLockTimeout)&&(identical(other.hideContentInMultitasking, _this.hideContentInMultitasking) || other.hideContentInMultitasking == _this.hideContentInMultitasking)&&(identical(other.enableScreenshotProtection, _this.enableScreenshotProtection) || other.enableScreenshotProtection == _this.enableScreenshotProtection)&&(identical(other.useSecretThumbnailMode, _this.useSecretThumbnailMode) || other.useSecretThumbnailMode == _this.useSecretThumbnailMode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PrivacySettings;
  return Object.hash(runtimeType,_this.isAppLockEnabled,_this.isBiometricEnabled,_this.autoLockTimeout,_this.hideContentInMultitasking,_this.enableScreenshotProtection,_this.useSecretThumbnailMode);
}

@override
String toString() {
  final _this = this as PrivacySettings;
  return 'PrivacySettings(isAppLockEnabled: ${_this.isAppLockEnabled}, isBiometricEnabled: ${_this.isBiometricEnabled}, autoLockTimeout: ${_this.autoLockTimeout}, hideContentInMultitasking: ${_this.hideContentInMultitasking}, enableScreenshotProtection: ${_this.enableScreenshotProtection}, useSecretThumbnailMode: ${_this.useSecretThumbnailMode})';
}


}

/// @nodoc
abstract mixin class $PrivacySettingsCopyWith<$Res>  {
  factory $PrivacySettingsCopyWith(PrivacySettings value, $Res Function(PrivacySettings) _then) = _$PrivacySettingsCopyWithImpl;
@useResult
$Res call({
 bool isAppLockEnabled, bool isBiometricEnabled, AutoLockTimeout autoLockTimeout, bool hideContentInMultitasking, bool enableScreenshotProtection, bool useSecretThumbnailMode
});




}
/// @nodoc
class _$PrivacySettingsCopyWithImpl<$Res>
    implements $PrivacySettingsCopyWith<$Res> {
  _$PrivacySettingsCopyWithImpl(this._self, this._then);

  final PrivacySettings _self;
  final $Res Function(PrivacySettings) _then;

/// Create a copy of PrivacySettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isAppLockEnabled = null,Object? isBiometricEnabled = null,Object? autoLockTimeout = null,Object? hideContentInMultitasking = null,Object? enableScreenshotProtection = null,Object? useSecretThumbnailMode = null,}) {
  return _then(PrivacySettings(
isAppLockEnabled: null == isAppLockEnabled ? _self.isAppLockEnabled : isAppLockEnabled // ignore: cast_nullable_to_non_nullable
as bool,isBiometricEnabled: null == isBiometricEnabled ? _self.isBiometricEnabled : isBiometricEnabled // ignore: cast_nullable_to_non_nullable
as bool,autoLockTimeout: null == autoLockTimeout ? _self.autoLockTimeout : autoLockTimeout // ignore: cast_nullable_to_non_nullable
as AutoLockTimeout,hideContentInMultitasking: null == hideContentInMultitasking ? _self.hideContentInMultitasking : hideContentInMultitasking // ignore: cast_nullable_to_non_nullable
as bool,enableScreenshotProtection: null == enableScreenshotProtection ? _self.enableScreenshotProtection : enableScreenshotProtection // ignore: cast_nullable_to_non_nullable
as bool,useSecretThumbnailMode: null == useSecretThumbnailMode ? _self.useSecretThumbnailMode : useSecretThumbnailMode // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [PrivacySettings].
extension PrivacySettingsPatterns on PrivacySettings {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PrivacySettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PrivacySettings() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PrivacySettings value)  $default,){
final _that = this;
switch (_that) {
case _PrivacySettings():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PrivacySettings value)?  $default,){
final _that = this;
switch (_that) {
case _PrivacySettings() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isAppLockEnabled,  bool isBiometricEnabled,  AutoLockTimeout autoLockTimeout,  bool hideContentInMultitasking,  bool enableScreenshotProtection,  bool useSecretThumbnailMode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PrivacySettings() when $default != null:
return $default(_that.isAppLockEnabled,_that.isBiometricEnabled,_that.autoLockTimeout,_that.hideContentInMultitasking,_that.enableScreenshotProtection,_that.useSecretThumbnailMode);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isAppLockEnabled,  bool isBiometricEnabled,  AutoLockTimeout autoLockTimeout,  bool hideContentInMultitasking,  bool enableScreenshotProtection,  bool useSecretThumbnailMode)  $default,) {final _that = this;
switch (_that) {
case _PrivacySettings():
return $default(_that.isAppLockEnabled,_that.isBiometricEnabled,_that.autoLockTimeout,_that.hideContentInMultitasking,_that.enableScreenshotProtection,_that.useSecretThumbnailMode);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isAppLockEnabled,  bool isBiometricEnabled,  AutoLockTimeout autoLockTimeout,  bool hideContentInMultitasking,  bool enableScreenshotProtection,  bool useSecretThumbnailMode)?  $default,) {final _that = this;
switch (_that) {
case _PrivacySettings() when $default != null:
return $default(_that.isAppLockEnabled,_that.isBiometricEnabled,_that.autoLockTimeout,_that.hideContentInMultitasking,_that.enableScreenshotProtection,_that.useSecretThumbnailMode);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PrivacySettings implements PrivacySettings {
  const _PrivacySettings({this.isAppLockEnabled = false, this.isBiometricEnabled = false, this.autoLockTimeout = AutoLockTimeout.immediately, this.hideContentInMultitasking = false, this.enableScreenshotProtection = true, this.useSecretThumbnailMode = false});
  factory _PrivacySettings.fromJson(Map<String, dynamic> json) => _$PrivacySettingsFromJson(json);

@override@JsonKey() final  bool isAppLockEnabled;
@override@JsonKey() final  bool isBiometricEnabled;
@override@JsonKey() final  AutoLockTimeout autoLockTimeout;
@override@JsonKey() final  bool hideContentInMultitasking;
@override@JsonKey() final  bool enableScreenshotProtection;
@override@JsonKey() final  bool useSecretThumbnailMode;

/// Create a copy of PrivacySettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PrivacySettingsCopyWith<_PrivacySettings> get copyWith => __$PrivacySettingsCopyWithImpl<_PrivacySettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PrivacySettingsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PrivacySettings&&(identical(other.isAppLockEnabled, isAppLockEnabled) || other.isAppLockEnabled == isAppLockEnabled)&&(identical(other.isBiometricEnabled, isBiometricEnabled) || other.isBiometricEnabled == isBiometricEnabled)&&(identical(other.autoLockTimeout, autoLockTimeout) || other.autoLockTimeout == autoLockTimeout)&&(identical(other.hideContentInMultitasking, hideContentInMultitasking) || other.hideContentInMultitasking == hideContentInMultitasking)&&(identical(other.enableScreenshotProtection, enableScreenshotProtection) || other.enableScreenshotProtection == enableScreenshotProtection)&&(identical(other.useSecretThumbnailMode, useSecretThumbnailMode) || other.useSecretThumbnailMode == useSecretThumbnailMode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,isAppLockEnabled,isBiometricEnabled,autoLockTimeout,hideContentInMultitasking,enableScreenshotProtection,useSecretThumbnailMode);
}

@override
String toString() {
    return 'PrivacySettings(isAppLockEnabled: $isAppLockEnabled, isBiometricEnabled: $isBiometricEnabled, autoLockTimeout: $autoLockTimeout, hideContentInMultitasking: $hideContentInMultitasking, enableScreenshotProtection: $enableScreenshotProtection, useSecretThumbnailMode: $useSecretThumbnailMode)';
}


}

/// @nodoc
abstract mixin class _$PrivacySettingsCopyWith<$Res> implements $PrivacySettingsCopyWith<$Res> {
  factory _$PrivacySettingsCopyWith(_PrivacySettings value, $Res Function(_PrivacySettings) _then) = __$PrivacySettingsCopyWithImpl;
@override @useResult
$Res call({
 bool isAppLockEnabled, bool isBiometricEnabled, AutoLockTimeout autoLockTimeout, bool hideContentInMultitasking, bool enableScreenshotProtection, bool useSecretThumbnailMode
});




}
/// @nodoc
class __$PrivacySettingsCopyWithImpl<$Res>
    implements _$PrivacySettingsCopyWith<$Res> {
  __$PrivacySettingsCopyWithImpl(this._self, this._then);

  final _PrivacySettings _self;
  final $Res Function(_PrivacySettings) _then;

/// Create a copy of PrivacySettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isAppLockEnabled = null,Object? isBiometricEnabled = null,Object? autoLockTimeout = null,Object? hideContentInMultitasking = null,Object? enableScreenshotProtection = null,Object? useSecretThumbnailMode = null,}) {
  return _then(_PrivacySettings(
isAppLockEnabled: null == isAppLockEnabled ? _self.isAppLockEnabled : isAppLockEnabled // ignore: cast_nullable_to_non_nullable
as bool,isBiometricEnabled: null == isBiometricEnabled ? _self.isBiometricEnabled : isBiometricEnabled // ignore: cast_nullable_to_non_nullable
as bool,autoLockTimeout: null == autoLockTimeout ? _self.autoLockTimeout : autoLockTimeout // ignore: cast_nullable_to_non_nullable
as AutoLockTimeout,hideContentInMultitasking: null == hideContentInMultitasking ? _self.hideContentInMultitasking : hideContentInMultitasking // ignore: cast_nullable_to_non_nullable
as bool,enableScreenshotProtection: null == enableScreenshotProtection ? _self.enableScreenshotProtection : enableScreenshotProtection // ignore: cast_nullable_to_non_nullable
as bool,useSecretThumbnailMode: null == useSecretThumbnailMode ? _self.useSecretThumbnailMode : useSecretThumbnailMode // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
