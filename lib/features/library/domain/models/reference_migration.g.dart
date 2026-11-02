// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reference_migration.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetReferenceMigrationCollection on Isar {
  IsarCollection<ReferenceMigration> get referenceMigrations =>
      this.collection();
}

const ReferenceMigrationSchema = CollectionSchema(
  name: r'ReferenceMigration',
  id: 8271158385351128976,
  properties: {
    r'checkpoints': PropertySchema(
      id: 0,
      name: r'checkpoints',
      type: IsarType.string,
    ),
    r'cleanupPending': PropertySchema(
      id: 1,
      name: r'cleanupPending',
      type: IsarType.bool,
    ),
    r'committed': PropertySchema(
      id: 2,
      name: r'committed',
      type: IsarType.bool,
    ),
    r'key': PropertySchema(id: 3, name: r'key', type: IsarType.string),
    r'snapshot': PropertySchema(
      id: 4,
      name: r'snapshot',
      type: IsarType.string,
    ),
  },

  estimateSize: _referenceMigrationEstimateSize,
  serialize: _referenceMigrationSerialize,
  deserialize: _referenceMigrationDeserialize,
  deserializeProp: _referenceMigrationDeserializeProp,
  idName: r'id',
  indexes: {
    r'key': IndexSchema(
      id: -4906094122524121629,
      name: r'key',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'key',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _referenceMigrationGetId,
  getLinks: _referenceMigrationGetLinks,
  attach: _referenceMigrationAttach,
  version: '3.1.0+1',
);

int _referenceMigrationEstimateSize(
  ReferenceMigration object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.checkpoints.length * 3;
  bytesCount += 3 + object.key.length * 3;
  bytesCount += 3 + object.snapshot.length * 3;
  return bytesCount;
}

void _referenceMigrationSerialize(
  ReferenceMigration object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.checkpoints);
  writer.writeBool(offsets[1], object.cleanupPending);
  writer.writeBool(offsets[2], object.committed);
  writer.writeString(offsets[3], object.key);
  writer.writeString(offsets[4], object.snapshot);
}

ReferenceMigration _referenceMigrationDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ReferenceMigration();
  object.checkpoints = reader.readString(offsets[0]);
  object.cleanupPending = reader.readBool(offsets[1]);
  object.committed = reader.readBool(offsets[2]);
  object.id = id;
  object.key = reader.readString(offsets[3]);
  object.snapshot = reader.readString(offsets[4]);
  return object;
}

P _referenceMigrationDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readBool(offset)) as P;
    case 2:
      return (reader.readBool(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _referenceMigrationGetId(ReferenceMigration object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _referenceMigrationGetLinks(
  ReferenceMigration object,
) {
  return [];
}

void _referenceMigrationAttach(
  IsarCollection<dynamic> col,
  Id id,
  ReferenceMigration object,
) {
  object.id = id;
}

extension ReferenceMigrationByIndex on IsarCollection<ReferenceMigration> {
  Future<ReferenceMigration?> getByKey(String key) {
    return getByIndex(r'key', [key]);
  }

  ReferenceMigration? getByKeySync(String key) {
    return getByIndexSync(r'key', [key]);
  }

  Future<bool> deleteByKey(String key) {
    return deleteByIndex(r'key', [key]);
  }

  bool deleteByKeySync(String key) {
    return deleteByIndexSync(r'key', [key]);
  }

  Future<List<ReferenceMigration?>> getAllByKey(List<String> keyValues) {
    final values = keyValues.map((e) => [e]).toList();
    return getAllByIndex(r'key', values);
  }

  List<ReferenceMigration?> getAllByKeySync(List<String> keyValues) {
    final values = keyValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'key', values);
  }

  Future<int> deleteAllByKey(List<String> keyValues) {
    final values = keyValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'key', values);
  }

  int deleteAllByKeySync(List<String> keyValues) {
    final values = keyValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'key', values);
  }

  Future<Id> putByKey(ReferenceMigration object) {
    return putByIndex(r'key', object);
  }

  Id putByKeySync(ReferenceMigration object, {bool saveLinks = true}) {
    return putByIndexSync(r'key', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByKey(List<ReferenceMigration> objects) {
    return putAllByIndex(r'key', objects);
  }

  List<Id> putAllByKeySync(
    List<ReferenceMigration> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'key', objects, saveLinks: saveLinks);
  }
}

extension ReferenceMigrationQueryWhereSort
    on QueryBuilder<ReferenceMigration, ReferenceMigration, QWhere> {
  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ReferenceMigrationQueryWhere
    on QueryBuilder<ReferenceMigration, ReferenceMigration, QWhereClause> {
  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterWhereClause>
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

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterWhereClause>
  idBetween(
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

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterWhereClause>
  keyEqualTo(String key) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'key', value: [key]),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterWhereClause>
  keyNotEqualTo(String key) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'key',
                lower: [],
                upper: [key],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'key',
                lower: [key],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'key',
                lower: [key],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'key',
                lower: [],
                upper: [key],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension ReferenceMigrationQueryFilter
    on QueryBuilder<ReferenceMigration, ReferenceMigration, QFilterCondition> {
  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  checkpointsEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'checkpoints',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  checkpointsGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'checkpoints',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  checkpointsLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'checkpoints',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  checkpointsBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'checkpoints',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  checkpointsStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'checkpoints',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  checkpointsEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'checkpoints',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  checkpointsContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'checkpoints',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  checkpointsMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'checkpoints',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  checkpointsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'checkpoints', value: ''),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  checkpointsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'checkpoints', value: ''),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  cleanupPendingEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cleanupPending', value: value),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  committedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'committed', value: value),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
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

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
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

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
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

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  keyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'key',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  keyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'key',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  keyLessThan(String value, {bool include = false, bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'key',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  keyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'key',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  keyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'key',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  keyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'key',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  keyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'key',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  keyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'key',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  keyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'key', value: ''),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  keyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'key', value: ''),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  snapshotEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'snapshot',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  snapshotGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'snapshot',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  snapshotLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'snapshot',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  snapshotBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'snapshot',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  snapshotStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'snapshot',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  snapshotEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'snapshot',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  snapshotContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'snapshot',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  snapshotMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'snapshot',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  snapshotIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'snapshot', value: ''),
      );
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterFilterCondition>
  snapshotIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'snapshot', value: ''),
      );
    });
  }
}

