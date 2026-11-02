// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'viewing_history.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetViewingHistoryCollection on Isar {
  IsarCollection<ViewingHistory> get viewingHistorys => this.collection();
}

const ViewingHistorySchema = CollectionSchema(
  name: r'ViewingHistory',
  id: -1411224508816741929,
  properties: {
    r'itemUid': PropertySchema(id: 0, name: r'itemUid', type: IsarType.string),
    r'openedAt': PropertySchema(
      id: 1,
      name: r'openedAt',
      type: IsarType.dateTime,
    ),
  },

  estimateSize: _viewingHistoryEstimateSize,
  serialize: _viewingHistorySerialize,
  deserialize: _viewingHistoryDeserialize,
  deserializeProp: _viewingHistoryDeserializeProp,
  idName: r'id',
  indexes: {
    r'itemUid': IndexSchema(
      id: -2069666004872549333,
      name: r'itemUid',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'itemUid',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'openedAt': IndexSchema(
      id: -5170574981129517220,
      name: r'openedAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'openedAt',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _viewingHistoryGetId,
  getLinks: _viewingHistoryGetLinks,
  attach: _viewingHistoryAttach,
  version: '3.1.0+1',
);

int _viewingHistoryEstimateSize(
  ViewingHistory object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.itemUid.length * 3;
  return bytesCount;
}

void _viewingHistorySerialize(
  ViewingHistory object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.itemUid);
  writer.writeDateTime(offsets[1], object.openedAt);
}

ViewingHistory _viewingHistoryDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ViewingHistory();
  object.id = id;
  object.itemUid = reader.readString(offsets[0]);
  object.openedAt = reader.readDateTime(offsets[1]);
  return object;
}

P _viewingHistoryDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _viewingHistoryGetId(ViewingHistory object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _viewingHistoryGetLinks(ViewingHistory object) {
  return [];
}

void _viewingHistoryAttach(
  IsarCollection<dynamic> col,
  Id id,
  ViewingHistory object,
) {
  object.id = id;
}

extension ViewingHistoryByIndex on IsarCollection<ViewingHistory> {
  Future<ViewingHistory?> getByItemUid(String itemUid) {
    return getByIndex(r'itemUid', [itemUid]);
  }

  ViewingHistory? getByItemUidSync(String itemUid) {
    return getByIndexSync(r'itemUid', [itemUid]);
  }

  Future<bool> deleteByItemUid(String itemUid) {
    return deleteByIndex(r'itemUid', [itemUid]);
  }

  bool deleteByItemUidSync(String itemUid) {
    return deleteByIndexSync(r'itemUid', [itemUid]);
  }

  Future<List<ViewingHistory?>> getAllByItemUid(List<String> itemUidValues) {
    final values = itemUidValues.map((e) => [e]).toList();
    return getAllByIndex(r'itemUid', values);
  }

  List<ViewingHistory?> getAllByItemUidSync(List<String> itemUidValues) {
    final values = itemUidValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'itemUid', values);
  }

  Future<int> deleteAllByItemUid(List<String> itemUidValues) {
    final values = itemUidValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'itemUid', values);
  }

  int deleteAllByItemUidSync(List<String> itemUidValues) {
    final values = itemUidValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'itemUid', values);
  }

  Future<Id> putByItemUid(ViewingHistory object) {
    return putByIndex(r'itemUid', object);
  }

  Id putByItemUidSync(ViewingHistory object, {bool saveLinks = true}) {
    return putByIndexSync(r'itemUid', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByItemUid(List<ViewingHistory> objects) {
    return putAllByIndex(r'itemUid', objects);
  }

  List<Id> putAllByItemUidSync(
    List<ViewingHistory> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'itemUid', objects, saveLinks: saveLinks);
  }
}

extension ViewingHistoryQueryWhereSort
    on QueryBuilder<ViewingHistory, ViewingHistory, QWhere> {
  QueryBuilder<ViewingHistory, ViewingHistory, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterWhere> anyOpenedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'openedAt'),
      );
    });
  }
}

