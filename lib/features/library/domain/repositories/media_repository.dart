import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/folder_summary.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';

abstract class MediaRepository {
  /// メディアを保存（新規・更新）
  Future<Result<void, AppError>> save(MediaItem item);

  /// 生成済みサムネイルのパスだけを保存し、一覧監視を再実行しない。
  Future<Result<void, AppError>> saveGeneratedThumbnailPath(
    int id,
    String itemPath,
    String thumbnailPath,
  );

  /// 複数のメディアを一括保存
  Future<Result<void, AppError>> saveAll(List<MediaItem> items);

  /// IDで取得
  Future<Result<MediaItem?, AppError>> getById(int id);

  /// UIDで取得
  Future<Result<MediaItem?, AppError>> getByUid(String uid);

  /// 全件取得（検証用・初期ロード用）
  Future<Result<List<MediaItem>, AppError>> getAll({MediaFilter? filter});

  Future<Result<List<MediaItem>, AppError>> getPage({
    required MediaFilter filter,
    required int offset,
    required int limit,
  });

  /// Invalidates an open page session; does not load any file or tag data.
  Stream<void> watchLibraryChanges({required MediaFilter filter});

  /// 検索条件に応じたメディアのストリームを取得
  Stream<List<MediaItem>> watchAll({MediaFilter? filter});

  /// 最近閲覧した項目を、フィルター適用後の閲覧日時順で取得する。
  Future<Result<List<MediaItem>, AppError>> getRecentMedia({
    int limit = 10,
    MediaSourceType? sourceType,
    bool? isHidden,
  });

  /// 最近閲覧した項目を、全件ロードせずに監視する。
  Stream<List<MediaItem>> watchRecentMedia({
    int limit = 10,
    MediaSourceType? sourceType,
    bool? isHidden,
  });

  /// 削除
  Future<Result<void, AppError>> delete(int id);

  /// 一括削除
  Future<Result<void, AppError>> deleteAll(List<int> ids);

  /// アイテム・カタログ・関連参照を単一DBトランザクションで削除する。
  Future<Result<void, AppError>> deleteGraph(
    List<int> itemIds,
    List<int> collectionIds,
  );

  /// アイテム・カタロググラフを復元可能なごみ箱状態へ移す。
  Future<Result<void, AppError>> moveGraphToTrash(
    List<int> itemIds,
    List<int> collectionIds, {
    required int rootItemId,
    required String? trashPath,
    required DateTime trashedAt,
  });

  /// ごみ箱一覧に表示する削除ルートを取得する。
  Future<Result<List<MediaItem>, AppError>> getTrashedRoots();

  /// 単一の削除操作に属するごみ箱内アイテムを取得する。
  Future<Result<List<MediaItem>, AppError>> getTrashedItems(String rootPath);

  /// 単一の削除操作に属するごみ箱内カタログを取得する。
  Future<Result<List<MediaCollection>, AppError>> getTrashedCollections(
    String rootPath,
  );

  /// 復元対象と同じパスを持つ通常項目・カタログを取得する。
  Future<Result<List<String>, AppError>> getTrashRestoreConflicts(
    String rootPath,
  );

  /// 指定ルート配下のアイテム・カタログをごみ箱状態から復元する。
  Future<Result<void, AppError>> restoreGraphFromTrash(
    String rootPath, {
    String? targetRootPath,
    String? targetParentPath,
  });

  /// 親フォルダパスで取得（階層表示用）
  Future<Result<List<MediaItem>, AppError>> getByParentPath(String? parentPath);

  /// Direct file candidates only; no collection/tag hydration or display sort.
  Future<Result<List<MediaItem>, AppError>> getCoverCandidates(
    String parentPath,
  );

  /// パスで取得
  Future<Result<MediaItem?, AppError>> getByPath(
    String path, {
    bool includeTrashed = true,
  });

  /// ピン留めされたコレクションを取得
  Future<Result<List<MediaCollection>, AppError>> getPinnedCollections({
    CollectionType? type,
    bool? isHidden,
  });

  /// ピン留めされたコレクションを監視
  Stream<List<MediaCollection>> watchPinnedCollections({
    CollectionType? type,
    bool? isHidden,
  });

  /// お気に入り登録されたコレクションを取得
  Future<Result<List<MediaCollection>, AppError>> getFavoriteCollections({
    CollectionType? type,
    bool? isHidden,
  });

  /// お気に入り登録されたコレクションを監視
  Stream<List<MediaCollection>> watchFavoriteCollections({
    CollectionType? type,
    bool? isHidden,
  });

  /// アーカイブされたコレクションを取得
  Future<Result<List<MediaCollection>, AppError>> getArchivedCollections({
    CollectionType? type,
    bool? isHidden,
  });

  /// アーカイブされたコレクションを監視
  Stream<List<MediaCollection>> watchArchivedCollections({
    CollectionType? type,
    bool? isHidden,
  });

