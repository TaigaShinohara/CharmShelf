// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collection.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMediaCollectionCollection on Isar {
  IsarCollection<MediaCollection> get mediaCollections => this.collection();
}

const MediaCollectionSchema = CollectionSchema(
  name: r'MediaCollection',
  id: 1870953031712495552,
  properties: {
    r'alias': PropertySchema(id: 0, name: r'alias', type: IsarType.string),
    r'coverImagePath': PropertySchema(
      id: 1,
      name: r'coverImagePath',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 2,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'defaultSortOrder': PropertySchema(
      id: 3,
      name: r'defaultSortOrder',
      type: IsarType.byte,
      enumMap: _MediaCollectiondefaultSortOrderEnumValueMap,
    ),
    r'defaultViewMode': PropertySchema(
      id: 4,
      name: r'defaultViewMode',
      type: IsarType.byte,
      enumMap: _MediaCollectiondefaultViewModeEnumValueMap,
    ),
    r'isArchived': PropertySchema(
      id: 5,
      name: r'isArchived',
      type: IsarType.bool,
    ),
    r'isCatalog': PropertySchema(
      id: 6,
      name: r'isCatalog',
      type: IsarType.bool,
    ),
    r'isFavorite': PropertySchema(
      id: 7,
      name: r'isFavorite',
      type: IsarType.bool,
    ),
    r'isHeaderExpanded': PropertySchema(
      id: 8,
      name: r'isHeaderExpanded',
      type: IsarType.bool,
    ),
    r'isHidden': PropertySchema(id: 9, name: r'isHidden', type: IsarType.bool),
    r'isPinned': PropertySchema(id: 10, name: r'isPinned', type: IsarType.bool),
    r'isTrashed': PropertySchema(
      id: 11,
      name: r'isTrashed',
      type: IsarType.bool,
    ),
    r'lastViewedAt': PropertySchema(
      id: 12,
      name: r'lastViewedAt',
      type: IsarType.dateTime,
    ),
    r'lastViewedItemId': PropertySchema(
      id: 13,
      name: r'lastViewedItemId',
      type: IsarType.long,
    ),
    r'notes': PropertySchema(id: 14, name: r'notes', type: IsarType.string),
    r'path': PropertySchema(id: 15, name: r'path', type: IsarType.string),
    r'splitSpreadView': PropertySchema(
      id: 16,
      name: r'splitSpreadView',
      type: IsarType.bool,
    ),
    r'tier': PropertySchema(id: 17, name: r'tier', type: IsarType.long),
    r'title': PropertySchema(id: 18, name: r'title', type: IsarType.string),
    r'trashRootPath': PropertySchema(
      id: 19,
      name: r'trashRootPath',
      type: IsarType.string,
    ),
    r'type': PropertySchema(
      id: 20,
      name: r'type',
      type: IsarType.byte,
      enumMap: _MediaCollectiontypeEnumValueMap,
    ),
    r'uid': PropertySchema(id: 21, name: r'uid', type: IsarType.string),
    r'updatedAt': PropertySchema(
      id: 22,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
  },

  estimateSize: _mediaCollectionEstimateSize,
  serialize: _mediaCollectionSerialize,
  deserialize: _mediaCollectionDeserialize,
  deserializeProp: _mediaCollectionDeserializeProp,
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
    r'title': IndexSchema(
      id: -7636685945352118059,
      name: r'title',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'title',
          type: IndexType.value,
          caseSensitive: true,
        ),
      ],
    ),
    r'path': IndexSchema(
      id: 8756705481922369689,
      name: r'path',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'path',
          type: IndexType.hash,
          caseSensitive: true,
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
    r'lastViewedAt': IndexSchema(
      id: -4764843800160647912,
      name: r'lastViewedAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'lastViewedAt',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'isPinned': IndexSchema(
      id: 7607338673446676027,
      name: r'isPinned',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isPinned',
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
    r'items': LinkSchema(
      id: -6097037800937656231,
      name: r'items',
      target: r'MediaItem',
      single: false,
    ),
    r'tags': LinkSchema(
      id: 2438904160648796384,
      name: r'tags',
      target: r'Tag',
      single: false,
    ),
  },
  embeddedSchemas: {},

  getId: _mediaCollectionGetId,
  getLinks: _mediaCollectionGetLinks,
  attach: _mediaCollectionAttach,
  version: '3.1.0+1',
);

int _mediaCollectionEstimateSize(
  MediaCollection object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.alias;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.coverImagePath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.notes;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.path.length * 3;
  bytesCount += 3 + object.title.length * 3;
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

void _mediaCollectionSerialize(
  MediaCollection object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.alias);
  writer.writeString(offsets[1], object.coverImagePath);
  writer.writeDateTime(offsets[2], object.createdAt);
  writer.writeByte(offsets[3], object.defaultSortOrder.index);
  writer.writeByte(offsets[4], object.defaultViewMode.index);
  writer.writeBool(offsets[5], object.isArchived);
  writer.writeBool(offsets[6], object.isCatalog);
  writer.writeBool(offsets[7], object.isFavorite);
  writer.writeBool(offsets[8], object.isHeaderExpanded);
  writer.writeBool(offsets[9], object.isHidden);
  writer.writeBool(offsets[10], object.isPinned);
  writer.writeBool(offsets[11], object.isTrashed);
  writer.writeDateTime(offsets[12], object.lastViewedAt);
  writer.writeLong(offsets[13], object.lastViewedItemId);
  writer.writeString(offsets[14], object.notes);
  writer.writeString(offsets[15], object.path);
  writer.writeBool(offsets[16], object.splitSpreadView);
  writer.writeLong(offsets[17], object.tier);
  writer.writeString(offsets[18], object.title);
  writer.writeString(offsets[19], object.trashRootPath);
  writer.writeByte(offsets[20], object.type.index);
  writer.writeString(offsets[21], object.uid);
  writer.writeDateTime(offsets[22], object.updatedAt);
}

MediaCollection _mediaCollectionDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = MediaCollection();
  object.alias = reader.readStringOrNull(offsets[0]);
  object.coverImagePath = reader.readStringOrNull(offsets[1]);
  object.createdAt = reader.readDateTime(offsets[2]);
  object.defaultSortOrder =
      _MediaCollectiondefaultSortOrderValueEnumMap[reader.readByteOrNull(
        offsets[3],
      )] ??
      SortOrder.dateDesc;
  object.defaultViewMode =
      _MediaCollectiondefaultViewModeValueEnumMap[reader.readByteOrNull(
        offsets[4],
      )] ??
      ViewMode.grid;
  object.id = id;
  object.isArchived = reader.readBool(offsets[5]);
  object.isCatalog = reader.readBool(offsets[6]);
  object.isFavorite = reader.readBool(offsets[7]);
  object.isHeaderExpanded = reader.readBool(offsets[8]);
  object.isHidden = reader.readBool(offsets[9]);
  object.isPinned = reader.readBool(offsets[10]);
  object.isTrashed = reader.readBool(offsets[11]);
  object.lastViewedAt = reader.readDateTimeOrNull(offsets[12]);
  object.lastViewedItemId = reader.readLongOrNull(offsets[13]);
  object.notes = reader.readStringOrNull(offsets[14]);
  object.path = reader.readString(offsets[15]);
  object.splitSpreadView = reader.readBool(offsets[16]);
  object.tier = reader.readLong(offsets[17]);
  object.title = reader.readString(offsets[18]);
  object.trashRootPath = reader.readStringOrNull(offsets[19]);
  object.type =
      _MediaCollectiontypeValueEnumMap[reader.readByteOrNull(offsets[20])] ??
      CollectionType.folder;
  object.uid = reader.readStringOrNull(offsets[21]);
  object.updatedAt = reader.readDateTime(offsets[22]);
  return object;
}

