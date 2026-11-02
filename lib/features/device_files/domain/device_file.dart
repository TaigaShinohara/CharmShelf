import 'package:path/path.dart' as p;
import '../../library/domain/models/media_format_utils.dart';

class DeviceFile {
  const DeviceFile({
    required this.uri,
    required this.identity,
    required this.name,
    required this.directory,
    this.size,
    this.modified = 0,
  });
  final Uri uri;
  final String identity, name;
  final bool directory;
  final int? size;
  final int modified;
  String get key => '$uri\n$identity';
  bool get supported =>
      !directory &&
      !MediaFormatUtils.isIgnoredFile(name) &&
      MediaFormatUtils.allSupportedExtensions.contains(
        p.extension(name).toLowerCase(),
      );
  String get extension => p.extension(name).toLowerCase();
  Map<String, dynamic> toMap() => {
    'uri': '$uri',
    'id': identity,
    'name': name,
    'directory': directory,
    'size': size,
    'modified': modified,
  };
  factory DeviceFile.fromMap(Map<dynamic, dynamic> map) {
    final uri = Uri.parse(map['uri'] as String);
    if (uri.scheme != 'file' || uri.authority.isNotEmpty) {
      throw const FormatException('Invalid device path');
    }
    return DeviceFile(
      uri: uri,
      identity: map['id'] as String,
      name: map['name'] as String,
      directory: map['directory'] == true,
      size: (map['size'] as num?)?.toInt(),
      modified: (map['modified'] as num?)?.toInt() ?? 0,
    );
  }
}

class DeviceFileLabels {
  const DeviceFileLabels({
    this.tags = const [],
    this.catalog = '',
    this.favorite = false,
  });
  final List<String> tags;
  final String catalog;
  final bool favorite;
  Map<String, dynamic> toMap() => {
    'tags': tags,
    'catalog': catalog,
    'favorite': favorite,
  };
  factory DeviceFileLabels.fromMap(Map<dynamic, dynamic> map) =>
      DeviceFileLabels(
        tags: List<String>.from(map['tags'] as List),
        catalog: map['catalog'] as String,
        favorite: map['favorite'] == true,
      );
}
