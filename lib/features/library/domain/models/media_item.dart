import 'package:isar/isar.dart' hide Collection;

import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_format_utils.dart';

part 'media_item.g.dart';

@collection
class MediaItem {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  String? uid;

  /// アプリ内ストレージの相対パス (例: `folders/abc/image.jpg`)
  @Index(type: IndexType.value)
  String path = '';

  /// インポート元の絶対パス（バックアップ/復元、再リンク用）
  String originalPath = '';

  /// データソース種別
  @enumerated
  MediaSourceType sourceType = MediaSourceType.localCopy;

  /// 追加日
  @Index()
  DateTime addedAt = DateTime(2000);

  /// 更新日
  DateTime updatedAt = DateTime(2000);

  /// ファイルサイズ (bytes)
  int? size;

  /// 種別 (file / folder)
  @enumerated
  MediaType type = MediaType.file;

  /// サムネイルのパス（アプリ内相対パス）
  String? thumbnailPath;

  /// 親フォルダのパス（階層構造用）。ルートの場合は null または空文字
  @Index()
  String? parentPath;

  /// 所属するカタログ（バックリンク）
  @Backlink(to: 'items')
  final collection = IsarLink<MediaCollection>();

  /// ファイルが見つからない（参照切れ）状態か
  @Index()
  bool isMissing = false;

  /// 最後にファイル存在確認を行った日時
  DateTime? missingCheckedAt;

  /// アーカイブされたかどうか
  @Index()
  bool isArchived = false;

  /// 非表示にされたかどうか
  @Index()
  bool isHidden = false;

  /// お気に入りに登録されているかどうか
  @Index()
  bool isFavorite = false;

  /// ごみ箱に移動された論理削除状態。
  @Index()
  bool isTrashed = false;

  /// ごみ箱一覧に表示する削除操作のルート項目。
  @Index()
  bool isTrashRoot = false;

  /// ごみ箱へ移動した日時。
  DateTime? trashedAt;

  /// 内部実体の退避先。ルート項目にのみ設定する。
  String? trashPath;

  /// 同じ削除操作に属するグラフを識別するルートパス。
  @Index()
  String? trashRootPath;

  /// Transient import preview; never persisted in the library.
  @ignore
  bool isImportPreview = false;

  @ignore
  bool get requiresSourceAccess =>
      isImportPreview || sourceType == MediaSourceType.externalReference;

  @ignore
  String? mimeType;

  @ignore
  bool get isImage => MediaFormatUtils.isImage(
    path,
    mimeType: mimeType,
    originalPath: originalPath,
  );

  @ignore
  bool get isVideo => MediaFormatUtils.isVideo(
    path,
    mimeType: mimeType,
    originalPath: originalPath,
  );

  @ignore
  bool get isAudio => MediaFormatUtils.isAudio(
    path,
    mimeType: mimeType,
    originalPath: originalPath,
  );

  @ignore
  bool get isDocument => MediaFormatUtils.isDocument(
    path,
    mimeType: mimeType,
    originalPath: originalPath,
  );

  @ignore
  bool get isText => MediaFormatUtils.isText(
    path,
    mimeType: mimeType,
    originalPath: originalPath,
  );

  @ignore
  bool get isMarkdown =>
      MediaFormatUtils.isMarkdown(path, originalPath: originalPath);

  @ignore
  bool get isPdf => MediaFormatUtils.isPdf(
    path,
    mimeType: mimeType,
    originalPath: originalPath,
  );

  @ignore
  bool get isArchive =>
      MediaFormatUtils.isArchive(path, originalPath: originalPath);

  @ignore
  bool get isSvg => MediaFormatUtils.isSvg(
    path,
    mimeType: mimeType,
    originalPath: originalPath,
  );

  @ignore
  bool get isRawOrTiff => MediaFormatUtils.isRawOrTiff(
    path,
    mimeType: mimeType,
    originalPath: originalPath,
  );

  @ignore
  bool get isDirectlyViewableImage => MediaFormatUtils.isDirectlyViewableImage(
    path,
    mimeType: mimeType,
    originalPath: originalPath,
  );

  @ignore
  bool get isViewableInApp => MediaFormatUtils.isViewableInApp(
    path,
    mimeType: mimeType,
    originalPath: originalPath,
  );
}

enum MediaType { file, folder }

enum MediaSourceType {
  localCopy, // アプリ内コピー
  externalReference, // 外部参照 (SAF/Scoped Storage)
}

enum MediaTier {
  s(5),
  a(4),
  b(3),
  c(2),
  d(1),
  none(0);

  final int value;

  const MediaTier(this.value);

  static MediaTier fromInt(int value) {
    return MediaTier.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MediaTier.none,
    );
  }
}
