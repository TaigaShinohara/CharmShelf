// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'storage_ref.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetStorageRefCollection on Isar {
  IsarCollection<StorageRef> get storageRefs => this.collection();
}

const StorageRefSchema = CollectionSchema(
  name: r'StorageRef',
  id: 2768276394694657656,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'isPrimary': PropertySchema(
      id: 1,
      name: r'isPrimary',
      type: IsarType.bool,
    ),
    r'locator': PropertySchema(id: 2, name: r'locator', type: IsarType.string),
    r'normalizedLocator': PropertySchema(
      id: 3,
      name: r'normalizedLocator',
      type: IsarType.string,
    ),
    r'ownerType': PropertySchema(
      id: 4,
      name: r'ownerType',
      type: IsarType.byte,
      enumMap: _StorageRefownerTypeEnumValueMap,
    ),
    r'ownerUid': PropertySchema(
      id: 5,
      name: r'ownerUid',
      type: IsarType.string,
    ),
    r'parentUid': PropertySchema(
      id: 6,
      name: r'parentUid',
      type: IsarType.string,
    ),
    r'sourceType': PropertySchema(
      id: 7,
      name: r'sourceType',
      type: IsarType.byte,
      enumMap: _StorageRefsourceTypeEnumValueMap,
    ),
    r'uid': PropertySchema(id: 8, name: r'uid', type: IsarType.string),
    r'updatedAt': PropertySchema(
      id: 9,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
  },

  estimateSize: _storageRefEstimateSize,
  serialize: _storageRefSerialize,
  deserialize: _storageRefDeserialize,
  deserializeProp: _storageRefDeserializeProp,
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
    r'ownerUid': IndexSchema(
      id: -8016718989707307851,
      name: r'ownerUid',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'ownerUid',
          type: IndexType.value,
          caseSensitive: true,
        ),
      ],
    ),
    r'locator': IndexSchema(
      id: 2063308390449673127,
      name: r'locator',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'locator',
          type: IndexType.value,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _storageRefGetId,
  getLinks: _storageRefGetLinks,
  attach: _storageRefAttach,
  version: '3.1.0+1',
);

