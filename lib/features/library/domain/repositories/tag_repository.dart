import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';

abstract class TagRepository {
  /// タグを保存（新規・更新）
  Future<Result<void, AppError>> save(Tag tag);

  /// 複数のタグを一括保存（単一トランザクション）
  Future<Result<void, AppError>> saveAll(List<Tag> tags);

  /// 対象タグと再計算済みの子孫を単一トランザクションで保存する。
  Future<Result<void, AppError>> saveTree(Tag tag, List<Tag> descendants);

  /// IDで取得
  Future<Result<Tag?, AppError>> getById(int id);

  /// キーで取得
  Future<Result<Tag?, AppError>> getByKey(String key);

  /// 全件取得
  Future<Result<List<Tag>, AppError>> getAll();

  /// タグ一覧を監視
  Stream<List<Tag>> watchTags();

  /// Facetで取得
  Future<Result<List<Tag>, AppError>> getByFacetId(int facetId);

  /// Levelで取得
  Future<Result<List<Tag>, AppError>> getByFacetAndLevel(
    int facetId,
    int level,
  );

  /// 子タグ取得
  Future<Result<List<Tag>, AppError>> getChildren(int parentId);

  /// 削除
  Future<Result<void, AppError>> delete(int id);

  /// タグの使用回数を全件再計算する
  Future<Result<void, AppError>> recalculateUsageCounts();
}
