// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'media_filter.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MediaFilter {

 String? get parentPath; List<int>? get tagIds; List<int>? get excludedTagIds; List<int>? get tiers; String? get searchQuery; SearchTarget? get searchTarget; bool? get hasTags; bool? get isFavorite; bool? get isArchived; bool? get isHidden; List<MediaType>? get mediaTypes; int? get limit; MediaSourceType? get sourceType; String? get path; bool? get rootOnly; SortOrder get sortOrder; bool get onlyCatalogs;/// 検索中も今開いているフォルダに限る。未指定時は棚全体を探す。
 bool get searchWithinParent;
/// Create a copy of MediaFilter
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MediaFilterCopyWith<MediaFilter> get copyWith => _$MediaFilterCopyWithImpl<MediaFilter>(this as MediaFilter, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as MediaFilter;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MediaFilter&&(identical(other.parentPath, _this.parentPath) || other.parentPath == _this.parentPath)&&const DeepCollectionEquality().equals(other.tagIds, _this.tagIds)&&const DeepCollectionEquality().equals(other.excludedTagIds, _this.excludedTagIds)&&const DeepCollectionEquality().equals(other.tiers, _this.tiers)&&(identical(other.searchQuery, _this.searchQuery) || other.searchQuery == _this.searchQuery)&&(identical(other.searchTarget, _this.searchTarget) || other.searchTarget == _this.searchTarget)&&(identical(other.hasTags, _this.hasTags) || other.hasTags == _this.hasTags)&&(identical(other.isFavorite, _this.isFavorite) || other.isFavorite == _this.isFavorite)&&(identical(other.isArchived, _this.isArchived) || other.isArchived == _this.isArchived)&&(identical(other.isHidden, _this.isHidden) || other.isHidden == _this.isHidden)&&const DeepCollectionEquality().equals(other.mediaTypes, _this.mediaTypes)&&(identical(other.limit, _this.limit) || other.limit == _this.limit)&&(identical(other.sourceType, _this.sourceType) || other.sourceType == _this.sourceType)&&(identical(other.path, _this.path) || other.path == _this.path)&&(identical(other.rootOnly, _this.rootOnly) || other.rootOnly == _this.rootOnly)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder)&&(identical(other.onlyCatalogs, _this.onlyCatalogs) || other.onlyCatalogs == _this.onlyCatalogs)&&(identical(other.searchWithinParent, _this.searchWithinParent) || other.searchWithinParent == _this.searchWithinParent));
}


@override
int get hashCode {
  final _this = this as MediaFilter;
  return Object.hash(runtimeType,_this.parentPath,const DeepCollectionEquality().hash(_this.tagIds),const DeepCollectionEquality().hash(_this.excludedTagIds),const DeepCollectionEquality().hash(_this.tiers),_this.searchQuery,_this.searchTarget,_this.hasTags,_this.isFavorite,_this.isArchived,_this.isHidden,const DeepCollectionEquality().hash(_this.mediaTypes),_this.limit,_this.sourceType,_this.path,_this.rootOnly,_this.sortOrder,_this.onlyCatalogs,_this.searchWithinParent);
}

@override
String toString() {
  final _this = this as MediaFilter;
  return 'MediaFilter(parentPath: ${_this.parentPath}, tagIds: ${_this.tagIds}, excludedTagIds: ${_this.excludedTagIds}, tiers: ${_this.tiers}, searchQuery: ${_this.searchQuery}, searchTarget: ${_this.searchTarget}, hasTags: ${_this.hasTags}, isFavorite: ${_this.isFavorite}, isArchived: ${_this.isArchived}, isHidden: ${_this.isHidden}, mediaTypes: ${_this.mediaTypes}, limit: ${_this.limit}, sourceType: ${_this.sourceType}, path: ${_this.path}, rootOnly: ${_this.rootOnly}, sortOrder: ${_this.sortOrder}, onlyCatalogs: ${_this.onlyCatalogs}, searchWithinParent: ${_this.searchWithinParent})';
}


}

