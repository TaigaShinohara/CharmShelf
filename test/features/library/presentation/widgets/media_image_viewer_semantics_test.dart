import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/widgets/viewer/media_image_viewer.dart';

import '../../../../helpers/test_helpers.dart';

void main() {
  testWidgets('画像ビューアーが内容と操作方法を読み上げる', (tester) async {
    final semantics = tester.ensureSemantics();
    final directory = Directory.systemTemp.createTempSync(
      'media_image_semantics_',
    );
    addTearDown(() {
      directory.deleteSync(recursive: true);
    });
    final file = File('${directory.path}/思い出.png');
    file.writeAsBytesSync(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
        '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
    final item = MediaItem()
      ..uid = 'image-1'
      ..path = file.path
      ..sourceType = MediaSourceType.localCopy;
    await tester.pumpWidget(
      createProviderApp(
        Scaffold(
          body: MediaImageViewer(file: file, item: item, onTap: () {}),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final image = find.bySemanticsLabel('画像: 思い出.png');
    expect(image, findsOneWidget);
    final data = tester.getSemantics(image).getSemanticsData();
    expect(data.hint, contains('ダブルタップ'));
    expect(data.flagsCollection.isImage, isTrue);
    expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
    semantics.dispose();
  });
}
