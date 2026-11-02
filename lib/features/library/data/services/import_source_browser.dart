import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/import_safety_policy.dart';
import '../../domain/models/import_source.dart';
import '../../domain/models/file_tree.dart';

final importSourceBrowserProvider = Provider((ref) => ImportSourceBrowser());

class ImportSourceBrowser {
  static const channel = MethodChannel(
    'com.tsmusic.privateshelf/import_sources',
  );
  final Set<String> _requests = {};
  int _generation = 0;

  Future<T?> _call<T>(String method, Map<String, dynamic> args) async {
    final id = const Uuid().v4();
    _requests.add(id);
    try {
      return await channel.invokeMethod<T>(method, {...args, 'requestId': id});
    } finally {
      _requests.remove(id);
    }
  }

  Future<ImportSourceEntry> root(Uri tree) async {
    final value = await _call<Map<dynamic, dynamic>>('root', {'treeUri': '$tree'});
    if (value == null) throw StateError('Missing source root');
    final entry = ImportSourceEntry.fromMap(value);
    return ImportSourceEntry(
      id: entry.id,
      uri: entry.uri,
      name: entry.name,
      isDirectory: true,
    );
  }

  Future<List<ImportSourceEntry>> children(
    ImportSource source,
    ImportSourceEntry directory,
  ) async {
    final values = await _call<List<dynamic>>('children', {
      'treeUri': '${source.treeUri}',
      'directoryUri': '${directory.uri}',
    });
    if (values == null) throw StateError('Missing source listing');
    final entries = values
        .map((e) => ImportSourceEntry.fromMap(e as Map, parent: directory.path))
        .toList();
    if (entries.map((e) => e.name).toSet().length != entries.length) {
      throw StateError('Ambiguous duplicate document names');
    }
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      final order = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    return entries;
  }

  Future<void> cancel() async {
    _generation++;
    await Future.wait(
      _requests.toList().map(
        (id) => channel.invokeMethod<void>('cancel', {'requestId': id}),
      ),
    );
  }

  /// Scan only explicitly selected subtrees. A failed listing aborts confirmation.
  Future<FileTreeNode> selection(
    ImportSource source,
    List<ImportSourceEntry> selected,
  ) async {
    final generation = _generation;
    void check() {
      if (generation != _generation) throw StateError('Selection cancelled');
    }

    var count = 0;
    final visited = <String>{};
    Future<FileTreeNode> scan(ImportSourceEntry entry, int depth) async {
      check();
      if (++count > ImportSafetyPolicy.maxScannedEntryCount ||
          depth > ImportSafetyPolicy.maxRelativePathDepth ||
          !visited.add('${entry.uri}')) {
        throw StateError('Source exceeds browsing limits or contains a cycle');
      }
      final nodes = <FileTreeNode>[];
      if (entry.isDirectory) {
        for (final child in await children(source, entry)) {
          nodes.add(await scan(child, depth + 1));
        }
      }
      check();
      return FileTreeNode(
        name: entry.name,
        uri: entry.uri,
        relativePath: entry.path,
        isDirectory: entry.isDirectory,
        size: entry.size,
        mimeType: entry.mimeType,
        isMedia: entry.isDirectory
            ? nodes.any((e) => e.isMedia)
            : entry.supported,
        isCatalog: entry.isDirectory,
        children: nodes,
        sourceTreeUri: source.treeUri,
      );
    }

    final roots = selected
        .where(
          (entry) => !selected.any(
            (parent) =>
                parent.id != entry.id &&
                parent.isDirectory &&
                (parent.path.isEmpty ||
                    entry.path.startsWith('${parent.path}/')),
          ),
        )
        .toList();
    final nodes = <FileTreeNode>[];
    for (final entry in roots) {
      nodes.add(await scan(entry, 0));
    }
    return FileTreeNode(
      name: source.name,
      uri: Uri.parse('private-shelf://source-selection'),
      relativePath: '',
      isDirectory: true,
      isExpanded: true,
      isMedia: nodes.any((e) => e.isMedia),
      children: nodes,
      sourceTreeUri: source.treeUri,
    );
  }
}