/// @nodoc
abstract mixin class $MediaFilterCopyWith<$Res>  {
  factory $MediaFilterCopyWith(MediaFilter value, $Res Function(MediaFilter) _then) = _$MediaFilterCopyWithImpl;
@useResult
$Res call({
 String? parentPath, List<int>? tagIds, List<int>? excludedTagIds, List<int>? tiers, String? searchQuery, SearchTarget? searchTarget, bool? hasTags, bool? isFavorite, bool? isArchived, bool? isHidden, List<MediaType>? mediaTypes, int? limit, MediaSourceType? sourceType, String? path, bool? rootOnly, SortOrder sortOrder, bool onlyCatalogs, bool searchWithinParent
});




}
/// @nodoc
class _$MediaFilterCopyWithImpl<$Res>
    implements $MediaFilterCopyWith<$Res> {
  _$MediaFilterCopyWithImpl(this._self, this._then);

  final MediaFilter _self;
  final $Res Function(MediaFilter) _then;

/// Create a copy of MediaFilter
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? parentPath = freezed,Object? tagIds = freezed,Object? excludedTagIds = freezed,Object? tiers = freezed,Object? searchQuery = freezed,Object? searchTarget = freezed,Object? hasTags = freezed,Object? isFavorite = freezed,Object? isArchived = freezed,Object? isHidden = freezed,Object? mediaTypes = freezed,Object? limit = freezed,Object? sourceType = freezed,Object? path = freezed,Object? rootOnly = freezed,Object? sortOrder = null,Object? onlyCatalogs = null,Object? searchWithinParent = null,}) {
  return _then(MediaFilter(
parentPath: freezed == parentPath ? _self.parentPath : parentPath // ignore: cast_nullable_to_non_nullable
as String?,tagIds: freezed == tagIds ? _self.tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as List<int>?,excludedTagIds: freezed == excludedTagIds ? _self.excludedTagIds : excludedTagIds // ignore: cast_nullable_to_non_nullable
as List<int>?,tiers: freezed == tiers ? _self.tiers : tiers // ignore: cast_nullable_to_non_nullable
as List<int>?,searchQuery: freezed == searchQuery ? _self.searchQuery : searchQuery // ignore: cast_nullable_to_non_nullable
as String?,searchTarget: freezed == searchTarget ? _self.searchTarget : searchTarget // ignore: cast_nullable_to_non_nullable
as SearchTarget?,hasTags: freezed == hasTags ? _self.hasTags : hasTags // ignore: cast_nullable_to_non_nullable
as bool?,isFavorite: freezed == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool?,isArchived: freezed == isArchived ? _self.isArchived : isArchived // ignore: cast_nullable_to_non_nullable
as bool?,isHidden: freezed == isHidden ? _self.isHidden : isHidden // ignore: cast_nullable_to_non_nullable
as bool?,mediaTypes: freezed == mediaTypes ? _self.mediaTypes : mediaTypes // ignore: cast_nullable_to_non_nullable
as List<MediaType>?,limit: freezed == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int?,sourceType: freezed == sourceType ? _self.sourceType : sourceType // ignore: cast_nullable_to_non_nullable
as MediaSourceType?,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,rootOnly: freezed == rootOnly ? _self.rootOnly : rootOnly // ignore: cast_nullable_to_non_nullable
as bool?,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as SortOrder,onlyCatalogs: null == onlyCatalogs ? _self.onlyCatalogs : onlyCatalogs // ignore: cast_nullable_to_non_nullable
as bool,searchWithinParent: null == searchWithinParent ? _self.searchWithinParent : searchWithinParent // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [MediaFilter].
extension MediaFilterPatterns on MediaFilter {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MediaFilter value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MediaFilter() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MediaFilter value)  $default,){
final _that = this;
switch (_that) {
case _MediaFilter():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MediaFilter value)?  $default,){
final _that = this;
switch (_that) {
case _MediaFilter() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? parentPath,  List<int>? tagIds,  List<int>? excludedTagIds,  List<int>? tiers,  String? searchQuery,  SearchTarget? searchTarget,  bool? hasTags,  bool? isFavorite,  bool? isArchived,  bool? isHidden,  List<MediaType>? mediaTypes,  int? limit,  MediaSourceType? sourceType,  String? path,  bool? rootOnly,  SortOrder sortOrder,  bool onlyCatalogs,  bool searchWithinParent)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MediaFilter() when $default != null:
return $default(_that.parentPath,_that.tagIds,_that.excludedTagIds,_that.tiers,_that.searchQuery,_that.searchTarget,_that.hasTags,_that.isFavorite,_that.isArchived,_that.isHidden,_that.mediaTypes,_that.limit,_that.sourceType,_that.path,_that.rootOnly,_that.sortOrder,_that.onlyCatalogs,_that.searchWithinParent);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? parentPath,  List<int>? tagIds,  List<int>? excludedTagIds,  List<int>? tiers,  String? searchQuery,  SearchTarget? searchTarget,  bool? hasTags,  bool? isFavorite,  bool? isArchived,  bool? isHidden,  List<MediaType>? mediaTypes,  int? limit,  MediaSourceType? sourceType,  String? path,  bool? rootOnly,  SortOrder sortOrder,  bool onlyCatalogs,  bool searchWithinParent)  $default,) {final _that = this;
switch (_that) {
case _MediaFilter():
return $default(_that.parentPath,_that.tagIds,_that.excludedTagIds,_that.tiers,_that.searchQuery,_that.searchTarget,_that.hasTags,_that.isFavorite,_that.isArchived,_that.isHidden,_that.mediaTypes,_that.limit,_that.sourceType,_that.path,_that.rootOnly,_that.sortOrder,_that.onlyCatalogs,_that.searchWithinParent);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? parentPath,  List<int>? tagIds,  List<int>? excludedTagIds,  List<int>? tiers,  String? searchQuery,  SearchTarget? searchTarget,  bool? hasTags,  bool? isFavorite,  bool? isArchived,  bool? isHidden,  List<MediaType>? mediaTypes,  int? limit,  MediaSourceType? sourceType,  String? path,  bool? rootOnly,  SortOrder sortOrder,  bool onlyCatalogs,  bool searchWithinParent)?  $default,) {final _that = this;
switch (_that) {
case _MediaFilter() when $default != null:
return $default(_that.parentPath,_that.tagIds,_that.excludedTagIds,_that.tiers,_that.searchQuery,_that.searchTarget,_that.hasTags,_that.isFavorite,_that.isArchived,_that.isHidden,_that.mediaTypes,_that.limit,_that.sourceType,_that.path,_that.rootOnly,_that.sortOrder,_that.onlyCatalogs,_that.searchWithinParent);case _:
  return null;

}
}

}

