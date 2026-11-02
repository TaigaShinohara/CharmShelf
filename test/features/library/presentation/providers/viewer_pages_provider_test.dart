import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/viewer_pages_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('比率取得後は物理パスとMediaItemパスの両方から参照できる', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'viewer_aspect_ratio_test',
    );
    late final File file;
    addTearDown(() async {
      globalImageAspectRatioCache.remove('relative/wide.png');
      globalImageAspectRatioCache.remove(file.path);
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });
    file = File('${tempDir.path}/wide.png');
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 20, 10),
      Paint()..color = Colors.white,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(20, 10);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    await file.writeAsBytes(bytes!.buffer.asUint8List());

    final ratio = await fetchImageAspectRatio(
      file,
      cacheKey: 'relative/wide.png',
    );

    expect(ratio, 2.0);
    expect(globalImageAspectRatioCache[file.path], 2.0);
    expect(globalImageAspectRatioCache['relative/wide.png'], 2.0);
  });

  test('物理パス側の既存比率を安定パスへ補完する', () async {
    final file = File('/tmp/viewer-existing-ratio.png');
    globalImageAspectRatioCache[file.path] = 1.75;
    addTearDown(() {
      globalImageAspectRatioCache.remove(file.path);
      globalImageAspectRatioCache.remove('relative/existing.png');
    });

    final ratio = await fetchImageAspectRatio(
      file,
      cacheKey: 'relative/existing.png',
    );

    expect(ratio, 1.75);
    expect(globalImageAspectRatioCache['relative/existing.png'], 1.75);
  });

  test('安定パスに保存された横長比率から見開きページを生成する', () {
    final collection = MediaCollection()..splitSpreadView = true;
    final item = MediaItem()
      ..id = 900
      ..path = 'relative/spread.png'
      ..mimeType = 'image/png';
    item.collection.value = collection;
    globalImageAspectRatioCache[item.path] = 2.0;
    addTearDown(() => globalImageAspectRatioCache.remove(item.path));
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final pages = container.read(viewerPagesProvider(ViewerPagesParam([item])));

    expect(pages, hasLength(2));
    expect(pages.first.splitSide?.name, 'left');
    expect(pages.last.splitSide?.name, 'right');
  });
}
