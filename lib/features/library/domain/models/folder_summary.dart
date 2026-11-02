/// フォルダの特性タイプ
enum FolderContentType {
  empty, // 空フォルダ
  deepDirectory, // サブフォルダを持つ階層フォルダ
  imageMedia, // 画像を含むフォルダ
  videoMedia, // 動画を含むフォルダ
  mixedMedia, // 複数種別のメディアを含むフォルダ
  documents, // ドキュメント・テキストを含むフォルダ
  standard, // 一般フォルダ
}

/// フォルダの内包アイテム情報を表すクラス
class FolderSummary {
  final int folderCount;
  final int catalogCount;
  final int fileCount;
  final int totalCount;
  final int imageCount;
  final int videoCount;
  final int documentCount;
  final String? firstThumbnailPath;
  final String? firstImagePath;

  const FolderSummary({
    this.folderCount = 0,
    this.catalogCount = 0,
    this.fileCount = 0,
    this.totalCount = 0,
    this.imageCount = 0,
    this.videoCount = 0,
    this.documentCount = 0,
    this.firstThumbnailPath,
    this.firstImagePath,
  });

  bool get isEmpty => totalCount == 0;
  bool get hasSubfolders => folderCount > 0;
  bool get hasImages => imageCount > 0;
  bool get hasVideos => videoCount > 0;

  FolderContentType get contentType {
    if (isEmpty) return FolderContentType.empty;
    if (hasSubfolders) return FolderContentType.deepDirectory;
    if (imageCount > 0 && videoCount > 0) return FolderContentType.mixedMedia;
    if (imageCount > 0) return FolderContentType.imageMedia;
    if (videoCount > 0) return FolderContentType.videoMedia;
    if (documentCount > 0) return FolderContentType.documents;
    return FolderContentType.standard;
  }
}
