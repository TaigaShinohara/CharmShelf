// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_item.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMediaItemCollection on Isar {
  IsarCollection<MediaItem> get mediaItems => this.collection();
}

const MediaItemSchema = CollectionSchema(
  name: r'MediaItem',
  id: 3893864289923902342,
  properties: {
    r'addedAt': PropertySchema(
      id: 0,
      name: r'addedAt',
      type: IsarType.dateTime,
    ),
    r'isArchived': PropertySchema(
      id: 1,
      name: r'isArchived',
      type: IsarType.bool,
    ),
    r'isFavorite': PropertySchema(
      id: 2,
      name: r'isFavorite',
      type: IsarType.bool,
    ),
    r'isHidden': PropertySchema(id: 3, name: r'isHidden', type: IsarType.bool),
    r'isMissing': PropertySchema(
      id: 4,
      name: r'isMissing',
      type: IsarType.bool,
    ),
    r'isTrashRoot': PropertySchema(
      id: 5,
      name: r'isTrashRoot',
      type: IsarType.bool,
    ),
    r'isTrashed': PropertySchema(
      id: 6,
      name: r'isTrashed',
      type: IsarType.bool,
    ),
    r'missingCheckedAt': PropertySchema(
      id: 7,
      name: r'missingCheckedAt',
      type: IsarType.dateTime,
    ),
    r'originalPath': PropertySchema(
      id: 8,
      name: r'originalPath',
      type: IsarType.string,
    ),
    r'parentPath': PropertySchema(
      id: 9,
      name: r'parentPath',
      type: IsarType.string,
    ),
    r'path': PropertySchema(id: 10, name: r'path', type: IsarType.string),
    r'size': PropertySchema(id: 11, name: r'size', type: IsarType.long),
    r'sourceType': PropertySchema(
      id: 12,
      name: r'sourceType',
      type: IsarType.byte,
      enumMap: _MediaItemsourceTypeEnumValueMap,
    ),
    r'thumbnailPath': PropertySchema(
      id: 13,
      name: r'thumbnailPath',
      type: IsarType.string,
    ),
    r'trashPath': PropertySchema(
      id: 14,
      name: r'trashPath',
      type: IsarType.string,
    ),
    r'trashRootPath': PropertySchema(
      id: 15,
      name: r'trashRootPath',
      type: IsarType.string,
    ),
    r'trashedAt': PropertySchema(
      id: 16,
      name: r'trashedAt',
      type: IsarType.dateTime,
    ),
    r'type': PropertySchema(
      id: 17,
      name: r'type',
      type: IsarType.byte,
      enumMap: _MediaItemtypeEnumValueMap,
    ),
    r'uid': PropertySchema(id: 18, name: r'uid', type: IsarType.string),
    r'updatedAt': PropertySchema(
      id: 19,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
  },

  estimateSize: _mediaItemEstimateSize,
  serialize: _mediaItemSerialize,
  deserialize: _mediaItemDeserialize,
  deserializeProp: _mediaItemDeserializeProp,
  idName: r'id',
  indexes: {
    r'uid': IndexSchema(
      id: 8193695471701937315,
      name: r'uid',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'uid',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'path': IndexSchema(
      id: 8756705481922369689,
      name: r'path',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'path',
          type: IndexType.value,
          caseSensitive: true,
        ),
      ],
    ),
    r'addedAt': IndexSchema(
      id: -8595779697745674092,
      name: r'addedAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'addedAt',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'parentPath': IndexSchema(
      id: -420149345764640134,
      name: r'parentPath',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'parentPath',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'isMissing': IndexSchema(
      id: -7658664132704194746,
      name: r'isMissing',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isMissing',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'isArchived': IndexSchema(
      id: 655844772568347876,
      name: r'isArchived',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isArchived',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'isHidden': IndexSchema(
      id: 1012074769999104596,
      name: r'isHidden',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isHidden',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'isFavorite': IndexSchema(
      id: 5742774614603939776,
      name: r'isFavorite',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isFavorite',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'isTrashed': IndexSchema(
      id: 3056854837835265747,
      name: r'isTrashed',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isTrashed',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'isTrashRoot': IndexSchema(
      id: 2992163001158321673,
      name: r'isTrashRoot',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isTrashRoot',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'trashRootPath': IndexSchema(
      id: -7861729269397016776,
      name: r'trashRootPath',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'trashRootPath',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {
    r'collection': LinkSchema(
      id: -3604140086454794793,
      name: r'collection',
      target: r'MediaCollection',
      single: true,
      linkName: r'items',
    ),
  },
  embeddedSchemas: {},

  getId: _mediaItemGetId,
  getLinks: _mediaItemGetLinks,
  attach: _mediaItemAttach,
  version: '3.1.0+1',
);

int _mediaItemEstimateSize(
  MediaItem object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.originalPath.length * 3;
  {
    final value = object.parentPath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.path.length * 3;
  {
    final value = object.thumbnailPath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.trashPath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.trashRootPath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.uid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _mediaItemSerialize(
  MediaItem object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.addedAt);
  writer.writeBool(offsets[1], object.isArchived);
  writer.writeBool(offsets[2], object.isFavorite);
  writer.writeBool(offsets[3], object.isHidden);
  writer.writeBool(offsets[4], object.isMissing);
  writer.writeBool(offsets[5], object.isTrashRoot);
  writer.writeBool(offsets[6], object.isTrashed);
  writer.writeDateTime(offsets[7], object.missingCheckedAt);
  writer.writeString(offsets[8], object.originalPath);
  writer.writeString(offsets[9], object.parentPath);
  writer.writeString(offsets[10], object.path);
  writer.writeLong(offsets[11], object.size);
  writer.writeByte(offsets[12], object.sourceType.index);
  writer.writeString(offsets[13], object.thumbnailPath);
  writer.writeString(offsets[14], object.trashPath);
  writer.writeString(offsets[15], object.trashRootPath);
  writer.writeDateTime(offsets[16], object.trashedAt);
  writer.writeByte(offsets[17], object.type.index);
  writer.writeString(offsets[18], object.uid);
  writer.writeDateTime(offsets[19], object.updatedAt);
}

MediaItem _mediaItemDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = MediaItem();
  object.addedAt = reader.readDateTime(offsets[0]);
  object.id = id;
  object.isArchived = reader.readBool(offsets[1]);
  object.isFavorite = reader.readBool(offsets[2]);
  object.isHidden = reader.readBool(offsets[3]);
  object.isMissing = reader.readBool(offsets[4]);
  object.isTrashRoot = reader.readBool(offsets[5]);
  object.isTrashed = reader.readBool(offsets[6]);
  object.missingCheckedAt = reader.readDateTimeOrNull(offsets[7]);
  object.originalPath = reader.readString(offsets[8]);
  object.parentPath = reader.readStringOrNull(offsets[9]);
  object.path = reader.readString(offsets[10]);
  object.size = reader.readLongOrNull(offsets[11]);
  object.sourceType =
      _MediaItemsourceTypeValueEnumMap[reader.readByteOrNull(offsets[12])] ??
      MediaSourceType.localCopy;
  object.thumbnailPath = reader.readStringOrNull(offsets[13]);
  object.trashPath = reader.readStringOrNull(offsets[14]);
  object.trashRootPath = reader.readStringOrNull(offsets[15]);
  object.trashedAt = reader.readDateTimeOrNull(offsets[16]);
  object.type =
      _MediaItemtypeValueEnumMap[reader.readByteOrNull(offsets[17])] ??
      MediaType.file;
  object.uid = reader.readStringOrNull(offsets[18]);
  object.updatedAt = reader.readDateTime(offsets[19]);
  return object;
}

P _mediaItemDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readBool(offset)) as P;
    case 2:
      return (reader.readBool(offset)) as P;
    case 3:
      return (reader.readBool(offset)) as P;
    case 4:
      return (reader.readBool(offset)) as P;
    case 5:
      return (reader.readBool(offset)) as P;
    case 6:
      return (reader.readBool(offset)) as P;
    case 7:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (reader.readLongOrNull(offset)) as P;
    case 12:
      return (_MediaItemsourceTypeValueEnumMap[reader.readByteOrNull(offset)] ??
              MediaSourceType.localCopy)
          as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (reader.readStringOrNull(offset)) as P;
    case 16:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 17:
      return (_MediaItemtypeValueEnumMap[reader.readByteOrNull(offset)] ??
              MediaType.file)
          as P;
    case 18:
      return (reader.readStringOrNull(offset)) as P;
    case 19:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _MediaItemsourceTypeEnumValueMap = {
  'localCopy': 0,
  'externalReference': 1,
};
const _MediaItemsourceTypeValueEnumMap = {
  0: MediaSourceType.localCopy,
  1: MediaSourceType.externalReference,
};
const _MediaItemtypeEnumValueMap = {'file': 0, 'folder': 1};
const _MediaItemtypeValueEnumMap = {0: MediaType.file, 1: MediaType.folder};

Id _mediaItemGetId(MediaItem object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _mediaItemGetLinks(MediaItem object) {
  return [object.collection];
}

void _mediaItemAttach(IsarCollection<dynamic> col, Id id, MediaItem object) {
  object.id = id;
  object.collection.attach(
    col,
    col.isar.collection<MediaCollection>(),
    r'collection',
    id,
  );
}

extension MediaItemByIndex on IsarCollection<MediaItem> {
  Future<MediaItem?> getByUid(String? uid) {
    return getByIndex(r'uid', [uid]);
  }

  MediaItem? getByUidSync(String? uid) {
    return getByIndexSync(r'uid', [uid]);
  }

  Future<bool> deleteByUid(String? uid) {
    return deleteByIndex(r'uid', [uid]);
  }

  bool deleteByUidSync(String? uid) {
    return deleteByIndexSync(r'uid', [uid]);
  }

  Future<List<MediaItem?>> getAllByUid(List<String?> uidValues) {
    final values = uidValues.map((e) => [e]).toList();
    return getAllByIndex(r'uid', values);
  }

  List<MediaItem?> getAllByUidSync(List<String?> uidValues) {
    final values = uidValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'uid', values);
  }

  Future<int> deleteAllByUid(List<String?> uidValues) {
    final values = uidValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'uid', values);
  }

  int deleteAllByUidSync(List<String?> uidValues) {
    final values = uidValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'uid', values);
  }

  Future<Id> putByUid(MediaItem object) {
    return putByIndex(r'uid', object);
  }

  Id putByUidSync(MediaItem object, {bool saveLinks = true}) {
    return putByIndexSync(r'uid', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByUid(List<MediaItem> objects) {
    return putAllByIndex(r'uid', objects);
  }

  List<Id> putAllByUidSync(List<MediaItem> objects, {bool saveLinks = true}) {
    return putAllByIndexSync(r'uid', objects, saveLinks: saveLinks);
  }
}

extension MediaItemQueryWhereSort
    on QueryBuilder<MediaItem, MediaItem, QWhere> {
  QueryBuilder<MediaItem, MediaItem, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhere> anyPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'path'),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhere> anyAddedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'addedAt'),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhere> anyIsMissing() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isMissing'),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhere> anyIsArchived() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isArchived'),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhere> anyIsHidden() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isHidden'),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhere> anyIsFavorite() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isFavorite'),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhere> anyIsTrashed() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isTrashed'),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhere> anyIsTrashRoot() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isTrashRoot'),
      );
    });
  }
}

