import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final samplePreviewServiceProvider = Provider.autoDispose<SamplePreviewService>(
  (ref) => SamplePreviewService(rootBundle),
);

/// Reads assets only. Cache lives with the preview, without files or DB writes.
/// Concurrent requests share one load; failed loads are always retryable.
class SamplePreviewService {
  SamplePreviewService(this._bundle);

  final AssetBundle _bundle;
  final Map<String, Uint8List> _cache = {};
  final Map<String, Future<Uint8List>> _pending = {};

  void discard(String assetPath) => _cache.remove(assetPath);

  Future<Uint8List> load(String assetPath) {
    final cached = _cache[assetPath];
    if (cached != null) return Future.value(cached);
    return _pending.putIfAbsent(assetPath, () => _load(assetPath));
  }

  Future<Uint8List> _load(String assetPath) async {
    try {
      final data = await Future.sync(() => _bundle.load(assetPath));
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      _cache[assetPath] = bytes;
      return bytes;
    } finally {
      _pending.remove(assetPath);
    }
  }
}
