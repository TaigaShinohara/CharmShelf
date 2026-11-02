import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/domain/models/media_format_utils.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';

void main() {
  group('MediaFormatUtils 形式判定テスト', () {
    test('画像形式を正しく判定できる', () {
      final images = [
        'photo.jpg',
        'photo.JPEG',
        'image.png',
        'anim.gif',
        'modern.webp',
        'bitmap.bmp',
        'raw_photo.heic',
        'raw_photo.HEIF',
        'high_res.tiff',
        'vector.svg',
        'icon.ico',
        'camera.dng',
        'camera.raw',
      ];

      for (final path in images) {
        expect(
          MediaFormatUtils.isImage(path),
          isTrue,
          reason: 'Failed for $path',
        );
        expect(MediaFormatUtils.isVideo(path), isFalse);
        expect(MediaFormatUtils.isAudio(path), isFalse);
      }
    });

    test('動画形式を正しく判定できる', () {
      final videos = [
        'movie.mp4',
        'movie.MOV',
        'clip.avi',
        'stream.mkv',
        'web.webm',
        'video.m4v',
        'old.3gp',
        'flash.flv',
        'windows.wmv',
        'broadcast.ts',
        'bluray.m2ts',
      ];

      for (final path in videos) {
        expect(
          MediaFormatUtils.isVideo(path),
          isTrue,
          reason: 'Failed for $path',
        );
        expect(MediaFormatUtils.isImage(path), isFalse);
        expect(MediaFormatUtils.isAudio(path), isFalse);
      }
    });

    test('音声形式を正しく判定できる', () {
      final audios = [
        'music.mp3',
        'music.MP3',
        'recording.wav',
        'itunes.m4a',
        'lossless.flac',
        'audio.aac',
        'media.wma',
        'stream.ogg',
        'studio.aiff',
        'apple.alac',
      ];

      for (final path in audios) {
        expect(
          MediaFormatUtils.isAudio(path),
          isTrue,
          reason: 'Failed for $path',
        );
        expect(MediaFormatUtils.isImage(path), isFalse);
        expect(MediaFormatUtils.isVideo(path), isFalse);
      }
    });

    test('PDFおよびドキュメント形式を正しく判定できる', () {
      expect(MediaFormatUtils.isPdf('doc.pdf'), isTrue);
      expect(MediaFormatUtils.isPdf('doc.PDF'), isTrue);
      expect(MediaFormatUtils.isPdf('doc.docx'), isFalse);

      final docs = [
        'doc.pdf',
        'word.doc',
        'word.docx',
        'sheet.xls',
        'sheet.xlsx',
        'slides.ppt',
        'slides.pptx',
        'memo.txt',
        'rich.rtf',
        'data.csv',
        'apple.pages',
        'apple.numbers',
        'apple.key',
      ];

      for (final path in docs) {
        expect(
          MediaFormatUtils.isDocument(path),
          isTrue,
          reason: 'Failed for $path',
        );
      }
    });

    test('テキストおよびMarkdown形式を正しく判定できる', () {
      expect(MediaFormatUtils.isMarkdown('readme.md'), isTrue);
      expect(MediaFormatUtils.isMarkdown('readme.MARKDOWN'), isTrue);
      expect(MediaFormatUtils.isMarkdown('code.dart'), isFalse);

      final texts = [
        'memo.txt',
        'readme.md',
        'config.yaml',
        'config.yml',
        'data.json',
        'export.csv',
        'script.py',
        'main.dart',
        'app.js',
        'index.ts',
        'page.html',
        'style.css',
        'build.sh',
        'schema.sql',
        'settings.ini',
        'server.conf',
        'app.log',
      ];

      for (final path in texts) {
        expect(
          MediaFormatUtils.isText(path),
          isTrue,
          reason: 'Failed for $path',
        );
      }
    });

    test('アーカイブ形式を正しく判定できる', () {
      final archives = [
        'archive.zip',
        'archive.ZIP',
        'compressed.rar',
        'backup.7z',
        'bundle.tar',
        'data.gz',
      ];

      for (final path in archives) {
        expect(
          MediaFormatUtils.isArchive(path),
          isTrue,
          reason: 'Failed for $path',
        );
      }
    });

    test('MIMEタイプ付きの判定が正常に動作する', () {
      expect(
        MediaFormatUtils.isImage('unknown_ext', mimeType: 'image/jpeg'),
        isTrue,
      );
      expect(
        MediaFormatUtils.isVideo('unknown_ext', mimeType: 'video/mp4'),
        isTrue,
      );
      expect(
        MediaFormatUtils.isAudio('unknown_ext', mimeType: 'audio/mpeg'),
        isTrue,
      );
      expect(
        MediaFormatUtils.isPdf('unknown_ext', mimeType: 'application/pdf'),
        isTrue,
      );
    });

    test('SVGおよびRAW画像形式を正しく判定できる', () {
      expect(MediaFormatUtils.isSvg('vector.svg'), isTrue);
      expect(MediaFormatUtils.isSvg('vector.SVG'), isTrue);
      expect(MediaFormatUtils.isSvg('photo.png'), isFalse);

      expect(MediaFormatUtils.isRawOrTiff('image.tiff'), isTrue);
      expect(MediaFormatUtils.isRawOrTiff('image.tif'), isTrue);
      expect(MediaFormatUtils.isRawOrTiff('camera.raw'), isTrue);
      expect(MediaFormatUtils.isRawOrTiff('camera.dng'), isTrue);
      expect(MediaFormatUtils.isRawOrTiff('photo.jpg'), isFalse);

      // 直接描画可能判定（SVG含む、RAW/TIFF除外）
      expect(MediaFormatUtils.isDirectlyViewableImage('photo.jpg'), isTrue);
      expect(MediaFormatUtils.isDirectlyViewableImage('vector.svg'), isTrue);
      expect(MediaFormatUtils.isDirectlyViewableImage('camera.raw'), isFalse);
      expect(MediaFormatUtils.isDirectlyViewableImage('image.tiff'), isFalse);
    });

    test('MediaItem との連携が正常に動作する', () {
      final item = MediaItem()..path = 'documents/library/sample.png';
      expect(item.isImage, isTrue);
      expect(item.isDirectlyViewableImage, isTrue);
      expect(item.isSvg, isFalse);
      expect(item.isVideo, isFalse);
      expect(item.isViewableInApp, isTrue);

      final svgItem = MediaItem()..path = 'documents/library/logo.svg';
      expect(svgItem.isImage, isTrue);
      expect(svgItem.isSvg, isTrue);
      expect(svgItem.isDirectlyViewableImage, isTrue);
      expect(svgItem.isViewableInApp, isTrue);

      final rawItem = MediaItem()..path = 'documents/library/photo.dng';
      expect(rawItem.isImage, isTrue);
      expect(rawItem.isRawOrTiff, isTrue);
      expect(rawItem.isDirectlyViewableImage, isFalse);
      expect(rawItem.isViewableInApp, isFalse);

      final docItem = MediaItem()..path = 'documents/library/book.pdf';
      expect(docItem.isPdf, isTrue);
      expect(docItem.isDocument, isTrue);
      expect(docItem.isViewableInApp, isTrue);

      final zipItem = MediaItem()..path = 'documents/library/archive.zip';
      expect(zipItem.isArchive, isTrue);
      expect(zipItem.isViewableInApp, isFalse);
    });
  });
}