P _mediaCollectionDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readDateTime(offset)) as P;
    case 3:
      return (_MediaCollectiondefaultSortOrderValueEnumMap[reader
                  .readByteOrNull(offset)] ??
              SortOrder.dateDesc)
          as P;
    case 4:
      return (_MediaCollectiondefaultViewModeValueEnumMap[reader.readByteOrNull(
                offset,
              )] ??
              ViewMode.grid)
          as P;
    case 5:
      return (reader.readBool(offset)) as P;
    case 6:
      return (reader.readBool(offset)) as P;
    case 7:
      return (reader.readBool(offset)) as P;
    case 8:
      return (reader.readBool(offset)) as P;
    case 9:
      return (reader.readBool(offset)) as P;
    case 10:
      return (reader.readBool(offset)) as P;
    case 11:
      return (reader.readBool(offset)) as P;
    case 12:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 13:
      return (reader.readLongOrNull(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (reader.readString(offset)) as P;
    case 16:
      return (reader.readBool(offset)) as P;
    case 17:
      return (reader.readLong(offset)) as P;
    case 18:
      return (reader.readString(offset)) as P;
    case 19:
      return (reader.readStringOrNull(offset)) as P;
    case 20:
      return (_MediaCollectiontypeValueEnumMap[reader.readByteOrNull(offset)] ??
              CollectionType.folder)
          as P;
    case 21:
      return (reader.readStringOrNull(offset)) as P;
    case 22:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _MediaCollectiondefaultSortOrderEnumValueMap = {
  'dateDesc': 0,
  'dateAsc': 1,
  'nameAsc': 2,
  'nameDesc': 3,
  'sizeDesc': 4,
  'sizeAsc': 5,
  'tierDesc': 6,
  'tierAsc': 7,
  'favoriteDesc': 8,
  'lastViewedDesc': 9,
  'addedDesc': 10,
  'updatedDesc': 11,
  'addedAsc': 12,
  'updatedAsc': 13,
};
const _MediaCollectiondefaultSortOrderValueEnumMap = {
  0: SortOrder.dateDesc,
  1: SortOrder.dateAsc,
  2: SortOrder.nameAsc,
  3: SortOrder.nameDesc,
  4: SortOrder.sizeDesc,
  5: SortOrder.sizeAsc,
  6: SortOrder.tierDesc,
  7: SortOrder.tierAsc,
  8: SortOrder.favoriteDesc,
  9: SortOrder.lastViewedDesc,
  10: SortOrder.addedDesc,
  11: SortOrder.updatedDesc,
  12: SortOrder.addedAsc,
  13: SortOrder.updatedAsc,
};
const _MediaCollectiondefaultViewModeEnumValueMap = {'grid': 0, 'list': 1};
const _MediaCollectiondefaultViewModeValueEnumMap = {
  0: ViewMode.grid,
  1: ViewMode.list,
};
const _MediaCollectiontypeEnumValueMap = {
  'folder': 0,
  'file': 1,
  'externalFolder': 2,
};
const _MediaCollectiontypeValueEnumMap = {
  0: CollectionType.folder,
  1: CollectionType.file,
  2: CollectionType.externalFolder,
};

Id _mediaCollectionGetId(MediaCollection object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _mediaCollectionGetLinks(MediaCollection object) {
  return [object.items, object.tags];
}

void _mediaCollectionAttach(
  IsarCollection<dynamic> col,
  Id id,
  MediaCollection object,
) {
  object.id = id;
  object.items.attach(col, col.isar.collection<MediaItem>(), r'items', id);
  object.tags.attach(col, col.isar.collection<Tag>(), r'tags', id);
}

extension MediaCollectionByIndex on IsarCollection<MediaCollection> {
  Future<MediaCollection?> getByUid(String? uid) {
    return getByIndex(r'uid', [uid]);
  }

  MediaCollection? getByUidSync(String? uid) {
    return getByIndexSync(r'uid', [uid]);
  }

  Future<bool> deleteByUid(String? uid) {
    return deleteByIndex(r'uid', [uid]);
  }

  bool deleteByUidSync(String? uid) {
    return deleteByIndexSync(r'uid', [uid]);
  }

  Future<List<MediaCollection?>> getAllByUid(List<String?> uidValues) {
    final values = uidValues.map((e) => [e]).toList();
    return getAllByIndex(r'uid', values);
  }

  List<MediaCollection?> getAllByUidSync(List<String?> uidValues) {
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

  Future<Id> putByUid(MediaCollection object) {
    return putByIndex(r'uid', object);
  }

  Id putByUidSync(MediaCollection object, {bool saveLinks = true}) {
    return putByIndexSync(r'uid', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByUid(List<MediaCollection> objects) {
    return putAllByIndex(r'uid', objects);
  }

  List<Id> putAllByUidSync(
    List<MediaCollection> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'uid', objects, saveLinks: saveLinks);
  }

  Future<MediaCollection?> getByPath(String path) {
    return getByIndex(r'path', [path]);
  }

  MediaCollection? getByPathSync(String path) {
    return getByIndexSync(r'path', [path]);
  }

  Future<bool> deleteByPath(String path) {
    return deleteByIndex(r'path', [path]);
  }

  bool deleteByPathSync(String path) {
    return deleteByIndexSync(r'path', [path]);
  }

  Future<List<MediaCollection?>> getAllByPath(List<String> pathValues) {
    final values = pathValues.map((e) => [e]).toList();
    return getAllByIndex(r'path', values);
  }

  List<MediaCollection?> getAllByPathSync(List<String> pathValues) {
    final values = pathValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'path', values);
  }

  Future<int> deleteAllByPath(List<String> pathValues) {
    final values = pathValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'path', values);
  }

  int deleteAllByPathSync(List<String> pathValues) {
    final values = pathValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'path', values);
  }

  Future<Id> putByPath(MediaCollection object) {
    return putByIndex(r'path', object);
  }

  Id putByPathSync(MediaCollection object, {bool saveLinks = true}) {
    return putByIndexSync(r'path', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByPath(List<MediaCollection> objects) {
    return putAllByIndex(r'path', objects);
  }

  List<Id> putAllByPathSync(
    List<MediaCollection> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'path', objects, saveLinks: saveLinks);
  }
}

extension MediaCollectionQueryWhereSort
    on QueryBuilder<MediaCollection, MediaCollection, QWhere> {
  QueryBuilder<MediaCollection, MediaCollection, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhere> anyTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'title'),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhere> anyIsFavorite() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isFavorite'),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhere>
  anyLastViewedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'lastViewedAt'),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhere> anyIsPinned() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isPinned'),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhere> anyIsArchived() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isArchived'),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhere> anyIsHidden() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isHidden'),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhere> anyIsTrashed() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isTrashed'),
      );
    });
  }
}