extension MediaItemQueryWhere
    on QueryBuilder<MediaItem, MediaItem, QWhereClause> {
  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> uidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'uid', value: [null]),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> uidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'uid',
          lower: [null],
          includeLower: false,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> uidEqualTo(
    String? uid,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'uid', value: [uid]),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> uidNotEqualTo(
    String? uid,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'uid',
                lower: [],
                upper: [uid],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'uid',
                lower: [uid],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'uid',
                lower: [uid],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'uid',
                lower: [],
                upper: [uid],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> pathEqualTo(
    String path,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'path', value: [path]),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> pathNotEqualTo(
    String path,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'path',
                lower: [],
                upper: [path],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'path',
                lower: [path],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'path',
                lower: [path],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'path',
                lower: [],
                upper: [path],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> pathGreaterThan(
    String path, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'path',
          lower: [path],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> pathLessThan(
    String path, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'path',
          lower: [],
          upper: [path],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> pathBetween(
    String lowerPath,
    String upperPath, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'path',
          lower: [lowerPath],
          includeLower: includeLower,
          upper: [upperPath],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> pathStartsWith(
    String PathPrefix,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'path',
          lower: [PathPrefix],
          upper: ['$PathPrefix\u{FFFFF}'],
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> pathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'path', value: ['']),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> pathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.lessThan(indexName: r'path', upper: ['']),
            )
            .addWhereClause(
              IndexWhereClause.greaterThan(indexName: r'path', lower: ['']),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.greaterThan(indexName: r'path', lower: ['']),
            )
            .addWhereClause(
              IndexWhereClause.lessThan(indexName: r'path', upper: ['']),
            );
      }
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> addedAtEqualTo(
    DateTime addedAt,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'addedAt', value: [addedAt]),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> addedAtNotEqualTo(
    DateTime addedAt,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'addedAt',
                lower: [],
                upper: [addedAt],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'addedAt',
                lower: [addedAt],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'addedAt',
                lower: [addedAt],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'addedAt',
                lower: [],
                upper: [addedAt],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> addedAtGreaterThan(
    DateTime addedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'addedAt',
          lower: [addedAt],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> addedAtLessThan(
    DateTime addedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'addedAt',
          lower: [],
          upper: [addedAt],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> addedAtBetween(
    DateTime lowerAddedAt,
    DateTime upperAddedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'addedAt',
          lower: [lowerAddedAt],
          includeLower: includeLower,
          upper: [upperAddedAt],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> parentPathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'parentPath', value: [null]),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> parentPathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'parentPath',
          lower: [null],
          includeLower: false,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> parentPathEqualTo(
    String? parentPath,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'parentPath', value: [parentPath]),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> parentPathNotEqualTo(
    String? parentPath,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'parentPath',
                lower: [],
                upper: [parentPath],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'parentPath',
                lower: [parentPath],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'parentPath',
                lower: [parentPath],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'parentPath',
                lower: [],
                upper: [parentPath],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> isMissingEqualTo(
    bool isMissing,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'isMissing', value: [isMissing]),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> isMissingNotEqualTo(
    bool isMissing,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isMissing',
                lower: [],
                upper: [isMissing],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isMissing',
                lower: [isMissing],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isMissing',
                lower: [isMissing],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isMissing',
                lower: [],
                upper: [isMissing],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> isArchivedEqualTo(
    bool isArchived,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'isArchived', value: [isArchived]),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> isArchivedNotEqualTo(
    bool isArchived,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isArchived',
                lower: [],
                upper: [isArchived],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isArchived',
                lower: [isArchived],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isArchived',
                lower: [isArchived],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isArchived',
                lower: [],
                upper: [isArchived],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> isHiddenEqualTo(
    bool isHidden,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'isHidden', value: [isHidden]),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> isHiddenNotEqualTo(
    bool isHidden,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isHidden',
                lower: [],
                upper: [isHidden],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isHidden',
                lower: [isHidden],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isHidden',
                lower: [isHidden],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isHidden',
                lower: [],
                upper: [isHidden],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> isFavoriteEqualTo(
    bool isFavorite,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'isFavorite', value: [isFavorite]),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> isFavoriteNotEqualTo(
    bool isFavorite,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isFavorite',
                lower: [],
                upper: [isFavorite],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isFavorite',
                lower: [isFavorite],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isFavorite',
                lower: [isFavorite],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isFavorite',
                lower: [],
                upper: [isFavorite],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> isTrashedEqualTo(
    bool isTrashed,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'isTrashed', value: [isTrashed]),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> isTrashedNotEqualTo(
    bool isTrashed,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isTrashed',
                lower: [],
                upper: [isTrashed],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isTrashed',
                lower: [isTrashed],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isTrashed',
                lower: [isTrashed],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isTrashed',
                lower: [],
                upper: [isTrashed],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> isTrashRootEqualTo(
    bool isTrashRoot,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'isTrashRoot',
          value: [isTrashRoot],
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> isTrashRootNotEqualTo(
    bool isTrashRoot,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isTrashRoot',
                lower: [],
                upper: [isTrashRoot],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isTrashRoot',
                lower: [isTrashRoot],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isTrashRoot',
                lower: [isTrashRoot],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isTrashRoot',
                lower: [],
                upper: [isTrashRoot],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> trashRootPathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'trashRootPath', value: [null]),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause>
  trashRootPathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'trashRootPath',
          lower: [null],
          includeLower: false,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> trashRootPathEqualTo(
    String? trashRootPath,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'trashRootPath',
          value: [trashRootPath],
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterWhereClause> trashRootPathNotEqualTo(
    String? trashRootPath,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'trashRootPath',
                lower: [],
                upper: [trashRootPath],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'trashRootPath',
                lower: [trashRootPath],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'trashRootPath',
                lower: [trashRootPath],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'trashRootPath',
                lower: [],
                upper: [trashRootPath],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension MediaItemQueryFilter
    on QueryBuilder<MediaItem, MediaItem, QFilterCondition> {
  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> addedAtEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'addedAt', value: value),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> addedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'addedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> addedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'addedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> addedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'addedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> isArchivedEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isArchived', value: value),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> isFavoriteEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isFavorite', value: value),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> isHiddenEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isHidden', value: value),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> isMissingEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isMissing', value: value),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> isTrashRootEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isTrashRoot', value: value),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> isTrashedEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isTrashed', value: value),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  missingCheckedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'missingCheckedAt'),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  missingCheckedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'missingCheckedAt'),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  missingCheckedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'missingCheckedAt', value: value),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  missingCheckedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'missingCheckedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  missingCheckedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'missingCheckedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  missingCheckedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'missingCheckedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> originalPathEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'originalPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  originalPathGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'originalPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  originalPathLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'originalPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> originalPathBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'originalPath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  originalPathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'originalPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  originalPathEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'originalPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  originalPathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'originalPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> originalPathMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'originalPath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  originalPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'originalPath', value: ''),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  originalPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'originalPath', value: ''),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> parentPathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'parentPath'),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  parentPathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'parentPath'),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> parentPathEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'parentPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  parentPathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'parentPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> parentPathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'parentPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> parentPathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'parentPath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  parentPathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'parentPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> parentPathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'parentPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> parentPathContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'parentPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> parentPathMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'parentPath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  parentPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'parentPath', value: ''),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  parentPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'parentPath', value: ''),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> pathEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'path',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> pathGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'path',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> pathLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'path',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> pathBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'path',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> pathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'path',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> pathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'path',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> pathContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'path',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> pathMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'path',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> pathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'path', value: ''),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> pathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'path', value: ''),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> sizeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'size'),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> sizeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'size'),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> sizeEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'size', value: value),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> sizeGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'size',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> sizeLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'size',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> sizeBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'size',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> sourceTypeEqualTo(
    MediaSourceType value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sourceType', value: value),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  sourceTypeGreaterThan(MediaSourceType value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sourceType',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> sourceTypeLessThan(
    MediaSourceType value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sourceType',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> sourceTypeBetween(
    MediaSourceType lower,
    MediaSourceType upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sourceType',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  thumbnailPathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'thumbnailPath'),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  thumbnailPathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'thumbnailPath'),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  thumbnailPathEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'thumbnailPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  thumbnailPathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'thumbnailPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  thumbnailPathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'thumbnailPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  thumbnailPathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'thumbnailPath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  thumbnailPathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'thumbnailPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  thumbnailPathEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'thumbnailPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  thumbnailPathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'thumbnailPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  thumbnailPathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'thumbnailPath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  thumbnailPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'thumbnailPath', value: ''),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  thumbnailPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'thumbnailPath', value: ''),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> trashPathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'trashPath'),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  trashPathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'trashPath'),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> trashPathEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'trashPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  trashPathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'trashPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> trashPathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'trashPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> trashPathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'trashPath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> trashPathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'trashPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> trashPathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'trashPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> trashPathContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'trashPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> trashPathMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'trashPath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> trashPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'trashPath', value: ''),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  trashPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'trashPath', value: ''),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  trashRootPathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'trashRootPath'),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  trashRootPathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'trashRootPath'),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  trashRootPathEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'trashRootPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  trashRootPathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'trashRootPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  trashRootPathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'trashRootPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  trashRootPathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'trashRootPath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  trashRootPathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'trashRootPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  trashRootPathEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'trashRootPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  trashRootPathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'trashRootPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  trashRootPathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'trashRootPath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  trashRootPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'trashRootPath', value: ''),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  trashRootPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'trashRootPath', value: ''),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> trashedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'trashedAt'),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  trashedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'trashedAt'),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> trashedAtEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'trashedAt', value: value),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  trashedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'trashedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> trashedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'trashedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> trashedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'trashedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> typeEqualTo(
    MediaType value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'type', value: value),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> typeGreaterThan(
    MediaType value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'type',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> typeLessThan(
    MediaType value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'type',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> typeBetween(
    MediaType lower,
    MediaType upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'type',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> uidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'uid'),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> uidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'uid'),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> uidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'uid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> uidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'uid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> uidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'uid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> uidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'uid',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> uidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'uid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> uidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'uid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> uidContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'uid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> uidMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'uid',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> uidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'uid', value: ''),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> uidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'uid', value: ''),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> updatedAtEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition>
  updatedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> updatedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'updatedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension MediaItemQueryObject
    on QueryBuilder<MediaItem, MediaItem, QFilterCondition> {}

extension MediaItemQueryLinks
    on QueryBuilder<MediaItem, MediaItem, QFilterCondition> {
  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> collection(
    FilterQuery<MediaCollection> q,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'collection');
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterFilterCondition> collectionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'collection', 0, true, 0, true);
    });
  }
}

