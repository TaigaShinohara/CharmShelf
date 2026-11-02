import 'media_item.dart';

/// Read-only source selected for inspection before copying into the library.
class ImportPreviewSource {
  const ImportPreviewSource({
    required this.uri,
    required this.name,
    this.size,
    this.mimeType,
  });
  final Uri uri;
  final String name;
  final int? size;
  final String? mimeType;

  MediaItem toViewerItem() => MediaItem()
    ..id = -DateTime.now().microsecondsSinceEpoch
    ..path = uri.toString()
    ..originalPath = name
    ..isImportPreview = true
    ..size = size
    ..mimeType = mimeType;
}
