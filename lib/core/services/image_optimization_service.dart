import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../error/app_error.dart';
import '../error/result.dart';
import '../logger/app_logger.dart';
import '../logger/log_tag.dart';

/// 画像最適化サービス
///
/// 画像のリサイズ、圧縮、形式変換を提供します。
///
/// 使用例:
/// ```dart
/// final service = ImageOptimizationService();
///
/// // リサイズ
/// final result = await service.resize(
///   file: imageFile,
///   maxWidth: 800,
///   maxHeight: 600,
/// );
///
/// // 圧縮
/// final compressed = await service.compress(
///   file: imageFile,
///   quality: 80,
/// );
/// ```
class ImageOptimizationService {
  /// 画像をリサイズ
  ///
  /// [file]: 元の画像ファイル
  /// [maxWidth]: 最大幅
  /// [maxHeight]: 最大高さ
  /// [quality]: 画像品質（1-100）
  Future<Result<Uint8List, AppError>> resize({
    required File file,
    required int maxWidth,
    required int maxHeight,
    int quality = 85,
  }) async {
    try {
      final infoResult = await getInfo(file);
      if (infoResult.isFailure) return Result.failure(infoResult.errorOrNull!);
      final info = infoResult.dataOrNull!;

      // アスペクト比を維持して目標サイズを計算
      final ratio = info.width / info.height;
      var targetWidth = maxWidth;
      var targetHeight = maxHeight;

      if (info.width > info.height) {
        targetHeight = (maxWidth / ratio).round();
        if (targetHeight > maxHeight) {
          targetHeight = maxHeight;
          targetWidth = (maxHeight * ratio).round();
        }
      } else {
        targetWidth = (maxHeight * ratio).round();
        if (targetWidth > maxWidth) {
          targetWidth = maxWidth;
          targetHeight = (maxWidth / ratio).round();
        }
      }

      // リサイズが不要な場合はそのまま返す
      if (info.width <= targetWidth && info.height <= targetHeight) {
        AppLogger.d(LogTag.app, 'リサイズ不要: ${info.width}x${info.height}');
        final bytes = await file.readAsBytes();
        return Result.success(bytes);
      }

      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          final resizedBytes = await _encodeImage(frame.image, quality);
          AppLogger.d(
            LogTag.app,
            'リサイズ完了: ${info.width}x${info.height} → ${targetWidth}x$targetHeight',
          );
          return Result.success(resizedBytes);
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } catch (e, st) {
      AppLogger.e(LogTag.app, '画像のリサイズに失敗', e, st);
      return Result.failure(
        AppError.unknown('画像のリサイズに失敗しました', original: e, stackTrace: st),
      );
    }
  }

  /// 画像を圧縮
  ///
  /// [file]: 元の画像ファイル
  /// [quality]: 画像品質（1-100）
  /// [maxSizeKB]: 目標ファイルサイズ（KB）
  Future<Result<Uint8List, AppError>> compress({
    required File file,
    int quality = 80,
    int? maxSizeKB,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final image = await _decodeImage(bytes);

      final currentQuality = quality.clamp(1, 100);
      var compressed = await _encodeImage(image, currentQuality);

      // 目標サイズが指定されている場合、寸法を段階的に縮小して目標サイズ以下に収める
      if (maxSizeKB != null) {
        final targetBytes = maxSizeKB * 1024;
        var scale = 0.85;
        var attempts = 0;
        while (compressed.length > targetBytes && attempts < 5) {
          final targetWidth = (image.width * scale).round();
          final targetHeight = (image.height * scale).round();
          if (targetWidth < 50 || targetHeight < 50) break;

          final downscaled = await _resizeImage(
            image,
            targetWidth,
            targetHeight,
            currentQuality,
          );
          compressed = downscaled;
          scale *= 0.75;
          attempts++;
        }
      }

      image.dispose(); // エンコード後に画像を解放

      final originalKB = (bytes.length / 1024).round();
      final compressedKB = (compressed.length / 1024).round();
      AppLogger.d(
        LogTag.app,
        '圧縮完了: ${originalKB}KB → ${compressedKB}KB (quality: $currentQuality)',
      );

      return Result.success(compressed);
    } catch (e, st) {
      AppLogger.e(LogTag.app, '画像の圧縮に失敗', e, st);
      return Result.failure(
        AppError.unknown('画像の圧縮に失敗しました', original: e, stackTrace: st),
      );
    }
  }

  /// 画像情報を取得
  Future<Result<ImageInfo, AppError>> getInfo(File file) async {
    try {
      if (!await file.exists()) {
        return Result.failure(AppError.file('ファイルが存在しません: ${file.path}'));
      }

      // ファイル全体をデコードせず、ヘッダ情報からサイズを高速に取得する
      final buffer = await ui.ImmutableBuffer.fromFilePath(file.path);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);

      final info = ImageInfo(
        width: descriptor.width,
        height: descriptor.height,
        sizeBytes: await file.length(),
      );

      descriptor.dispose();
      buffer.dispose();

      return Result.success(info);
    } catch (e, st) {
      AppLogger.e(LogTag.app, '画像情報の取得に失敗: ${file.path}', e, st);
      return Result.failure(
        AppError.unknown('画像情報の取得に失敗しました', original: e, stackTrace: st),
      );
    }
  }

  /// 画像をデコード
  Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  /// 画像をリサイズしてエンコード
  Future<Uint8List> _resizeImage(
    ui.Image image,
    int width,
    int height,
    int quality,
  ) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    final paint = Paint()..filterQuality = FilterQuality.high;

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      paint,
    );

    final picture = pictureRecorder.endRecording();
    try {
      final resizedImage = await picture.toImage(width, height);
      try {
        return await _encodeImage(resizedImage, quality);
      } finally {
        resizedImage.dispose(); // リサイズ後の画像を解放
      }
    } finally {
      picture.dispose(); // ネイティブPictureリソースを解放
    }
  }

  /// 画像をエンコード
  Future<Uint8List> _encodeImage(ui.Image image, int quality) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Failed to encode image to byte data');
    }
    return byteData.buffer.asUint8List();
  }
}

/// 画像情報
class ImageInfo {
  const ImageInfo({
    required this.width,
    required this.height,
    required this.sizeBytes,
  });

  final int width;
  final int height;
  final int sizeBytes;

  double get aspectRatio => width / height;
  int get sizeKB => (sizeBytes / 1024).round();
  int get sizeMB => (sizeBytes / (1024 * 1024)).round();

  @override
  String toString() {
    return 'ImageInfo(${width}x$height, ${sizeKB}KB)';
  }
}

/// 画像サイズの推奨設定
abstract class RecommendedImageSizes {
  /// サムネイル（リスト表示用）
  static const thumbnail = (maxWidth: 200, maxHeight: 200, quality: 70);

  /// プレビュー（詳細表示用）
  static const preview = (maxWidth: 800, maxHeight: 800, quality: 80);

  /// フルサイズ（保存用）
  static const full = (maxWidth: 1920, maxHeight: 1920, quality: 85);

  /// アバター
  static const avatar = (maxWidth: 256, maxHeight: 256, quality: 80);
}
