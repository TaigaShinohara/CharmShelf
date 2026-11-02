import 'dart:collection';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:uuid/uuid.dart';
import '../../../core/services/import_safety_policy.dart';
import '../../library/domain/models/file_tree.dart';
import '../domain/device_file.dart';

final deviceStorageProvider = Provider((ref) => DeviceStorage());

class DeviceScanCancelled implements Exception {}

class DeviceListing {
  const DeviceListing(this.entries, {this.skipped = 0});
  final List<DeviceFile> entries;
  final int skipped;
}

class DeviceStorage {
  static const channel = MethodChannel(
    'com.tsmusic.privateshelf/device_storage',
  );
  final _requests = <String>{};
  int _generation = 0;
  Future<T?> _call<T>(
    String method, [
    Map<String, dynamic> args = const {},
  ]) async {
    final id = const Uuid().v4();
    _requests.add(id);
    try {
      return await channel.invokeMethod<T>(method, {...args, 'requestId': id});
    } finally {
      _requests.remove(id);
    }
  }

  Future<bool> allowed() async =>
      (await _call<Map<dynamic, dynamic>>('status'))?['allowed'] == true;
  Future<void> requestPermission() async {
    final status = await _call<Map<dynamic, dynamic>>('status');
    if ((status?['sdk'] as int? ?? 30) >= 30) {
      await ph.Permission.manageExternalStorage.request();
    } else {
      await ph.Permission.storage.request();
    }
  }

  Future<bool> legacyEmpty() async => await _call<bool>('legacyEmpty') == true;
  Future<List<DeviceFile>> roots() async =>
      (await _call<List<dynamic>>('roots') ?? [])
          .map((e) => DeviceFile.fromMap(e as Map))
          .toList();
  Future<DeviceFile> stat(Uri uri) async => DeviceFile.fromMap(
    (await _call<Map<dynamic, dynamic>>('stat', {'uri': '$uri'}))!,
  );
  Future<DeviceListing> children(Uri uri) async {
    final result = (await _call<Map<dynamic, dynamic>>('children', {
      'uri': '$uri',
    }))!;
    final entries = (result['entries'] as List)
        .map((e) => DeviceFile.fromMap(e as Map))
        .toList();
    entries.sort((a, b) {
      if (a.directory != b.directory) return a.directory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return DeviceListing(entries, skipped: result['skipped'] as int);
  }

  Future<void> validate(List<DeviceFile> entries) async {
    for (var start = 0; start < entries.length; start += 200) {
      final batch = entries.skip(start).take(200).toList();
      final valid = await _call<bool>('validate', {
        'entries': [
          for (final e in batch) {'uri': '${e.uri}', 'id': e.identity},
        ],
      });
      if (valid != true) throw StateError('Source has changed');
    }
  }

  Future<void> cancel() async {
    _generation++;
    await Future.wait(
      _requests.toList().map(
        (id) => channel.invokeMethod<void>('cancel', {'requestId': id}),
      ),
    );
  }

  /// Complete snapshots only. A failed folder never silently removes old results.
  Future<DeviceListing> scan(
    List<DeviceFile> roots, {
    Set<String> excluded = const {},
    void Function(int count)? onProgress,
  }) async {
    final generation = _generation;
    final queue = Queue<(DeviceFile, int)>.from(roots.map((e) => (e, 0)));
    final visited = <String>{};
    final result = <DeviceFile>[];
    var skipped = 0;
    void check() {
      if (generation != _generation) throw DeviceScanCancelled();
    }

    while (queue.isNotEmpty) {
      check();
      final (folder, depth) = queue.removeFirst();
      if (excluded.any(
        (e) => '${folder.uri}' == e || '${folder.uri}'.startsWith('$e/'),
      )) {
        continue;
      }
      if (!visited.add('${folder.uri}')) throw StateError('Directory cycle');
      if (depth > ImportSafetyPolicy.maxRelativePathDepth) {
        throw StateError('Directory depth limit');
      }
      final listing = await children(folder.uri);
      check();
      skipped += listing.skipped;
      for (final entry in listing.entries) {
        if (excluded.any(
          (e) => '${entry.uri}' == e || '${entry.uri}'.startsWith('$e/'),
        )) {
          continue;
        }
        result.add(entry);
        if (result.length > ImportSafetyPolicy.maxScannedEntryCount) {
          throw StateError('Index entry limit');
        }
        if (entry.directory) queue.add((entry, depth + 1));
      }
      onProgress?.call(result.length);
      // Give cancellation and painting a turn even with fast fake/local listings.
      await Future<void>.delayed(Duration.zero);
    }
    check();
    return DeviceListing(result, skipped: skipped);
  }

  Future<FileTreeNode> selection(
    DeviceFile root,
    List<DeviceFile> selected,
  ) async {
    final generation = _generation;
    var count = 0;
    final paths = selected
        .where(
          (e) => !selected.any(
            (parent) =>
                parent.directory &&
                parent.uri != e.uri &&
                e.uri.toFilePath().startsWith('${parent.uri.toFilePath()}/'),
          ),
        )
        .toList();
    Future<FileTreeNode> node(DeviceFile e, String relative, int depth) async {
      if (generation != _generation) throw DeviceScanCancelled();
      if (++count > ImportSafetyPolicy.maxScannedEntryCount ||
          depth > ImportSafetyPolicy.maxRelativePathDepth) {
        throw StateError('Selection limit');
      }
      await validate([e]);
      final childrenNodes = <FileTreeNode>[];
      if (e.directory) {
        final listing = await children(e.uri);
        if (listing.skipped != 0) {
          throw StateError('Selection contains unreadable entries');
        }
        for (final child in listing.entries) {
          childrenNodes.add(
            await node(child, '$relative/${child.name}', depth + 1),
          );
        }
      }
      if (generation != _generation) throw DeviceScanCancelled();
      return FileTreeNode(
        name: e.name,
        uri: e.uri,
        sourceTreeUri: root.uri,
        sourceIdentity: e.identity,
        relativePath: relative,
        isDirectory: e.directory,
        isMedia: e.directory
            ? childrenNodes.any((c) => c.isMedia)
            : e.supported,
        size: e.size,
        isCatalog: e.directory,
        children: childrenNodes,
      );
    }

    final nodes = <FileTreeNode>[];
    for (final e in paths) {
      // Keep distinct relative paths for same-name files in different directories.
      final relative = e.uri
          .toFilePath()
          .substring(root.uri.toFilePath().length)
          .replaceFirst(RegExp(r'^/'), '');
      nodes.add(await node(e, relative.isEmpty ? e.name : relative, 0));
    }
    return FileTreeNode(
      name: root.name,
      uri: Uri.parse('private-shelf://source-selection'),
      sourceTreeUri: root.uri,
      relativePath: '',
      isDirectory: true,
      isMedia: nodes.any((e) => e.isMedia),
      children: nodes,
      isExpanded: true,
    );
  }
}
