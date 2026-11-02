// audit: allow-file-io
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/device_file.dart';

final deviceFileRepositoryProvider = FutureProvider<DeviceFileRepository>((
  ref,
) async {
  final directory = await getApplicationSupportDirectory();
  final repository = DeviceFileRepository(
    File('${directory.path}/device_files_v1.json'),
  );
  await repository.load();
  return repository;
});

/// Atomic snapshots, serialized writes. Paths are app-owned; originals are never written.
class DeviceFileRepository {
  DeviceFileRepository(this.file);
  final File file;
  Future<void> _writes = Future.value();
  Map<String, dynamic> _data = _empty();
  List<DeviceFile> _entries = const [];
  Map<String, DeviceFileLabels> _labels = const {};
  void _hydrate(Map<String, dynamic> value) {
    final entries = List<DeviceFile>.unmodifiable(
      (value['entries'] as List).map((e) => DeviceFile.fromMap(e as Map)),
    );
    final labels = <String, DeviceFileLabels>{
      for (final e in (value['labels'] as Map).entries)
        e.key as String: DeviceFileLabels.fromMap(e.value as Map),
    };
    _data = value;
    _entries = entries;
    _labels = labels;
  }

  static Map<String, dynamic> _empty() => {
    'version': 1,
    'entries': <dynamic>[],
    'labels': <String, dynamic>{},
    'excluded': <String>[],
    'indexedAt': null,
    'skipped': 0,
  };
  Future<void> load() async {
    if (!await file.exists()) return;
    final value = await compute(_decodeSnapshot, await file.readAsString());
    if (value['version'] != 1 ||
        value['entries'] is! List ||
        value['labels'] is! Map ||
        value['excluded'] is! List) {
      throw const FormatException('Invalid device file index');
    }
    // Validate before replacing memory. Corruption must not become an empty library.
    for (final e in value['entries'] as List) {
      DeviceFile.fromMap(e as Map);
    }
    for (final e in (value['labels'] as Map).values) {
      DeviceFileLabels.fromMap(e as Map);
    }
    List<String>.from(value['excluded'] as List);
    _hydrate(value);
  }

  bool hasSavedLabels(Uri uri) =>
      _labels.keys.any((key) => key.startsWith('$uri\n'));
  List<DeviceFile> get entries => _entries;
  Set<String> get excluded => Set<String>.from(_data['excluded'] as List);
  DateTime? get indexedAt =>
      DateTime.tryParse(_data['indexedAt'] as String? ?? '');
  int get skipped => (_data['skipped'] as num?)?.toInt() ?? 0;
  DeviceFileLabels labels(DeviceFile entry) =>
      _labels[entry.key] ?? const DeviceFileLabels();
  DeviceFileLabels? previousLabels(DeviceFile entry) {
    final matches = (_data['labels'] as Map).entries
        .where(
          (e) =>
              (e.key as String).startsWith('${entry.uri}\n') &&
              e.key != entry.key,
        )
        .toList();
    return matches.isEmpty
        ? null
        : DeviceFileLabels.fromMap(matches.last.value as Map);
  }

  Future<void> _update(void Function(Map<String, dynamic>) change) {
    final next = _writes.then((_) async {
      final data = <String, dynamic>{
        ..._data,
        'entries': List<dynamic>.of(_data['entries'] as List),
        'labels': Map<String, dynamic>.from(_data['labels'] as Map),
        'excluded': List<String>.from(_data['excluded'] as List),
      };
      change(data);
      final staged = File('${file.path}.pending');
      await file.parent.create(recursive: true);
      await staged.writeAsString(
        await compute(_encodeSnapshot, data),
        flush: true,
      );
      await staged.rename(file.path);
      _hydrate(data);
    });
    _writes = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> saveLabels(DeviceFile entry, DeviceFileLabels labels) =>
      _update((data) {
        (data['labels'] as Map).removeWhere(
          (key, _) => (key as String).startsWith('${entry.uri}\n'),
        );
        (data['labels'] as Map)[entry.key] = labels.toMap();
        final records = data['entries'] as List;
        records.removeWhere((e) => (e as Map)['uri'] == '${entry.uri}');
        final excluded = (data['excluded'] as List).cast<String>();
        if (!excluded.any(
          (path) =>
              '${entry.uri}' == path || '${entry.uri}'.startsWith('$path/'),
        )) {
          records.add(entry.toMap());
        }
      });
  Future<void> replaceIndex(List<DeviceFile> entries, int skipped) =>
      _update((data) {
        data['entries'] = entries.map((e) => e.toMap()).toList();
        data['indexedAt'] = DateTime.now().toUtc().toIso8601String();
        data['skipped'] = skipped;
      });
  Future<void> setExcluded(Set<String> excluded) => _update((data) {
    data['excluded'] = excluded.toList();
    // An excluded location also disappears from the saved searchable snapshot.
    (data['entries'] as List).removeWhere((e) {
      final uri = (e as Map)['uri'] as String;
      return excluded.any((x) => uri == x || uri.startsWith('$x/'));
    });
  });
  Future<void> clear() => _update((data) {
    data
      ..clear()
      ..addAll(_empty());
  });
}

String _encodeSnapshot(Map<String, dynamic> value) => jsonEncode(value);
Map<String, dynamic> _decodeSnapshot(String value) =>
    jsonDecode(value) as Map<String, dynamic>;
