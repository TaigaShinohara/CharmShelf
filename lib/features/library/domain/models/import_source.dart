import 'package:path/path.dart' as p;
import 'media_format_utils.dart';

class ImportSource {
  const ImportSource({
    required this.id,
    required this.name,
    required this.treeUri,
  });
  final String id;
  final String name;
  final Uri treeUri;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'treeUri': '$treeUri',
  };
  factory ImportSource.fromMap(Map<String, dynamic> map) {
    final uri = Uri.parse(map['treeUri'] as String);
    if (uri.scheme != 'content' || !uri.pathSegments.contains('tree')) {
      throw const FormatException('Invalid import source');
    }
    return ImportSource(
      id: map['id'] as String,
      name: map['name'] as String,
      treeUri: uri,
    );
  }
}

/// Identity comes from the provider, never from a display name or local path.
class ImportSourceEntry {
  const ImportSourceEntry({
    required this.id,
    required this.uri,
    required this.name,
    required this.isDirectory,
    this.size,
    this.mimeType,
    this.path = '',
  });
  final String id;
  final Uri uri;
  final String name;
  final bool isDirectory;
  final int? size;
  final String? mimeType;
  final String path;
  bool get supported =>
      !MediaFormatUtils.isIgnoredFile(name) &&
      MediaFormatUtils.allSupportedExtensions.contains(
        p.extension(name).toLowerCase(),
      );

  factory ImportSourceEntry.fromMap(
    Map<dynamic, dynamic> map, {
    String parent = '',
  }) => ImportSourceEntry(
    id: map['id'] as String,
    uri: Uri.parse(map['uri'] as String),
    name: map['name'] as String,
    isDirectory: map['directory'] == true,
    size: (map['size'] as num?)?.toInt(),
    mimeType: map['mimeType'] as String?,
    path: p.posix.join(parent, map['name'] as String),
  );
}

/// Conservative grant ownership: document IDs are opaque, not filesystem paths.
bool sharesImportGrant(Uri grant, Uri reference) {
  if (grant == reference) return true;
  if (grant.scheme != 'content' ||
      reference.scheme != 'content' ||
      grant.authority != reference.authority) {
    return false;
  }
  String? treeId(Uri uri) {
    final parts = uri.pathSegments;
    final index = parts.indexOf('tree');
    return index >= 0 && index + 1 < parts.length ? parts[index + 1] : null;
  }

  final a = treeId(grant), b = treeId(reference);
  // Unknown/non-tree references can rely on this grant. Preserve it.
  return a == null || b == null || a == b;
}