extension ViewingHistoryQueryWhere
    on QueryBuilder<ViewingHistory, ViewingHistory, QWhereClause> {
  QueryBuilder<ViewingHistory, ViewingHistory, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterWhereClause> idNotEqualTo(
    Id id,
  ) {
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

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterWhereClause> idBetween(
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

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterWhereClause>
  itemUidEqualTo(String itemUid) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'itemUid', value: [itemUid]),
      );
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterWhereClause>
  itemUidNotEqualTo(String itemUid) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'itemUid',
                lower: [],
                upper: [itemUid],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'itemUid',
                lower: [itemUid],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'itemUid',
                lower: [itemUid],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'itemUid',
                lower: [],
                upper: [itemUid],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterWhereClause>
  openedAtEqualTo(DateTime openedAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'openedAt', value: [openedAt]),
      );
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterWhereClause>
  openedAtNotEqualTo(DateTime openedAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'openedAt',
                lower: [],
                upper: [openedAt],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'openedAt',
                lower: [openedAt],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'openedAt',
                lower: [openedAt],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'openedAt',
                lower: [],
                upper: [openedAt],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterWhereClause>
  openedAtGreaterThan(DateTime openedAt, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'openedAt',
          lower: [openedAt],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterWhereClause>
  openedAtLessThan(DateTime openedAt, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'openedAt',
          lower: [],
          upper: [openedAt],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterWhereClause>
  openedAtBetween(
    DateTime lowerOpenedAt,
    DateTime upperOpenedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'openedAt',
          lower: [lowerOpenedAt],
          includeLower: includeLower,
          upper: [upperOpenedAt],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ViewingHistoryQueryFilter
    on QueryBuilder<ViewingHistory, ViewingHistory, QFilterCondition> {
  QueryBuilder<ViewingHistory, ViewingHistory, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterFilterCondition>
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

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterFilterCondition>
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

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterFilterCondition> idBetween(
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

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterFilterCondition>
  itemUidEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'itemUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterFilterCondition>
  itemUidGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'itemUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterFilterCondition>
  itemUidLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'itemUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterFilterCondition>
  itemUidBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'itemUid',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterFilterCondition>
  itemUidStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'itemUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterFilterCondition>
  itemUidEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'itemUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterFilterCondition>
  itemUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'itemUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterFilterCondition>
  itemUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'itemUid',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterFilterCondition>
  itemUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'itemUid', value: ''),
      );
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterFilterCondition>
  itemUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'itemUid', value: ''),
      );
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterFilterCondition>
  openedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'openedAt', value: value),
      );
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterFilterCondition>
  openedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'openedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterFilterCondition>
  openedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'openedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterFilterCondition>
  openedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'openedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ViewingHistoryQueryObject
    on QueryBuilder<ViewingHistory, ViewingHistory, QFilterCondition> {}

extension ViewingHistoryQueryLinks
    on QueryBuilder<ViewingHistory, ViewingHistory, QFilterCondition> {}

extension ViewingHistoryQuerySortBy
    on QueryBuilder<ViewingHistory, ViewingHistory, QSortBy> {
  QueryBuilder<ViewingHistory, ViewingHistory, QAfterSortBy> sortByItemUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemUid', Sort.asc);
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterSortBy>
  sortByItemUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemUid', Sort.desc);
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterSortBy> sortByOpenedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openedAt', Sort.asc);
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterSortBy>
  sortByOpenedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openedAt', Sort.desc);
    });
  }
}

extension ViewingHistoryQuerySortThenBy
    on QueryBuilder<ViewingHistory, ViewingHistory, QSortThenBy> {
  QueryBuilder<ViewingHistory, ViewingHistory, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterSortBy> thenByItemUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemUid', Sort.asc);
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterSortBy>
  thenByItemUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemUid', Sort.desc);
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterSortBy> thenByOpenedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openedAt', Sort.asc);
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QAfterSortBy>
  thenByOpenedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openedAt', Sort.desc);
    });
  }
}

extension ViewingHistoryQueryWhereDistinct
    on QueryBuilder<ViewingHistory, ViewingHistory, QDistinct> {
  QueryBuilder<ViewingHistory, ViewingHistory, QDistinct> distinctByItemUid({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'itemUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ViewingHistory, ViewingHistory, QDistinct> distinctByOpenedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'openedAt');
    });
  }
}

extension ViewingHistoryQueryProperty
    on QueryBuilder<ViewingHistory, ViewingHistory, QQueryProperty> {
  QueryBuilder<ViewingHistory, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ViewingHistory, String, QQueryOperations> itemUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'itemUid');
    });
  }

  QueryBuilder<ViewingHistory, DateTime, QQueryOperations> openedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'openedAt');
    });
  }
}