/// @nodoc


class _MediaFilter extends MediaFilter {
  const _MediaFilter({this.parentPath,  List<int>? tagIds,  List<int>? excludedTagIds,  List<int>? tiers, this.searchQuery, this.searchTarget, this.hasTags, this.isFavorite, this.isArchived = false, this.isHidden = false,  List<MediaType>? mediaTypes, this.limit, this.sourceType, this.path, this.rootOnly, this.sortOrder = SortOrder.addedDesc, this.onlyCatalogs = false, this.searchWithinParent = false}): _tagIds = tagIds,_excludedTagIds = excludedTagIds,_tiers = tiers,_mediaTypes = mediaTypes,super._();
  

@override final  String? parentPath;
 final  List<int>? _tagIds;
@override List<int>? get tagIds {
  final value = _tagIds;
  if (value == null) return null;
  if (_tagIds is EqualUnmodifiableListView) return _tagIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<int>? _excludedTagIds;
@override List<int>? get excludedTagIds {
  final value = _excludedTagIds;
  if (value == null) return null;
  if (_excludedTagIds is EqualUnmodifiableListView) return _excludedTagIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<int>? _tiers;
@override List<int>? get tiers {
  final value = _tiers;
  if (value == null) return null;
  if (_tiers is EqualUnmodifiableListView) return _tiers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  String? searchQuery;
@override final  SearchTarget? searchTarget;
@override final  bool? hasTags;
@override final  bool? isFavorite;
@override@JsonKey() final  bool? isArchived;
@override@JsonKey() final  bool? isHidden;
 final  List<MediaType>? _mediaTypes;
@override List<MediaType>? get mediaTypes {
  final value = _mediaTypes;
  if (value == null) return null;
  if (_mediaTypes is EqualUnmodifiableListView) return _mediaTypes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  int? limit;
@override final  MediaSourceType? sourceType;
@override final  String? path;
@override final  bool? rootOnly;
@override@JsonKey() final  SortOrder sortOrder;
@override@JsonKey() final  bool onlyCatalogs;
/// 検索中も今開いているフォルダに限る。未指定時は棚全体を探す。
@override@JsonKey() final  bool searchWithinParent;

/// Create a copy of MediaFilter
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MediaFilterCopyWith<_MediaFilter> get copyWith => __$MediaFilterCopyWithImpl<_MediaFilter>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MediaFilter&&(identical(other.parentPath, parentPath) || other.parentPath == parentPath)&&const DeepCollectionEquality().equals(other.tagIds, _tagIds)&&const DeepCollectionEquality().equals(other.excludedTagIds, _excludedTagIds)&&const DeepCollectionEquality().equals(other.tiers, _tiers)&&(identical(other.searchQuery, searchQuery) || other.searchQuery == searchQuery)&&(identical(other.searchTarget, searchTarget) || other.searchTarget == searchTarget)&&(identical(other.hasTags, hasTags) || other.hasTags == hasTags)&&(identical(other.isFavorite, isFavorite) || other.isFavorite == isFavorite)&&(identical(other.isArchived, isArchived) || other.isArchived == isArchived)&&(identical(other.isHidden, isHidden) || other.isHidden == isHidden)&&const DeepCollectionEquality().equals(other.mediaTypes, _mediaTypes)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.sourceType, sourceType) || other.sourceType == sourceType)&&(identical(other.path, path) || other.path == path)&&(identical(other.rootOnly, rootOnly) || other.rootOnly == rootOnly)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.onlyCatalogs, onlyCatalogs) || other.onlyCatalogs == onlyCatalogs)&&(identical(other.searchWithinParent, searchWithinParent) || other.searchWithinParent == searchWithinParent));
}


