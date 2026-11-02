/// ディレクトリ構造をスキャンした際の一つのノード（フォルダまたはファイル）を表すクラス。
class FileTreeNode {
  /// ファイルシステム上の名前
  final String name;

  /// URI (Android SAF URI または iOS file URI)
  final Uri uri;

  /// Persisted SAF grant for selections made in the in-app browser.
  final Uri? sourceTreeUri;

  /// Read grant for a file picked with ACTION_OPEN_DOCUMENT, not a tree grant.
  final Uri? sourceDocumentUri;
  final String? sourceIdentity;

  /// ルートからの相対パス
  final String relativePath;

  /// フォルダかどうか
  final bool isDirectory;

  /// 子ノード
  final List<FileTreeNode> children;

  /// インポート対象に含めるかどうか
  bool includeInImport;

  /// カタログとして登録するかどうか
  bool isCatalog;

  /// 画面上の展開状態
  bool isExpanded;

  /// メディアファイルとして認識可能か（ディレクトリの場合は配下にメディアがあるか）
  final bool isMedia;
  final int? size;
  final String? mimeType;

  FileTreeNode({
    required this.name,
    required this.uri,
    this.sourceTreeUri,
    this.sourceDocumentUri,
    this.sourceIdentity,
    required this.relativePath,
    required this.isDirectory,
    List<FileTreeNode>? children,
    this.includeInImport = true,
    this.isCatalog = false,
    this.isExpanded = false,
    this.isMedia = false,
    this.size,
    this.mimeType,
  }) : children = children ?? [];

  /// コピーを作成する（State管理用）
  FileTreeNode copyWith({
    bool? includeInImport,
    bool? isCatalog,
    bool? isExpanded,
    List<FileTreeNode>? children,
  }) {
    return FileTreeNode(
      name: name,
      uri: uri,
      sourceTreeUri: sourceTreeUri,
      sourceDocumentUri: sourceDocumentUri,
      sourceIdentity: sourceIdentity,
      relativePath: relativePath,
      isDirectory: isDirectory,
      children: children ?? this.children,
      includeInImport: includeInImport ?? this.includeInImport,
      isCatalog: isCatalog ?? this.isCatalog,
      isExpanded: isExpanded ?? this.isExpanded,
      isMedia: isMedia,
      size: size,
      mimeType: mimeType,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      if (sourceIdentity != null) 'sourceIdentity': sourceIdentity,
      'uri': uri.toString(),
      if (sourceTreeUri != null) 'sourceTreeUri': '$sourceTreeUri',
      if (sourceDocumentUri != null) 'sourceDocumentUri': '$sourceDocumentUri',
      'relativePath': relativePath,
      'isDirectory': isDirectory,
      'children': children.map((child) => child.toMap()).toList(),
      'includeInImport': includeInImport,
      'isCatalog': isCatalog,
      'isExpanded': isExpanded,
      'isMedia': isMedia,
      'size': size,
      'mimeType': mimeType,
    };
  }

  factory FileTreeNode.fromMap(Map<String, dynamic> map) {
    return FileTreeNode(
      name: (map['name'] as String?) ?? '',
      sourceIdentity: map['sourceIdentity'] as String?,
      sourceTreeUri: map['sourceTreeUri'] is String
          ? Uri.parse(map['sourceTreeUri'] as String)
          : null,
      sourceDocumentUri: map['sourceDocumentUri'] is String
          ? Uri.parse(map['sourceDocumentUri'] as String)
          : null,
      uri:
          Uri.tryParse((map['uri'] as String?) ?? '') ??
          Uri.parse('about:blank'),
      relativePath: (map['relativePath'] as String?) ?? '',
      isDirectory: map['isDirectory'] == true,
      children: (map['children'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FileTreeNode.fromMap)
          .toList(growable: false),
      includeInImport: map['includeInImport'] != false,
      isCatalog: map['isCatalog'] == true,
      isExpanded: map['isExpanded'] == true,
      isMedia: map['isMedia'] == true,
      size: (map['size'] as num?)?.toInt(),
      mimeType: map['mimeType'] as String?,
    );
  }
}
