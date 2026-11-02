import 'package:isar/isar.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';

part 'collection.g.dart';

@collection
class MediaCollection {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  String? uid;

  /// カタログタイトル（フォルダ名 or ファイル名。エイリアスがある場合はそちらを優先表示）
  @Index(type: IndexType.value)
  String title = '';

  /// カタログの別名（リネーム用）。nullの場合は title を使用する。
  String? alias;

  /// 参照パス (フォルダパス or ファイルパス/URI)
  @Index(unique: true, replace: true)
  String path = '';

  /// カタログ種別 (folder / file)
  @enumerated
  CollectionType type = CollectionType.folder;

  /// カタログとして登録済みかどうか。保存場所やファイル形式とは独立する。
  bool isCatalog = false;

  /// 作成日時
  DateTime createdAt = DateTime(2000);

  /// 更新日時
  DateTime updatedAt = DateTime(2000);

  /// 含まれるメディア項目
  final items = IsarLinks<MediaItem>();

  /// 表紙画像のパス（アプリ内相対キャッシュパス）
  String? coverImagePath;

  /// お気に入りフラグ
  @Index()
  bool isFavorite = false;

  /// メモ
  String? notes;

  /// 最後に閲覧した日時
  @Index()
  DateTime? lastViewedAt;

  /// 最後に閲覧したメディア項目のID
  int? lastViewedItemId;

  /// ホームへのピン留め
  @Index()
  bool isPinned = false;

  /// アーカイブされたかどうか
  @Index()
  bool isArchived = false;

  /// 非表示にされたかどうか
  @Index()
  bool isHidden = false;

  /// 対応するファイルグラフがごみ箱にあるか。
  @Index()
  bool isTrashed = false;

  /// 同じ削除操作に属するグラフを識別するルートパス。
  @Index()
  String? trashRootPath;

  /// デフォルトのソート順
  @enumerated
  SortOrder defaultSortOrder = SortOrder.addedDesc;

  /// デフォルトの表示モード
  @enumerated
  ViewMode defaultViewMode = ViewMode.list;

  bool splitSpreadView = false;

  /// カタログ情報ヘッダーの展開状態
  bool isHeaderExpanded = true;

  /// カタログのティア (0-5: none/D/C/B/A/S)
  int tier = 0;

  /// タグとのリレーション
  final tags = IsarLinks<Tag>();

  /// ホームのお気に入り一覧で、カタログ化されていない項目を表すための表示用参照。
  @ignore
  MediaItem? favoriteItem;

  /// ティア変更用ヘルパー
  @ignore
  MediaTier get mediaTier => MediaTier.fromInt(tier);

  /// 外部フォルダかどうか
  @ignore
  bool get isExternal => type == CollectionType.externalFolder;
}

enum CollectionType {
  folder, // フォルダをカタログとする
  file, // 単一ファイルをカタログとする
  externalFolder, // 外部参照フォルダ（SAF URI）
}
