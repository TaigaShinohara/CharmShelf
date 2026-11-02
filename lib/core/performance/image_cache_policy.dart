import 'package:flutter/painting.dart';

/// 通常画面で維持する画像キャッシュ上限。
///
/// ビューワー表示中だけ専用リースが別途上限を引き上げる。
class AppImageCachePolicy {
  AppImageCachePolicy._();

  static const int maximumSizeBytes = 64 * 1024 * 1024;
  static const int maximumSize = 300;

  static void apply(ImageCache cache) {
    cache.maximumSizeBytes = maximumSizeBytes;
    cache.maximumSize = maximumSize;
  }
}