@override
int get hashCode {
    return Object.hash(runtimeType,parentPath,const DeepCollectionEquality().hash(_tagIds),const DeepCollectionEquality().hash(_excludedTagIds),const DeepCollectionEquality().hash(_tiers),searchQuery,searchTarget,hasTags,isFavorite,isArchived,isHidden,const DeepCollectionEquality().hash(_mediaTypes),limit,sourceType,path,rootOnly,sortOrder,onlyCatalogs,searchWithinParent);
}

@override
String toString() {
    return 'MediaFilter(parentPath: $parentPath, tagIds: $tagIds, excludedTagIds: $excludedTagIds, tiers: $tiers, searchQuery: $searchQuery, searchTarget: $searchTarget, hasTags: $hasTags, isFavorite: $isFavorite, isArchived: $isArchived, isHidden: $isHidden, mediaTypes: $mediaTypes, limit: $limit, sourceType: $sourceType, path: $path, rootOnly: $rootOnly, sortOrder: $sortOrder, onlyCatalogs: $onlyCatalogs, searchWithinParent: $searchWithinParent)';
}


}

/// @nodoc
abstract mixin class _$MediaFilterCopyWith<$Res> implements $MediaFilterCopyWith<$Res> {
  factory _$MediaFilterCopyWith(_MediaFilter value, $Res Function(_MediaFilter) _then) = __$MediaFilterCopyWithImpl;
@override @useResult
$Res call({
 String? parentPath, List<int>? tagIds, List<int>? excludedTagIds, List<int>? tiers, String? searchQuery, SearchTarget? searchTarget, bool? hasTags, bool? isFavorite, bool? isArchived, bool? isHidden, List<MediaType>? mediaTypes, int? limit, MediaSourceType? sourceType, String? path, bool? rootOnly, SortOrder sortOrder, bool onlyCatalogs, bool searchWithinParent
});




}
/// @nodoc
class __$MediaFilterCopyWithImpl<$Res>
    implements _$MediaFilterCopyWith<$Res> {
  __$MediaFilterCopyWithImpl(this._self, this._then);

  final _MediaFilter _self;
  final $Res Function(_MediaFilter) _then;

/// Create a copy of MediaFilter
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? parentPath = freezed,Object? tagIds = freezed,Object? excludedTagIds = freezed,Object? tiers = freezed,Object? searchQuery = freezed,Object? searchTarget = freezed,Object? hasTags = freezed,Object? isFavorite = freezed,Object? isArchived = freezed,Object? isHidden = freezed,Object? mediaTypes = freezed,Object? limit = freezed,Object? sourceType = freezed,Object? path = freezed,Object? rootOnly = freezed,Object? sortOrder = null,Object? onlyCatalogs = null,Object? searchWithinParent = null,}) {
  return _then(_MediaFilter(
parentPath: freezed == parentPath ? _self.parentPath : parentPath // ignore: cast_nullable_to_non_nullable
as String?,tagIds: freezed == tagIds ? _self._tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as List<int>?,excludedTagIds: freezed == excludedTagIds ? _self._excludedTagIds : excludedTagIds // ignore: cast_nullable_to_non_nullable
as List<int>?,tiers: freezed == tiers ? _self._tiers : tiers // ignore: cast_nullable_to_non_nullable
as List<int>?,searchQuery: freezed == searchQuery ? _self.searchQuery : searchQuery // ignore: cast_nullable_to_non_nullable
as String?,searchTarget: freezed == searchTarget ? _self.searchTarget : searchTarget // ignore: cast_nullable_to_non_nullable
as SearchTarget?,hasTags: freezed == hasTags ? _self.hasTags : hasTags // ignore: cast_nullable_to_non_nullable
as bool?,isFavorite: freezed == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool?,isArchived: freezed == isArchived ? _self.isArchived : isArchived // ignore: cast_nullable_to_non_nullable
as bool?,isHidden: freezed == isHidden ? _self.isHidden : isHidden // ignore: cast_nullable_to_non_nullable
as bool?,mediaTypes: freezed == mediaTypes ? _self._mediaTypes : mediaTypes // ignore: cast_nullable_to_non_nullable
as List<MediaType>?,limit: freezed == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int?,sourceType: freezed == sourceType ? _self.sourceType : sourceType // ignore: cast_nullable_to_non_nullable
as MediaSourceType?,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,rootOnly: freezed == rootOnly ? _self.rootOnly : rootOnly // ignore: cast_nullable_to_non_nullable
as bool?,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as SortOrder,onlyCatalogs: null == onlyCatalogs ? _self.onlyCatalogs : onlyCatalogs // ignore: cast_nullable_to_non_nullable
as bool,searchWithinParent: null == searchWithinParent ? _self.searchWithinParent : searchWithinParent // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