extension MediaCollectionQueryWhere
    on QueryBuilder<MediaCollection, MediaCollection, QWhereClause> {
  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  idNotEqualTo(Id id) {
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause> idBetween(
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  uidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'uid', value: [null]),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  uidIsNotNull() {
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause> uidEqualTo(
    String? uid,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'uid', value: [uid]),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  uidNotEqualTo(String? uid) {
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  titleEqualTo(String title) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'title', value: [title]),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  titleNotEqualTo(String title) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'title',
                lower: [],
                upper: [title],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'title',
                lower: [title],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'title',
                lower: [title],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'title',
                lower: [],
                upper: [title],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  titleGreaterThan(String title, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'title',
          lower: [title],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  titleLessThan(String title, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'title',
          lower: [],
          upper: [title],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  titleBetween(
    String lowerTitle,
    String upperTitle, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'title',
          lower: [lowerTitle],
          includeLower: includeLower,
          upper: [upperTitle],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  titleStartsWith(String TitlePrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'title',
          lower: [TitlePrefix],
          upper: ['$TitlePrefix\u{FFFFF}'],
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'title', value: ['']),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.lessThan(indexName: r'title', upper: ['']),
            )
            .addWhereClause(
              IndexWhereClause.greaterThan(indexName: r'title', lower: ['']),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.greaterThan(indexName: r'title', lower: ['']),
            )
            .addWhereClause(
              IndexWhereClause.lessThan(indexName: r'title', upper: ['']),
            );
      }
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause> pathEqualTo(
    String path,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'path', value: [path]),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  pathNotEqualTo(String path) {
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  isFavoriteEqualTo(bool isFavorite) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'isFavorite', value: [isFavorite]),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  isFavoriteNotEqualTo(bool isFavorite) {
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  lastViewedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'lastViewedAt', value: [null]),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  lastViewedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'lastViewedAt',
          lower: [null],
          includeLower: false,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  lastViewedAtEqualTo(DateTime? lastViewedAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'lastViewedAt',
          value: [lastViewedAt],
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  lastViewedAtNotEqualTo(DateTime? lastViewedAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'lastViewedAt',
                lower: [],
                upper: [lastViewedAt],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'lastViewedAt',
                lower: [lastViewedAt],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'lastViewedAt',
                lower: [lastViewedAt],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'lastViewedAt',
                lower: [],
                upper: [lastViewedAt],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  lastViewedAtGreaterThan(DateTime? lastViewedAt, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'lastViewedAt',
          lower: [lastViewedAt],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  lastViewedAtLessThan(DateTime? lastViewedAt, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'lastViewedAt',
          lower: [],
          upper: [lastViewedAt],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  lastViewedAtBetween(
    DateTime? lowerLastViewedAt,
    DateTime? upperLastViewedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'lastViewedAt',
          lower: [lowerLastViewedAt],
          includeLower: includeLower,
          upper: [upperLastViewedAt],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  isPinnedEqualTo(bool isPinned) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'isPinned', value: [isPinned]),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  isPinnedNotEqualTo(bool isPinned) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isPinned',
                lower: [],
                upper: [isPinned],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isPinned',
                lower: [isPinned],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isPinned',
                lower: [isPinned],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isPinned',
                lower: [],
                upper: [isPinned],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  isArchivedEqualTo(bool isArchived) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'isArchived', value: [isArchived]),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  isArchivedNotEqualTo(bool isArchived) {
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  isHiddenEqualTo(bool isHidden) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'isHidden', value: [isHidden]),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  isHiddenNotEqualTo(bool isHidden) {
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  isTrashedEqualTo(bool isTrashed) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'isTrashed', value: [isTrashed]),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  isTrashedNotEqualTo(bool isTrashed) {
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  trashRootPathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'trashRootPath', value: [null]),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  trashRootPathEqualTo(String? trashRootPath) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'trashRootPath',
          value: [trashRootPath],
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterWhereClause>
  trashRootPathNotEqualTo(String? trashRootPath) {
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

extension MediaCollectionQueryFilter
    on QueryBuilder<MediaCollection, MediaCollection, QFilterCondition> {
  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  aliasIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'alias'),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  aliasIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'alias'),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  aliasEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'alias',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  aliasGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'alias',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  aliasLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'alias',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  aliasBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'alias',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  aliasStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'alias',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  aliasEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'alias',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  aliasContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'alias',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  aliasMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'alias',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  aliasIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'alias', value: ''),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  aliasIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'alias', value: ''),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  coverImagePathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'coverImagePath'),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  coverImagePathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'coverImagePath'),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  coverImagePathEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'coverImagePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  coverImagePathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'coverImagePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  coverImagePathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'coverImagePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  coverImagePathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'coverImagePath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  coverImagePathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'coverImagePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  coverImagePathEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'coverImagePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  coverImagePathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'coverImagePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  coverImagePathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'coverImagePath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  coverImagePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'coverImagePath', value: ''),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  coverImagePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'coverImagePath', value: ''),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  createdAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  createdAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  defaultSortOrderEqualTo(SortOrder value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'defaultSortOrder', value: value),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  defaultSortOrderGreaterThan(SortOrder value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'defaultSortOrder',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  defaultSortOrderLessThan(SortOrder value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'defaultSortOrder',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  defaultSortOrderBetween(
    SortOrder lower,
    SortOrder upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'defaultSortOrder',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  defaultViewModeEqualTo(ViewMode value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'defaultViewMode', value: value),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  defaultViewModeGreaterThan(ViewMode value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'defaultViewMode',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  defaultViewModeLessThan(ViewMode value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'defaultViewMode',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  defaultViewModeBetween(
    ViewMode lower,
    ViewMode upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'defaultViewMode',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  idLessThan(Id value, {bool include = false}) {
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  idBetween(
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  isArchivedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isArchived', value: value),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  isCatalogEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isCatalog', value: value),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  isFavoriteEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isFavorite', value: value),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  isHeaderExpandedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isHeaderExpanded', value: value),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  isHiddenEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isHidden', value: value),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  isPinnedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isPinned', value: value),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  isTrashedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isTrashed', value: value),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  lastViewedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastViewedAt'),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  lastViewedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastViewedAt'),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  lastViewedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastViewedAt', value: value),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  lastViewedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastViewedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  lastViewedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastViewedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  lastViewedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastViewedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  lastViewedItemIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastViewedItemId'),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  lastViewedItemIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastViewedItemId'),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  lastViewedItemIdEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastViewedItemId', value: value),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  lastViewedItemIdGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastViewedItemId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  lastViewedItemIdLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastViewedItemId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  lastViewedItemIdBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastViewedItemId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  notesIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'notes'),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  notesIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'notes'),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  notesEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  notesGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  notesLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  notesBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'notes',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  notesStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  notesEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  notesContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  notesMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'notes',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  notesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'notes', value: ''),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  notesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'notes', value: ''),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  pathEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  pathGreaterThan(
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  pathLessThan(
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  pathBetween(
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  pathStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  pathEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  pathContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  pathMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  pathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'path', value: ''),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  pathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'path', value: ''),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  splitSpreadViewEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'splitSpreadView', value: value),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  tierEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'tier', value: value),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  tierGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'tier',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  tierLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'tier',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  tierBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'tier',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  titleEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'title',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  titleStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  titleEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  titleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  titleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'title',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  trashRootPathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'trashRootPath'),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  trashRootPathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'trashRootPath'),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  trashRootPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'trashRootPath', value: ''),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  trashRootPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'trashRootPath', value: ''),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  typeEqualTo(CollectionType value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'type', value: value),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  typeGreaterThan(CollectionType value, {bool include = false}) {
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  typeLessThan(CollectionType value, {bool include = false}) {
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  typeBetween(
    CollectionType lower,
    CollectionType upper, {
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  uidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'uid'),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  uidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'uid'),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  uidEqualTo(String? value, {bool caseSensitive = true}) {
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  uidGreaterThan(
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  uidLessThan(
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  uidBetween(
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  uidStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  uidEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  uidContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  uidMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  uidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'uid', value: ''),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  uidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'uid', value: ''),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  updatedAtLessThan(DateTime value, {bool include = false}) {
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

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  updatedAtBetween(
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

extension MediaCollectionQueryObject
    on QueryBuilder<MediaCollection, MediaCollection, QFilterCondition> {}

extension MediaCollectionQueryLinks
    on QueryBuilder<MediaCollection, MediaCollection, QFilterCondition> {
  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition> items(
    FilterQuery<MediaItem> q,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'items');
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  itemsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'items', length, true, length, true);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  itemsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'items', 0, true, 0, true);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  itemsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'items', 0, false, 999999, true);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  itemsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'items', 0, true, length, include);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  itemsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'items', length, include, 999999, true);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  itemsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(
        r'items',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition> tags(
    FilterQuery<Tag> q,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'tags');
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  tagsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'tags', length, true, length, true);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  tagsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'tags', 0, true, 0, true);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  tagsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'tags', 0, false, 999999, true);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  tagsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'tags', 0, true, length, include);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  tagsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'tags', length, include, 999999, true);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterFilterCondition>
  tagsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(
        r'tags',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }
}

