// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sync_progress.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SyncProgress {

 SyncStatus get status; int get totalItems; int get processedItems; bool get isCancelled; String? get currentFileName; String? get errorMessage;
/// Create a copy of SyncProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncProgressCopyWith<SyncProgress> get copyWith => _$SyncProgressCopyWithImpl<SyncProgress>(this as SyncProgress, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SyncProgress;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncProgress&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.totalItems, _this.totalItems) || other.totalItems == _this.totalItems)&&(identical(other.processedItems, _this.processedItems) || other.processedItems == _this.processedItems)&&(identical(other.isCancelled, _this.isCancelled) || other.isCancelled == _this.isCancelled)&&(identical(other.currentFileName, _this.currentFileName) || other.currentFileName == _this.currentFileName)&&(identical(other.errorMessage, _this.errorMessage) || other.errorMessage == _this.errorMessage));
}


@override
int get hashCode {
  final _this = this as SyncProgress;
  return Object.hash(runtimeType,_this.status,_this.totalItems,_this.processedItems,_this.isCancelled,_this.currentFileName,_this.errorMessage);
}

@override
String toString() {
  final _this = this as SyncProgress;
  return 'SyncProgress(status: ${_this.status}, totalItems: ${_this.totalItems}, processedItems: ${_this.processedItems}, isCancelled: ${_this.isCancelled}, currentFileName: ${_this.currentFileName}, errorMessage: ${_this.errorMessage})';
}


}

/// @nodoc
abstract mixin class $SyncProgressCopyWith<$Res>  {
  factory $SyncProgressCopyWith(SyncProgress value, $Res Function(SyncProgress) _then) = _$SyncProgressCopyWithImpl;
@useResult
$Res call({
 SyncStatus status, int totalItems, int processedItems, bool isCancelled, String? currentFileName, String? errorMessage
});




}
/// @nodoc
class _$SyncProgressCopyWithImpl<$Res>
    implements $SyncProgressCopyWith<$Res> {
  _$SyncProgressCopyWithImpl(this._self, this._then);

  final SyncProgress _self;
  final $Res Function(SyncProgress) _then;

/// Create a copy of SyncProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? totalItems = null,Object? processedItems = null,Object? isCancelled = null,Object? currentFileName = freezed,Object? errorMessage = freezed,}) {
  return _then(SyncProgress(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SyncStatus,totalItems: null == totalItems ? _self.totalItems : totalItems // ignore: cast_nullable_to_non_nullable
as int,processedItems: null == processedItems ? _self.processedItems : processedItems // ignore: cast_nullable_to_non_nullable
as int,isCancelled: null == isCancelled ? _self.isCancelled : isCancelled // ignore: cast_nullable_to_non_nullable
as bool,currentFileName: freezed == currentFileName ? _self.currentFileName : currentFileName // ignore: cast_nullable_to_non_nullable
as String?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SyncProgress].
extension SyncProgressPatterns on SyncProgress {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SyncProgress value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SyncProgress() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SyncProgress value)  $default,){
final _that = this;
switch (_that) {
case _SyncProgress():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SyncProgress value)?  $default,){
final _that = this;
switch (_that) {
case _SyncProgress() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SyncStatus status,  int totalItems,  int processedItems,  bool isCancelled,  String? currentFileName,  String? errorMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SyncProgress() when $default != null:
return $default(_that.status,_that.totalItems,_that.processedItems,_that.isCancelled,_that.currentFileName,_that.errorMessage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SyncStatus status,  int totalItems,  int processedItems,  bool isCancelled,  String? currentFileName,  String? errorMessage)  $default,) {final _that = this;
switch (_that) {
case _SyncProgress():
return $default(_that.status,_that.totalItems,_that.processedItems,_that.isCancelled,_that.currentFileName,_that.errorMessage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SyncStatus status,  int totalItems,  int processedItems,  bool isCancelled,  String? currentFileName,  String? errorMessage)?  $default,) {final _that = this;
switch (_that) {
case _SyncProgress() when $default != null:
return $default(_that.status,_that.totalItems,_that.processedItems,_that.isCancelled,_that.currentFileName,_that.errorMessage);case _:
  return null;

}
}

}

/// @nodoc


class _SyncProgress extends SyncProgress {
  const _SyncProgress({this.status = SyncStatus.idle, this.totalItems = 0, this.processedItems = 0, this.isCancelled = false, this.currentFileName, this.errorMessage}): super._();
  

@override@JsonKey() final  SyncStatus status;
@override@JsonKey() final  int totalItems;
@override@JsonKey() final  int processedItems;
@override@JsonKey() final  bool isCancelled;
@override final  String? currentFileName;
@override final  String? errorMessage;

/// Create a copy of SyncProgress
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SyncProgressCopyWith<_SyncProgress> get copyWith => __$SyncProgressCopyWithImpl<_SyncProgress>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SyncProgress&&(identical(other.status, status) || other.status == status)&&(identical(other.totalItems, totalItems) || other.totalItems == totalItems)&&(identical(other.processedItems, processedItems) || other.processedItems == processedItems)&&(identical(other.isCancelled, isCancelled) || other.isCancelled == isCancelled)&&(identical(other.currentFileName, currentFileName) || other.currentFileName == currentFileName)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode {
    return Object.hash(runtimeType,status,totalItems,processedItems,isCancelled,currentFileName,errorMessage);
}

@override
String toString() {
    return 'SyncProgress(status: $status, totalItems: $totalItems, processedItems: $processedItems, isCancelled: $isCancelled, currentFileName: $currentFileName, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class _$SyncProgressCopyWith<$Res> implements $SyncProgressCopyWith<$Res> {
  factory _$SyncProgressCopyWith(_SyncProgress value, $Res Function(_SyncProgress) _then) = __$SyncProgressCopyWithImpl;
@override @useResult
$Res call({
 SyncStatus status, int totalItems, int processedItems, bool isCancelled, String? currentFileName, String? errorMessage
});




}
/// @nodoc
class __$SyncProgressCopyWithImpl<$Res>
    implements _$SyncProgressCopyWith<$Res> {
  __$SyncProgressCopyWithImpl(this._self, this._then);

  final _SyncProgress _self;
  final $Res Function(_SyncProgress) _then;

/// Create a copy of SyncProgress
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? totalItems = null,Object? processedItems = null,Object? isCancelled = null,Object? currentFileName = freezed,Object? errorMessage = freezed,}) {
  return _then(_SyncProgress(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SyncStatus,totalItems: null == totalItems ? _self.totalItems : totalItems // ignore: cast_nullable_to_non_nullable
as int,processedItems: null == processedItems ? _self.processedItems : processedItems // ignore: cast_nullable_to_non_nullable
as int,isCancelled: null == isCancelled ? _self.isCancelled : isCancelled // ignore: cast_nullable_to_non_nullable
as bool,currentFileName: freezed == currentFileName ? _self.currentFileName : currentFileName // ignore: cast_nullable_to_non_nullable
as String?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
