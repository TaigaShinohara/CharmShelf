/// 端末内に存在する復元可能なデータの概要を表すイミュータブルモデル
class RestorableDataSummary {
  const RestorableDataSummary({
    required this.hasRestorableData,
    required this.hasMetadataFile,
    required this.tagCount,
    required this.collectionCount,
    required this.mediaItemCount,
    required this.folderCount,
    required this.storagePath,
    this.lastExportedAt,
  });

  /// 復元対象のデータが存在するかどうか
  final bool hasRestorableData;

  /// メタデータファイル（.tagshelf/metadata.json）が存在するか
  final bool hasMetadataFile;

  /// メタデータに含まれるタグ数
  final int tagCount;

  /// メタデータまたはストレージ内のコレクション（フォルダ）数
  final int collectionCount;

  /// メタデータまたはストレージ内のメディアファイル数
  final int mediaItemCount;

  /// ストレージ内で検出されたフォルダ数
  final int folderCount;

  /// データが検出されたストレージのパス
  final String storagePath;

  /// メタデータのエクスポート日時（存在する場合）
  final DateTime? lastExportedAt;

  /// メディア、タグ、コレクションの合計件数
  int get totalItemCount => tagCount + collectionCount + mediaItemCount;

  /// メディア、タグ、コレクションのいずれかが1件以上存在するかどうか
  bool get hasAnyItems => totalItemCount > 0;

  static const empty = RestorableDataSummary(
    hasRestorableData: false,
    hasMetadataFile: false,
    tagCount: 0,
    collectionCount: 0,
    mediaItemCount: 0,
    folderCount: 0,
    storagePath: '',
  );
}