extension ReferenceMigrationQueryObject
    on QueryBuilder<ReferenceMigration, ReferenceMigration, QFilterCondition> {}

extension ReferenceMigrationQueryLinks
    on QueryBuilder<ReferenceMigration, ReferenceMigration, QFilterCondition> {}

extension ReferenceMigrationQuerySortBy
    on QueryBuilder<ReferenceMigration, ReferenceMigration, QSortBy> {
  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterSortBy>
  sortByCheckpoints() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checkpoints', Sort.asc);
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterSortBy>
  sortByCheckpointsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checkpoints', Sort.desc);
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterSortBy>
  sortByCleanupPending() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cleanupPending', Sort.asc);
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterSortBy>
  sortByCleanupPendingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cleanupPending', Sort.desc);
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterSortBy>
  sortByCommitted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'committed', Sort.asc);
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterSortBy>
  sortByCommittedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'committed', Sort.desc);
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterSortBy>
  sortByKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'key', Sort.asc);
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterSortBy>
  sortByKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'key', Sort.desc);
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterSortBy>
  sortBySnapshot() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'snapshot', Sort.asc);
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterSortBy>
  sortBySnapshotDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'snapshot', Sort.desc);
    });
  }
}

extension ReferenceMigrationQuerySortThenBy
    on QueryBuilder<ReferenceMigration, ReferenceMigration, QSortThenBy> {
  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterSortBy>
  thenByCheckpoints() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checkpoints', Sort.asc);
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterSortBy>
  thenByCheckpointsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checkpoints', Sort.desc);
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterSortBy>
  thenByCleanupPending() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cleanupPending', Sort.asc);
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterSortBy>
  thenByCleanupPendingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cleanupPending', Sort.desc);
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterSortBy>
  thenByCommitted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'committed', Sort.asc);
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterSortBy>
  thenByCommittedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'committed', Sort.desc);
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterSortBy>
  thenByKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'key', Sort.asc);
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterSortBy>
  thenByKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'key', Sort.desc);
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterSortBy>
  thenBySnapshot() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'snapshot', Sort.asc);
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QAfterSortBy>
  thenBySnapshotDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'snapshot', Sort.desc);
    });
  }
}

extension ReferenceMigrationQueryWhereDistinct
    on QueryBuilder<ReferenceMigration, ReferenceMigration, QDistinct> {
  QueryBuilder<ReferenceMigration, ReferenceMigration, QDistinct>
  distinctByCheckpoints({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'checkpoints', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QDistinct>
  distinctByCleanupPending() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cleanupPending');
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QDistinct>
  distinctByCommitted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'committed');
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QDistinct>
  distinctByKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'key', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ReferenceMigration, ReferenceMigration, QDistinct>
  distinctBySnapshot({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'snapshot', caseSensitive: caseSensitive);
    });
  }
}

extension ReferenceMigrationQueryProperty
    on QueryBuilder<ReferenceMigration, ReferenceMigration, QQueryProperty> {
  QueryBuilder<ReferenceMigration, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ReferenceMigration, String, QQueryOperations>
  checkpointsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'checkpoints');
    });
  }

  QueryBuilder<ReferenceMigration, bool, QQueryOperations>
  cleanupPendingProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cleanupPending');
    });
  }

  QueryBuilder<ReferenceMigration, bool, QQueryOperations> committedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'committed');
    });
  }

  QueryBuilder<ReferenceMigration, String, QQueryOperations> keyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'key');
    });
  }

  QueryBuilder<ReferenceMigration, String, QQueryOperations>
  snapshotProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'snapshot');
    });
  }
}
