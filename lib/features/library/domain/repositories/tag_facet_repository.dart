import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';

abstract class TagFacetRepository {
  Future<Result<void, AppError>> save(TagFacet facet);
  Future<Result<void, AppError>> saveAll(List<TagFacet> facets);
  Future<Result<TagFacet?, AppError>> getById(int id);
  Future<Result<TagFacet?, AppError>> getByName(String name);
  Future<Result<List<TagFacet>, AppError>> getAll();
  Stream<List<TagFacet>> watchFacets();
  Future<Result<void, AppError>> delete(int id);

  /// Facet配下のタグを移管してから、元Facetを単一トランザクションで削除する。
  Future<Result<void, AppError>> deleteAndReassignTags(
    int id,
    TagFacet replacement,
  );
}
