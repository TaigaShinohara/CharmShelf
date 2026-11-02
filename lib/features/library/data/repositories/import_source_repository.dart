import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/import_source.dart';

/// A small, versioned registry. Registration never creates library records.
class ImportSourceRepository {
  ImportSourceRepository(this.preferences);
  static const storageKey = 'import_sources_v1';
  final SharedPreferences preferences;
  static final _writes = Expando<Future<void>>();

  Map<String, dynamic> _snapshot() {
    final value = preferences.getString(storageKey);
    if (value == null) {
      return {'version': 1, 'sources': <dynamic>[], 'pending': <dynamic>[]};
    }
    final data = jsonDecode(value) as Map<String, dynamic>;
    if (data['version'] != 1 ||
        data['sources'] is! List ||
        data['pending'] is! List) {
      throw const FormatException('Invalid source registry');
    }
    return data;
  }

  List<ImportSource> read() => (_snapshot()['sources'] as List)
      .map((e) => ImportSource.fromMap(Map<String, dynamic>.from(e as Map)))
      .toList();
  List<Uri> pendingReleases() =>
      (_snapshot()['pending'] as List).cast<String>().map(Uri.parse).toList();

  Future<void> _update(void Function(Map<String, dynamic>) update) {
    final next = (_writes[preferences] ?? Future<void>.value()).then((_) async {
      final previous = preferences.getString(storageKey);
      final data = _snapshot();
      update(data);
      try {
        if (!await preferences.setString(storageKey, jsonEncode(data))) {
          throw StateError('Could not save import sources');
        }
      } catch (_) {
        // SharedPreferences changes its cache before platform persistence succeeds.
        try {
          if (previous == null) {
            await preferences.remove(storageKey);
          } else {
            await preferences.setString(storageKey, previous);
          }
        } catch (_) {
          /* The original persistence failure must remain visible. */
        }
        rethrow;
      }
    });
    _writes[preferences] = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return next;
  }

  Future<void> save(ImportSource source) => _update((data) {
    final sources = (data['sources'] as List).cast<Map<dynamic, dynamic>>();
    for (final previous in sources.where(
      (s) => s['id'] == source.id && s['treeUri'] != '${source.treeUri}',
    )) {
      (data['pending'] as List).add(previous['treeUri']);
    }
    final same = sources
        .where((s) => s['treeUri'] == '${source.treeUri}')
        .firstOrNull;
    final record = source.toMap();
    if (same != null) {
      record['id'] = same['id'];
    }
    record['registeredAt'] =
        same?['registeredAt'] ?? DateTime.now().toUtc().toIso8601String();
    record['lastUsedAt'] = DateTime.now().toUtc().toIso8601String();
    sources.removeWhere(
      (s) => s['id'] == source.id || s['treeUri'] == '${source.treeUri}',
    );
    sources.add(record);
    data['sources'] = sources;
    (data['pending'] as List).remove('${source.treeUri}');
  });

  Future<void> remove(ImportSource source) => _update((data) {
    (data['sources'] as List).removeWhere((s) => (s as Map)['id'] == source.id);
    final pending = (data['pending'] as List).cast<String>().toSet()
      ..add('${source.treeUri}');
    data['pending'] = pending.toList();
  });
  Future<void> released(Uri uri) =>
      _update((data) => (data['pending'] as List).remove('$uri'));
}