  /// 非表示にされたコレクションを取得
  Future<Result<List<MediaCollection>, AppError>> getHiddenCollections({
    CollectionType? type,
    bool? isArchived,
  });

  /// 非表示にされたコレクションを監視
  Stream<List<MediaCollection>> watchHiddenCollections({
    CollectionType? type,
    bool? isArchived,
  });

  /// 非表示にされたアイテムを監視
  Stream<List<MediaItem>> watchHiddenItems({bool? isArchived});

  /// 最近閲覧したコレクションを取得（lastViewedAt降順）
  Future<Result<List<MediaCollection>, AppError>> getRecentlyViewedCollections({
    int limit = 10,
    bool? isExternal,
    bool? isHidden,
  });

  /// 最近閲覧したコレクションを監視
  Stream<List<MediaCollection>> watchRecentlyViewedCollections({
    int limit = 10,
    bool? isExternal,
    bool? isHidden,
  });

  /// コレクションを保存
  Future<Result<void, AppError>> saveCollection(MediaCollection collection);

  /// 登録解除とタグの使用回数・関連解除を同じトランザクションで保存する。
  /// ファイル、メモ、表示名、お気に入りは保持し、確定した状態を返す。
  Future<Result<MediaCollection?, AppError>> decatalogifyCollection(int id);

  /// ビューワーの最終閲覧位置だけを単一トランザクションで更新する。
  Future<Result<bool, AppError>> updateCollectionLastViewed(
    String path, {
    required int itemId,
    required DateTime viewedAt,
  });

  /// コレクション上のタグ付けをトグル（使用回数更新を含む）
  Future<Result<void, AppError>> toggleTagOnCollection(
    MediaCollection collection,
    Tag tag,
  );

  /// コレクションのタグを指定されたタグ一覧に同期（差分の usageCount 更新を含む一括処理）
  Future<Result<void, AppError>> syncTagsOnCollection(
    MediaCollection collection,
    List<Tag> targetTags,
  );

  /// UIDでコレクション取得
  Future<Result<MediaCollection?, AppError>> getCollectionByUid(String uid);

  /// パスでコレクションを取得
  Future<Result<MediaCollection?, AppError>> getCollectionByPath(
    String path, {
    bool includeTrashed = true,
  });

  /// 外部参照コレクション一覧を取得
  Future<Result<List<MediaCollection>, AppError>> getExternalCollections({
    MediaFilter? filter,
  });

  /// コレクションを削除
  Future<Result<void, AppError>> deleteCollection(int id);

  /// StorageRef を保存
  Future<Result<void, AppError>> saveStorageRef(StorageRef ref);

  /// UIDでStorageRef取得
  Future<Result<StorageRef?, AppError>> getStorageRefByUid(String uid);

  /// 所有者に紐づくStorageRef取得
  Future<Result<List<StorageRef>, AppError>> getStorageRefsByOwner(
    String ownerUid,
    StorageOwnerType ownerType,
  );

  /// StorageRef を削除
  Future<Result<void, AppError>> deleteStorageRef(int id);

  /// 移動したディレクトリ配下のアイテムのパスを再帰的に更新
  Future<Result<void, AppError>> updatePathsForMovedDirectory(
    String oldPath,
    String newPath,
  );

  /// カバー画像として使用されているコレクションの画像パスを更新
  Future<Result<void, AppError>> updateCoverImagePath(
    String oldPath,
    String newPath,
  );

  /// 指定されたパス配下の全てのコレクションを取得 (再帰的)
  Future<Result<List<MediaCollection>, AppError>> getDescendantCollections(
    String path,
  );

  /// 指定されたパス配下の全てのアイテムを取得 (再帰的)
  Future<Result<List<MediaItem>, AppError>> getDescendants(String path);

  /// 動画の指定位置でサムネイルを更新
  Future<Result<void, AppError>> updateThumbnail(int id, int positionMs);

  /// カタログ情報ヘッダーの展開状態を更新
  Future<Result<void, AppError>> updateCollectionHeaderExpanded(
    int id,
    bool expanded,
  );

  /// IDでコレクションを取得
  Future<Result<MediaCollection?, AppError>> getCollectionById(int id);

  /// フォルダ直下のサマリー情報（件数・代表画像）を高速に取得
  Future<Result<FolderSummary, AppError>> getFolderSummary(
    String folderPath, {
    bool? isHidden,
  });

  /// 条件に一致するアイテムが1件以上存在するか確認
  Future<Result<bool, AppError>> hasAnyItems({
    MediaSourceType? sourceType,
    bool? isArchived,
    bool? isHidden,
  });

  /// アイテム存在状況を監視
  Stream<bool> watchHasAnyItems({
    MediaSourceType? sourceType,
    bool? isArchived,
    bool? isHidden,
  });
}
