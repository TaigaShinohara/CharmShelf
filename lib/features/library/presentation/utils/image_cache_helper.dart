import 'dart:io';
import 'package:flutter/material.dart';

/// ディスプレイサイズとDPRから最適化されたキャッシュ解像度の制限値(px)を算出します
int calculateTargetImageLimit(BuildContext context) {
  final screenSize = MediaQuery.of(context).size;
  final dpr = MediaQuery.of(context).devicePixelRatio;
  final maxDim = screenSize.width > screenSize.height
      ? screenSize.width
      : screenSize.height;
  return (maxDim * dpr * 1.5).clamp(800.0, 2000.0).toInt();
}

/// ファイルに応じた正確かつ安定した ImageProvider を取得します
///
/// [ResizeImagePolicy.fit] を使用することで、アスペクト比の事前取得有無に関わらず
/// 長辺が [targetLimit] に収まるよう均一にリサイズデコードされ、キャッシュキーがブレません。
ImageProvider getImageProviderForFile({
  required File file,
  double? aspectRatio,
  required int targetLimit,
}) {
  final fileImage = FileImage(file);
  return ResizeImage(
    fileImage,
    width: targetLimit,
    height: targetLimit,
    policy: ResizeImagePolicy.fit,
  );
}

/// 画像ファイルをあらかじめデコードして Flutter の ImageCache に乗せます
Future<void> precacheImageFile({
  required BuildContext context,
  required File file,
  double? aspectRatio,
  required int targetLimit,
}) async {
  try {
    final provider = getImageProviderForFile(
      file: file,
      aspectRatio: aspectRatio,
      targetLimit: targetLimit,
    );
    await precacheImage(
      provider,
      context,
      // This is speculative work. The visible Image keeps its own
      // errorBuilder, so a failed preload must not surface as an uncaught
      // FlutterError before the user reaches that file.
      onError: (_, _) {},
    );
  } catch (_) {
    // プリキャッシュ時の例外はサイレントに処理（実表示側でハンドリング）
  }
}