int _storageRefEstimateSize(
  StorageRef object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.locator.length * 3;
  {
    final value = object.normalizedLocator;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.ownerUid.length * 3;
  {
    final value = object.parentUid;
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

void _storageRefSerialize(
  StorageRef object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeBool(offsets[1], object.isPrimary);
  writer.writeString(offsets[2], object.locator);
  writer.writeString(offsets[3], object.normalizedLocator);
  writer.writeByte(offsets[4], object.ownerType.index);
  writer.writeString(offsets[5], object.ownerUid);
  writer.writeString(offsets[6], object.parentUid);
  writer.writeByte(offsets[7], object.sourceType.index);
  writer.writeString(offsets[8], object.uid);
  writer.writeDateTime(offsets[9], object.updatedAt);
}

StorageRef _storageRefDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = StorageRef();
  object.createdAt = reader.readDateTime(offsets[0]);
  object.id = id;
  object.isPrimary = reader.readBool(offsets[1]);
  object.locator = reader.readString(offsets[2]);
  object.normalizedLocator = reader.readStringOrNull(offsets[3]);
  object.ownerType =
      _StorageRefownerTypeValueEnumMap[reader.readByteOrNull(offsets[4])] ??
      StorageOwnerType.collection;
  object.ownerUid = reader.readString(offsets[5]);
  object.parentUid = reader.readStringOrNull(offsets[6]);
  object.sourceType =
      _StorageRefsourceTypeValueEnumMap[reader.readByteOrNull(offsets[7])] ??
      StorageSourceType.local;
  object.uid = reader.readStringOrNull(offsets[8]);
  object.updatedAt = reader.readDateTime(offsets[9]);
  return object;
}

P _storageRefDeserializeProp<P>(
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
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (_StorageRefownerTypeValueEnumMap[reader.readByteOrNull(offset)] ??
              StorageOwnerType.collection)
          as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (_StorageRefsourceTypeValueEnumMap[reader.readByteOrNull(
                offset,
              )] ??
              StorageSourceType.local)
          as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _StorageRefownerTypeEnumValueMap = {'collection': 0, 'item': 1};
const _StorageRefownerTypeValueEnumMap = {
  0: StorageOwnerType.collection,
  1: StorageOwnerType.item,
};
const _StorageRefsourceTypeEnumValueMap = {'local': 0, 'external': 1};
const _StorageRefsourceTypeValueEnumMap = {
  0: StorageSourceType.local,
  1: StorageSourceType.external,
};

Id _storageRefGetId(StorageRef object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _storageRefGetLinks(StorageRef object) {
  return [];
}

void _storageRefAttach(IsarCollection<dynamic> col, Id id, StorageRef object) {
  object.id = id;
}

extension StorageRefByIndex on IsarCollection<StorageRef> {
  Future<StorageRef?> getByUid(String? uid) {
    return getByIndex(r'uid', [uid]);
  }

  StorageRef? getByUidSync(String? uid) {
    return getByIndexSync(r'uid', [uid]);
  }

  Future<bool> deleteByUid(String? uid) {
    return deleteByIndex(r'uid', [uid]);
  }

  bool deleteByUidSync(String? uid) {
    return deleteByIndexSync(r'uid', [uid]);
  }

  Future<List<StorageRef?>> getAllByUid(List<String?> uidValues) {
    final values = uidValues.map((e) => [e]).toList();
    return getAllByIndex(r'uid', values);
  }

  List<StorageRef?> getAllByUidSync(List<String?> uidValues) {
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

  Future<Id> putByUid(StorageRef object) {
    return putByIndex(r'uid', object);
  }

  Id putByUidSync(StorageRef object, {bool saveLinks = true}) {
    return putByIndexSync(r'uid', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByUid(List<StorageRef> objects) {
    return putAllByIndex(r'uid', objects);
  }

  List<Id> putAllByUidSync(List<StorageRef> objects, {bool saveLinks = true}) {
    return putAllByIndexSync(r'uid', objects, saveLinks: saveLinks);
  }
}

extension StorageRefQueryWhereSort
    on QueryBuilder<StorageRef, StorageRef, QWhere> {
  QueryBuilder<StorageRef, StorageRef, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterWhere> anyOwnerUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'ownerUid'),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterWhere> anyLocator() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'locator'),
      );
    });
  }
}

extension StorageRefQueryWhere
    on QueryBuilder<StorageRef, StorageRef, QWhereClause> {
  QueryBuilder<StorageRef, StorageRef, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<StorageRef, StorageRef, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterWhereClause> idBetween(
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

  QueryBuilder<StorageRef, StorageRef, QAfterWhereClause> uidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'uid', value: [null]),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterWhereClause> uidIsNotNull() {
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

  QueryBuilder<StorageRef, StorageRef, QAfterWhereClause> uidEqualTo(
    String? uid,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'uid', value: [uid]),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterWhereClause> uidNotEqualTo(
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

  QueryBuilder<StorageRef, StorageRef, QAfterWhereClause> ownerUidEqualTo(
    String ownerUid,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'ownerUid', value: [ownerUid]),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterWhereClause> ownerUidNotEqualTo(
    String ownerUid,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ownerUid',
                lower: [],
                upper: [ownerUid],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ownerUid',
                lower: [ownerUid],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ownerUid',
                lower: [ownerUid],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ownerUid',
                lower: [],
                upper: [ownerUid],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterWhereClause> ownerUidGreaterThan(
    String ownerUid, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'ownerUid',
          lower: [ownerUid],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterWhereClause> ownerUidLessThan(
    String ownerUid, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'ownerUid',
          lower: [],
          upper: [ownerUid],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterWhereClause> ownerUidBetween(
    String lowerOwnerUid,
    String upperOwnerUid, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'ownerUid',
          lower: [lowerOwnerUid],
          includeLower: includeLower,
          upper: [upperOwnerUid],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterWhereClause> ownerUidStartsWith(
    String OwnerUidPrefix,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'ownerUid',
          lower: [OwnerUidPrefix],
          upper: ['$OwnerUidPrefix\u{FFFFF}'],
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterWhereClause> ownerUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'ownerUid', value: ['']),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterWhereClause> ownerUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.lessThan(indexName: r'ownerUid', upper: ['']),
            )
            .addWhereClause(
              IndexWhereClause.greaterThan(indexName: r'ownerUid', lower: ['']),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.greaterThan(indexName: r'ownerUid', lower: ['']),
            )
            .addWhereClause(
              IndexWhereClause.lessThan(indexName: r'ownerUid', upper: ['']),
            );
      }
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterWhereClause> locatorEqualTo(
    String locator,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'locator', value: [locator]),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterWhereClause> locatorNotEqualTo(
    String locator,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'locator',
                lower: [],
                upper: [locator],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'locator',
                lower: [locator],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'locator',
                lower: [locator],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'locator',
                lower: [],
                upper: [locator],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterWhereClause> locatorGreaterThan(
    String locator, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'locator',
          lower: [locator],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterWhereClause> locatorLessThan(
    String locator, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'locator',
          lower: [],
          upper: [locator],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterWhereClause> locatorBetween(
    String lowerLocator,
    String upperLocator, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'locator',
          lower: [lowerLocator],
          includeLower: includeLower,
          upper: [upperLocator],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterWhereClause> locatorStartsWith(
    String LocatorPrefix,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'locator',
          lower: [LocatorPrefix],
          upper: ['$LocatorPrefix\u{FFFFF}'],
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterWhereClause> locatorIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'locator', value: ['']),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterWhereClause> locatorIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.lessThan(indexName: r'locator', upper: ['']),
            )
            .addWhereClause(
              IndexWhereClause.greaterThan(indexName: r'locator', lower: ['']),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.greaterThan(indexName: r'locator', lower: ['']),
            )
            .addWhereClause(
              IndexWhereClause.lessThan(indexName: r'locator', upper: ['']),
            );
      }
    });
  }
}

extension StorageRefQueryFilter
    on QueryBuilder<StorageRef, StorageRef, QFilterCondition> {
  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> createdAtEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
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

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
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

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> createdAtBetween(
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

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> idBetween(
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

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> isPrimaryEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isPrimary', value: value),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> locatorEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'locator',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
  locatorGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'locator',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> locatorLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'locator',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> locatorBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'locator',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> locatorStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'locator',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> locatorEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'locator',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> locatorContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'locator',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> locatorMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'locator',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> locatorIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'locator', value: ''),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
  locatorIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'locator', value: ''),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
  normalizedLocatorIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'normalizedLocator'),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
  normalizedLocatorIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'normalizedLocator'),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
  normalizedLocatorEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'normalizedLocator',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
  normalizedLocatorGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'normalizedLocator',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
  normalizedLocatorLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'normalizedLocator',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
  normalizedLocatorBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'normalizedLocator',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
  normalizedLocatorStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'normalizedLocator',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
  normalizedLocatorEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'normalizedLocator',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
  normalizedLocatorContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'normalizedLocator',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
  normalizedLocatorMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'normalizedLocator',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
  normalizedLocatorIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'normalizedLocator', value: ''),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
  normalizedLocatorIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'normalizedLocator', value: ''),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> ownerTypeEqualTo(
    StorageOwnerType value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'ownerType', value: value),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
  ownerTypeGreaterThan(StorageOwnerType value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'ownerType',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> ownerTypeLessThan(
    StorageOwnerType value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'ownerType',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> ownerTypeBetween(
    StorageOwnerType lower,
    StorageOwnerType upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'ownerType',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> ownerUidEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'ownerUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
  ownerUidGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'ownerUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> ownerUidLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'ownerUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> ownerUidBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'ownerUid',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
  ownerUidStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'ownerUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> ownerUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'ownerUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> ownerUidContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'ownerUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> ownerUidMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'ownerUid',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
  ownerUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'ownerUid', value: ''),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
  ownerUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'ownerUid', value: ''),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
  parentUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'parentUid'),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
  parentUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'parentUid'),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> parentUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'parentUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
  parentUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'parentUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> parentUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'parentUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> parentUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'parentUid',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
  parentUidStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'parentUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> parentUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'parentUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> parentUidContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'parentUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> parentUidMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'parentUid',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
  parentUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'parentUid', value: ''),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
  parentUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'parentUid', value: ''),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> sourceTypeEqualTo(
    StorageSourceType value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sourceType', value: value),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
  sourceTypeGreaterThan(StorageSourceType value, {bool include = false}) {
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

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
  sourceTypeLessThan(StorageSourceType value, {bool include = false}) {
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

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> sourceTypeBetween(
    StorageSourceType lower,
    StorageSourceType upper, {
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

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> uidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'uid'),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> uidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'uid'),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> uidEqualTo(
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

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> uidGreaterThan(
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

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> uidLessThan(
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

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> uidBetween(
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

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> uidStartsWith(
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

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> uidEndsWith(
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

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> uidContains(
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

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> uidMatches(
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

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> uidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'uid', value: ''),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> uidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'uid', value: ''),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> updatedAtEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition>
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

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> updatedAtLessThan(
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

  QueryBuilder<StorageRef, StorageRef, QAfterFilterCondition> updatedAtBetween(
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

extension StorageRefQueryObject
    on QueryBuilder<StorageRef, StorageRef, QFilterCondition> {}

extension StorageRefQueryLinks
    on QueryBuilder<StorageRef, StorageRef, QFilterCondition> {}

extension StorageRefQuerySortBy
    on QueryBuilder<StorageRef, StorageRef, QSortBy> {
  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> sortByIsPrimary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPrimary', Sort.asc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> sortByIsPrimaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPrimary', Sort.desc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> sortByLocator() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'locator', Sort.asc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> sortByLocatorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'locator', Sort.desc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> sortByNormalizedLocator() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'normalizedLocator', Sort.asc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy>
  sortByNormalizedLocatorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'normalizedLocator', Sort.desc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> sortByOwnerType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerType', Sort.asc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> sortByOwnerTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerType', Sort.desc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> sortByOwnerUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerUid', Sort.asc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> sortByOwnerUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerUid', Sort.desc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> sortByParentUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentUid', Sort.asc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> sortByParentUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentUid', Sort.desc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> sortBySourceType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceType', Sort.asc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> sortBySourceTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceType', Sort.desc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> sortByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uid', Sort.asc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> sortByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uid', Sort.desc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension StorageRefQuerySortThenBy
    on QueryBuilder<StorageRef, StorageRef, QSortThenBy> {
  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> thenByIsPrimary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPrimary', Sort.asc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> thenByIsPrimaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPrimary', Sort.desc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> thenByLocator() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'locator', Sort.asc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> thenByLocatorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'locator', Sort.desc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> thenByNormalizedLocator() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'normalizedLocator', Sort.asc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy>
  thenByNormalizedLocatorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'normalizedLocator', Sort.desc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> thenByOwnerType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerType', Sort.asc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> thenByOwnerTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerType', Sort.desc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> thenByOwnerUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerUid', Sort.asc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> thenByOwnerUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerUid', Sort.desc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> thenByParentUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentUid', Sort.asc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> thenByParentUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentUid', Sort.desc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> thenBySourceType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceType', Sort.asc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> thenBySourceTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceType', Sort.desc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> thenByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uid', Sort.asc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> thenByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uid', Sort.desc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension StorageRefQueryWhereDistinct
    on QueryBuilder<StorageRef, StorageRef, QDistinct> {
  QueryBuilder<StorageRef, StorageRef, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<StorageRef, StorageRef, QDistinct> distinctByIsPrimary() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isPrimary');
    });
  }

  QueryBuilder<StorageRef, StorageRef, QDistinct> distinctByLocator({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'locator', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QDistinct> distinctByNormalizedLocator({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'normalizedLocator',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<StorageRef, StorageRef, QDistinct> distinctByOwnerType() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerType');
    });
  }

  QueryBuilder<StorageRef, StorageRef, QDistinct> distinctByOwnerUid({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QDistinct> distinctByParentUid({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'parentUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QDistinct> distinctBySourceType() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceType');
    });
  }

  QueryBuilder<StorageRef, StorageRef, QDistinct> distinctByUid({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'uid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StorageRef, StorageRef, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension StorageRefQueryProperty
    on QueryBuilder<StorageRef, StorageRef, QQueryProperty> {
  QueryBuilder<StorageRef, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<StorageRef, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<StorageRef, bool, QQueryOperations> isPrimaryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isPrimary');
    });
  }

  QueryBuilder<StorageRef, String, QQueryOperations> locatorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'locator');
    });
  }

  QueryBuilder<StorageRef, String?, QQueryOperations>
  normalizedLocatorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'normalizedLocator');
    });
  }

  QueryBuilder<StorageRef, StorageOwnerType, QQueryOperations>
  ownerTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerType');
    });
  }

  QueryBuilder<StorageRef, String, QQueryOperations> ownerUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerUid');
    });
  }

  QueryBuilder<StorageRef, String?, QQueryOperations> parentUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'parentUid');
    });
  }

  QueryBuilder<StorageRef, StorageSourceType, QQueryOperations>
  sourceTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceType');
    });
  }

  QueryBuilder<StorageRef, String?, QQueryOperations> uidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'uid');
    });
  }

  QueryBuilder<StorageRef, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
