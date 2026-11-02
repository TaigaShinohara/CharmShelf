import '../../domain/models/media_item.dart';

/// Joins page settlement with successful content loading. Preloading alone
/// cannot create a history entry; repeated build/load notifications are harmless.
class ViewerHistoryGate {
  ViewerHistoryGate(this.onOpened);

  final void Function(MediaItem item, DateTime openedAt) onOpened;
  final Set<String> _loaded = {};
  int _generation = 0;
  MediaItem? _item;
  String? _visit;
  String? _recordedVisit;
  DateTime? _openedAt;
  bool _settled = false;
  String? _preservedRecordedKey;

  String _key(MediaItem item) => '${item.id}:${item.path}';

  void beginSession(int generation, {MediaItem? preserveCurrent}) {
    final preserve =
        preserveCurrent != null &&
        _item != null &&
        _key(preserveCurrent) == _key(_item!);
    final loaded = preserve && _loaded.contains(_key(preserveCurrent));
    _preservedRecordedKey =
        preserve && _recordedVisit == _visit && _visit != null
        ? _key(preserveCurrent)
        : null;
    _generation = generation;
    _loaded.clear();
    if (loaded) _loaded.add(_key(preserveCurrent));
    _item = null;
    _visit = null;
    _recordedVisit = null;
    _openedAt = null;
    _settled = false;
  }

  void beginTransition() => _settled = false;

  void settle(MediaItem item, {required String visit, required DateTime at}) {
    if (_visit != visit) {
      _visit = visit;
      _openedAt = at;
    }
    _item = item;
    if (_preservedRecordedKey == _key(item)) _recordedVisit = visit;
    _preservedRecordedKey = null;
    _settled = true;
    _recordIfReady();
  }

  void loaded(MediaItem item, {required int generation}) {
    if (generation != _generation) return;
    _loaded.add(_key(item));
    _recordIfReady();
  }

  void _recordIfReady() {
    final item = _item;
    if (!_settled ||
        item == null ||
        _visit == _recordedVisit ||
        !_loaded.contains(_key(item)) ||
        item.id <= 0 ||
        item.isMissing ||
        item.type != MediaType.file) {
      return;
    }
    _recordedVisit = _visit;
    onOpened(item, _openedAt!);
  }
}
