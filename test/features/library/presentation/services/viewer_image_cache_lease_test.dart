import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/performance/image_cache_policy.dart';
import 'package:private_shelf/features/library/presentation/services/viewer_image_cache_lease.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('通常画面のキャッシュ上限は端末メモリを過剰占有しない', () {
    final cache = PaintingBinding.instance.imageCache;
    final originalBytes = cache.maximumSizeBytes;
    final originalCount = cache.maximumSize;
    addTearDown(() {
      cache.maximumSizeBytes = originalBytes;
      cache.maximumSize = originalCount;
    });

    AppImageCachePolicy.apply(cache);

    expect(cache.maximumSizeBytes, 64 * 1024 * 1024);
    expect(cache.maximumSize, 300);
  });

  test('最後のビューワーが閉じるまで共有キャッシュ上限を維持する', () {
    final cache = PaintingBinding.instance.imageCache;
    final originalBytes = cache.maximumSizeBytes;
    final originalCount = cache.maximumSize;
    addTearDown(() {
      while (ViewerImageCacheLease.debugLeaseCount > 0) {
        ViewerImageCacheLease.release();
      }
      cache.maximumSizeBytes = originalBytes;
      cache.maximumSize = originalCount;
    });
    cache.maximumSizeBytes = 16 * 1024 * 1024;
    cache.maximumSize = 20;

    ViewerImageCacheLease.acquire();
    ViewerImageCacheLease.acquire();
    ViewerImageCacheLease.release();

    expect(ViewerImageCacheLease.debugLeaseCount, 1);
    expect(cache.maximumSizeBytes, ViewerImageCacheLease.requestedMaxSizeBytes);
    expect(cache.maximumSize, ViewerImageCacheLease.requestedMaxSize);

    ViewerImageCacheLease.release();

    expect(ViewerImageCacheLease.debugLeaseCount, 0);
    expect(cache.maximumSizeBytes, 16 * 1024 * 1024);
    expect(cache.maximumSize, 20);
  });

  test('通常上限からビューワー中だけ拡張し、終了時に通常上限へ戻す', () {
    final cache = PaintingBinding.instance.imageCache;
    final originalBytes = cache.maximumSizeBytes;
    final originalCount = cache.maximumSize;
    addTearDown(() {
      while (ViewerImageCacheLease.debugLeaseCount > 0) {
        ViewerImageCacheLease.release();
      }
      cache.maximumSizeBytes = originalBytes;
      cache.maximumSize = originalCount;
    });
    AppImageCachePolicy.apply(cache);

    ViewerImageCacheLease.acquire();
    expect(cache.maximumSizeBytes, ViewerImageCacheLease.requestedMaxSizeBytes);
    expect(cache.maximumSize, ViewerImageCacheLease.requestedMaxSize);

    ViewerImageCacheLease.release();
    expect(cache.maximumSizeBytes, AppImageCachePolicy.maximumSizeBytes);
    expect(cache.maximumSize, AppImageCachePolicy.maximumSize);
  });
}
