import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/services/image_optimization_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageOptimizationService テスト', () {
    late Directory tempDir;
    late File sampleImageFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('img_opt_test');

      // 100x100 のテスト用画像を生成して保存
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()..color = const ui.Color(0xFFFF0000);
      canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 100, 100), paint);
      final picture = recorder.endRecording();
      final img = await picture.toImage(100, 100);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      sampleImageFile = File('${tempDir.path}/sample.png');
      await sampleImageFile.writeAsBytes(byteData!.buffer.asUint8List());
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('画像情報を取得できる', () async {
      final service = ImageOptimizationService();
      final result = await service.getInfo(sampleImageFile);

      expect(result.isSuccess, isTrue);
      final info = result.dataOrNull!;
      expect(info.width, 100);
      expect(info.height, 100);
      expect(info.aspectRatio, 1.0);
    });

    test('画像のリサイズが正常に動作する', () async {
      final service = ImageOptimizationService();
      final result = await service.resize(
        file: sampleImageFile,
        maxWidth: 50,
        maxHeight: 50,
      );

      expect(result.isSuccess, isTrue);
      final bytes = result.dataOrNull!;
      expect(bytes, isNotEmpty);
    });

    test('画像の圧縮が正常に動作する', () async {
      final service = ImageOptimizationService();
      final result = await service.compress(
        file: sampleImageFile,
        quality: 60,
        maxSizeKB: 10,
      );

      expect(result.isSuccess, isTrue);
      final bytes = result.dataOrNull!;
      expect(bytes, isNotEmpty);
    });

    test('存在しないファイルの場合は失敗する', () async {
      final service = ImageOptimizationService();
      final result = await service.getInfo(
        File('${tempDir.path}/not_exists.png'),
      );

      expect(result.isFailure, isTrue);
    });
  });
}
