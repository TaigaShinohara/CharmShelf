import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Reference-counted ownership for the viewer's temporary ImageCache budget.
///
/// Multiple viewer routes can overlap during transitions. The original global
/// values are restored only after the last viewer releases its lease.
class ViewerImageCacheLease {
  ViewerImageCacheLease._();

  static const int requestedMaxSizeBytes = 120 * 1024 * 1024;
  static const int requestedMaxSize = 600;

  static int _leaseCount = 0;
  static int? _originalMaxSizeBytes;
  static int? _originalMaxSize;
  static int? _appliedMaxSizeBytes;
  static int? _appliedMaxSize;

  static void acquire() {
    if (_leaseCount++ > 0) return;

    final imageCache = PaintingBinding.instance.imageCache;
    _originalMaxSizeBytes = imageCache.maximumSizeBytes;
    _originalMaxSize = imageCache.maximumSize;

    if (imageCache.maximumSizeBytes < requestedMaxSizeBytes) {
      imageCache.maximumSizeBytes = requestedMaxSizeBytes;
      _appliedMaxSizeBytes = requestedMaxSizeBytes;
    }
    if (imageCache.maximumSize < requestedMaxSize) {
      imageCache.maximumSize = requestedMaxSize;
      _appliedMaxSize = requestedMaxSize;
    }
  }

  static void release() {
    if (_leaseCount == 0) return;
    if (--_leaseCount > 0) return;

    final imageCache = PaintingBinding.instance.imageCache;
    if (_originalMaxSizeBytes != null &&
        _appliedMaxSizeBytes != null &&
        imageCache.maximumSizeBytes == _appliedMaxSizeBytes) {
      imageCache.maximumSizeBytes = _originalMaxSizeBytes!;
    }
    if (_originalMaxSize != null &&
        _appliedMaxSize != null &&
        imageCache.maximumSize == _appliedMaxSize) {
      imageCache.maximumSize = _originalMaxSize!;
    }

    _originalMaxSizeBytes = null;
    _originalMaxSize = null;
    _appliedMaxSizeBytes = null;
    _appliedMaxSize = null;
  }

  @visibleForTesting
  static int get debugLeaseCount => _leaseCount;
}