extension MediaItemQuerySortBy on QueryBuilder<MediaItem, MediaItem, QSortBy> {
  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByAddedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedAt', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByAddedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedAt', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByIsArchived() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isArchived', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByIsArchivedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isArchived', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByIsFavorite() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFavorite', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByIsFavoriteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFavorite', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByIsHidden() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isHidden', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByIsHiddenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isHidden', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByIsMissing() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isMissing', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByIsMissingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isMissing', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByIsTrashRoot() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isTrashRoot', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByIsTrashRootDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isTrashRoot', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByIsTrashed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isTrashed', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByIsTrashedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isTrashed', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByMissingCheckedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'missingCheckedAt', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy>
  sortByMissingCheckedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'missingCheckedAt', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByOriginalPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originalPath', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByOriginalPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originalPath', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByParentPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentPath', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByParentPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentPath', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'path', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'path', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortBySize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'size', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortBySizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'size', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortBySourceType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceType', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortBySourceTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceType', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByThumbnailPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'thumbnailPath', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByThumbnailPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'thumbnailPath', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByTrashPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trashPath', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByTrashPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trashPath', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByTrashRootPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trashRootPath', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByTrashRootPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trashRootPath', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByTrashedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trashedAt', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByTrashedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trashedAt', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uid', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uid', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension MediaItemQuerySortThenBy
    on QueryBuilder<MediaItem, MediaItem, QSortThenBy> {
  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByAddedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedAt', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByAddedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedAt', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByIsArchived() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isArchived', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByIsArchivedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isArchived', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByIsFavorite() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFavorite', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByIsFavoriteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFavorite', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByIsHidden() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isHidden', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByIsHiddenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isHidden', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByIsMissing() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isMissing', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByIsMissingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isMissing', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByIsTrashRoot() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isTrashRoot', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByIsTrashRootDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isTrashRoot', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByIsTrashed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isTrashed', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByIsTrashedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isTrashed', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByMissingCheckedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'missingCheckedAt', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy>
  thenByMissingCheckedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'missingCheckedAt', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByOriginalPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originalPath', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByOriginalPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originalPath', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByParentPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentPath', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByParentPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentPath', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'path', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'path', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenBySize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'size', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenBySizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'size', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenBySourceType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceType', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenBySourceTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceType', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByThumbnailPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'thumbnailPath', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByThumbnailPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'thumbnailPath', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByTrashPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trashPath', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByTrashPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trashPath', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByTrashRootPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trashRootPath', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByTrashRootPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trashRootPath', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByTrashedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trashedAt', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByTrashedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trashedAt', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uid', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uid', Sort.desc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension MediaItemQueryWhereDistinct
    on QueryBuilder<MediaItem, MediaItem, QDistinct> {
  QueryBuilder<MediaItem, MediaItem, QDistinct> distinctByAddedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'addedAt');
    });
  }

  QueryBuilder<MediaItem, MediaItem, QDistinct> distinctByIsArchived() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isArchived');
    });
  }

  QueryBuilder<MediaItem, MediaItem, QDistinct> distinctByIsFavorite() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isFavorite');
    });
  }

  QueryBuilder<MediaItem, MediaItem, QDistinct> distinctByIsHidden() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isHidden');
    });
  }

  QueryBuilder<MediaItem, MediaItem, QDistinct> distinctByIsMissing() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isMissing');
    });
  }

  QueryBuilder<MediaItem, MediaItem, QDistinct> distinctByIsTrashRoot() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isTrashRoot');
    });
  }

  QueryBuilder<MediaItem, MediaItem, QDistinct> distinctByIsTrashed() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isTrashed');
    });
  }

  QueryBuilder<MediaItem, MediaItem, QDistinct> distinctByMissingCheckedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'missingCheckedAt');
    });
  }

  QueryBuilder<MediaItem, MediaItem, QDistinct> distinctByOriginalPath({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'originalPath', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QDistinct> distinctByParentPath({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'parentPath', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QDistinct> distinctByPath({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'path', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QDistinct> distinctBySize() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'size');
    });
  }

  QueryBuilder<MediaItem, MediaItem, QDistinct> distinctBySourceType() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceType');
    });
  }

  QueryBuilder<MediaItem, MediaItem, QDistinct> distinctByThumbnailPath({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'thumbnailPath',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QDistinct> distinctByTrashPath({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'trashPath', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QDistinct> distinctByTrashRootPath({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'trashRootPath',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<MediaItem, MediaItem, QDistinct> distinctByTrashedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'trashedAt');
    });
  }

  QueryBuilder<MediaItem, MediaItem, QDistinct> distinctByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'type');
    });
  }

  QueryBuilder<MediaItem, MediaItem, QDistinct> distinctByUid({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'uid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MediaItem, MediaItem, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension MediaItemQueryProperty
    on QueryBuilder<MediaItem, MediaItem, QQueryProperty> {
  QueryBuilder<MediaItem, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<MediaItem, DateTime, QQueryOperations> addedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'addedAt');
    });
  }

  QueryBuilder<MediaItem, bool, QQueryOperations> isArchivedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isArchived');
    });
  }

  QueryBuilder<MediaItem, bool, QQueryOperations> isFavoriteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isFavorite');
    });
  }

  QueryBuilder<MediaItem, bool, QQueryOperations> isHiddenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isHidden');
    });
  }

  QueryBuilder<MediaItem, bool, QQueryOperations> isMissingProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isMissing');
    });
  }

  QueryBuilder<MediaItem, bool, QQueryOperations> isTrashRootProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isTrashRoot');
    });
  }

  QueryBuilder<MediaItem, bool, QQueryOperations> isTrashedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isTrashed');
    });
  }

  QueryBuilder<MediaItem, DateTime?, QQueryOperations>
  missingCheckedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'missingCheckedAt');
    });
  }

  QueryBuilder<MediaItem, String, QQueryOperations> originalPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'originalPath');
    });
  }

  QueryBuilder<MediaItem, String?, QQueryOperations> parentPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'parentPath');
    });
  }

  QueryBuilder<MediaItem, String, QQueryOperations> pathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'path');
    });
  }

  QueryBuilder<MediaItem, int?, QQueryOperations> sizeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'size');
    });
  }

  QueryBuilder<MediaItem, MediaSourceType, QQueryOperations>
  sourceTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceType');
    });
  }

  QueryBuilder<MediaItem, String?, QQueryOperations> thumbnailPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'thumbnailPath');
    });
  }

  QueryBuilder<MediaItem, String?, QQueryOperations> trashPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'trashPath');
    });
  }

  QueryBuilder<MediaItem, String?, QQueryOperations> trashRootPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'trashRootPath');
    });
  }

  QueryBuilder<MediaItem, DateTime?, QQueryOperations> trashedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'trashedAt');
    });
  }

  QueryBuilder<MediaItem, MediaType, QQueryOperations> typeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'type');
    });
  }

  QueryBuilder<MediaItem, String?, QQueryOperations> uidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'uid');
    });
  }

  QueryBuilder<MediaItem, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