extension MediaCollectionQuerySortBy
    on QueryBuilder<MediaCollection, MediaCollection, QSortBy> {
  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy> sortByAlias() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alias', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByAliasDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alias', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByCoverImagePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverImagePath', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByCoverImagePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverImagePath', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByDefaultSortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultSortOrder', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByDefaultSortOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultSortOrder', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByDefaultViewMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultViewMode', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByDefaultViewModeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultViewMode', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByIsArchived() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isArchived', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByIsArchivedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isArchived', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByIsCatalog() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCatalog', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByIsCatalogDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCatalog', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByIsFavorite() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFavorite', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByIsFavoriteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFavorite', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByIsHeaderExpanded() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isHeaderExpanded', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByIsHeaderExpandedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isHeaderExpanded', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByIsHidden() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isHidden', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByIsHiddenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isHidden', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByIsPinned() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPinned', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByIsPinnedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPinned', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByIsTrashed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isTrashed', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByIsTrashedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isTrashed', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByLastViewedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastViewedAt', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByLastViewedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastViewedAt', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByLastViewedItemId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastViewedItemId', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByLastViewedItemIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastViewedItemId', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy> sortByNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy> sortByPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'path', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'path', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortBySplitSpreadView() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'splitSpreadView', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortBySplitSpreadViewDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'splitSpreadView', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy> sortByTier() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tier', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByTierDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tier', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByTrashRootPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trashRootPath', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByTrashRootPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trashRootPath', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy> sortByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy> sortByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uid', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy> sortByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uid', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension MediaCollectionQuerySortThenBy
    on QueryBuilder<MediaCollection, MediaCollection, QSortThenBy> {
  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy> thenByAlias() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alias', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByAliasDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alias', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByCoverImagePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverImagePath', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByCoverImagePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverImagePath', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByDefaultSortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultSortOrder', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByDefaultSortOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultSortOrder', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByDefaultViewMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultViewMode', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByDefaultViewModeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultViewMode', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByIsArchived() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isArchived', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByIsArchivedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isArchived', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByIsCatalog() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCatalog', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByIsCatalogDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCatalog', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByIsFavorite() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFavorite', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByIsFavoriteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFavorite', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByIsHeaderExpanded() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isHeaderExpanded', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByIsHeaderExpandedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isHeaderExpanded', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByIsHidden() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isHidden', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByIsHiddenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isHidden', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByIsPinned() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPinned', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByIsPinnedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPinned', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByIsTrashed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isTrashed', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByIsTrashedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isTrashed', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByLastViewedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastViewedAt', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByLastViewedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastViewedAt', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByLastViewedItemId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastViewedItemId', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByLastViewedItemIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastViewedItemId', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy> thenByNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy> thenByPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'path', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'path', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenBySplitSpreadView() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'splitSpreadView', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenBySplitSpreadViewDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'splitSpreadView', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy> thenByTier() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tier', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByTierDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tier', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByTrashRootPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trashRootPath', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByTrashRootPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trashRootPath', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy> thenByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy> thenByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uid', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy> thenByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uid', Sort.desc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QAfterSortBy>
  thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension MediaCollectionQueryWhereDistinct
    on QueryBuilder<MediaCollection, MediaCollection, QDistinct> {
  QueryBuilder<MediaCollection, MediaCollection, QDistinct> distinctByAlias({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'alias', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QDistinct>
  distinctByCoverImagePath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'coverImagePath',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QDistinct>
  distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QDistinct>
  distinctByDefaultSortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'defaultSortOrder');
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QDistinct>
  distinctByDefaultViewMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'defaultViewMode');
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QDistinct>
  distinctByIsArchived() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isArchived');
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QDistinct>
  distinctByIsCatalog() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isCatalog');
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QDistinct>
  distinctByIsFavorite() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isFavorite');
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QDistinct>
  distinctByIsHeaderExpanded() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isHeaderExpanded');
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QDistinct>
  distinctByIsHidden() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isHidden');
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QDistinct>
  distinctByIsPinned() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isPinned');
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QDistinct>
  distinctByIsTrashed() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isTrashed');
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QDistinct>
  distinctByLastViewedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastViewedAt');
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QDistinct>
  distinctByLastViewedItemId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastViewedItemId');
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QDistinct> distinctByNotes({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'notes', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QDistinct> distinctByPath({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'path', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QDistinct>
  distinctBySplitSpreadView() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'splitSpreadView');
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QDistinct> distinctByTier() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tier');
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QDistinct> distinctByTitle({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QDistinct>
  distinctByTrashRootPath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'trashRootPath',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QDistinct> distinctByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'type');
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QDistinct> distinctByUid({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'uid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MediaCollection, MediaCollection, QDistinct>
  distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension MediaCollectionQueryProperty
    on QueryBuilder<MediaCollection, MediaCollection, QQueryProperty> {
  QueryBuilder<MediaCollection, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<MediaCollection, String?, QQueryOperations> aliasProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'alias');
    });
  }

  QueryBuilder<MediaCollection, String?, QQueryOperations>
  coverImagePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'coverImagePath');
    });
  }

  QueryBuilder<MediaCollection, DateTime, QQueryOperations>
  createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<MediaCollection, SortOrder, QQueryOperations>
  defaultSortOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'defaultSortOrder');
    });
  }

  QueryBuilder<MediaCollection, ViewMode, QQueryOperations>
  defaultViewModeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'defaultViewMode');
    });
  }

  QueryBuilder<MediaCollection, bool, QQueryOperations> isArchivedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isArchived');
    });
  }

  QueryBuilder<MediaCollection, bool, QQueryOperations> isCatalogProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isCatalog');
    });
  }

  QueryBuilder<MediaCollection, bool, QQueryOperations> isFavoriteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isFavorite');
    });
  }

  QueryBuilder<MediaCollection, bool, QQueryOperations>
  isHeaderExpandedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isHeaderExpanded');
    });
  }

  QueryBuilder<MediaCollection, bool, QQueryOperations> isHiddenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isHidden');
    });
  }

  QueryBuilder<MediaCollection, bool, QQueryOperations> isPinnedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isPinned');
    });
  }

  QueryBuilder<MediaCollection, bool, QQueryOperations> isTrashedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isTrashed');
    });
  }

  QueryBuilder<MediaCollection, DateTime?, QQueryOperations>
  lastViewedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastViewedAt');
    });
  }

  QueryBuilder<MediaCollection, int?, QQueryOperations>
  lastViewedItemIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastViewedItemId');
    });
  }

  QueryBuilder<MediaCollection, String?, QQueryOperations> notesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'notes');
    });
  }

  QueryBuilder<MediaCollection, String, QQueryOperations> pathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'path');
    });
  }

  QueryBuilder<MediaCollection, bool, QQueryOperations>
  splitSpreadViewProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'splitSpreadView');
    });
  }

  QueryBuilder<MediaCollection, int, QQueryOperations> tierProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tier');
    });
  }

  QueryBuilder<MediaCollection, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<MediaCollection, String?, QQueryOperations>
  trashRootPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'trashRootPath');
    });
  }

  QueryBuilder<MediaCollection, CollectionType, QQueryOperations>
  typeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'type');
    });
  }

  QueryBuilder<MediaCollection, String?, QQueryOperations> uidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'uid');
    });
  }

  QueryBuilder<MediaCollection, DateTime, QQueryOperations>
  updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
