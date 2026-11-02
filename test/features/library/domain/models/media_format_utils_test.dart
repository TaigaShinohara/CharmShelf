import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/domain/models/media_format_utils.dart';

void main() {
  group('MediaFormatUtils', () {
    test(
      'extensionless provider names use only known supported MIME formats',
      () {
        const formats = {
          'image/png': '.png',
          'video/mp4': '.mp4',
          'audio/mpeg': '.mp3',
          'application/pdf': '.pdf',
          'text/plain': '.txt',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
              '.docx',
          'application/zip': '.zip',
        };
        for (final entry in formats.entries) {
          expect(
            MediaFormatUtils.supportedMimeExtension('document', entry.key),
            entry.value,
          );
          expect(
            MediaFormatUtils.importName('document', entry.key),
            'document${entry.value}',
          );
        }
        expect(
          MediaFormatUtils.importName('photo', 'IMAGE/PNG; charset=UTF-8'),
          'photo.png',
        );
      },
    );

    test('MIME cannot override existing extensions or ignored filenames', () {
      expect(
        MediaFormatUtils.supportedMimeExtension('photo.bin', 'image/png'),
        isNull,
      );
      expect(
        MediaFormatUtils.importName('photo.bin', 'image/png'),
        'photo.bin',
      );
      expect(
        MediaFormatUtils.supportedMimeExtension('photo', 'image/unknown'),
        isNull,
      );
      expect(MediaFormatUtils.importName('photo', 'image/unknown'), 'photo');
      expect(
        MediaFormatUtils.supportedMimeExtension('.photo', 'image/png'),
        isNull,
      );
      expect(MediaFormatUtils.supportedMimeExtension('', 'image/png'), isNull);
      expect(
        MediaFormatUtils.supportedMimeExtension(
          'photo.JPG',
          'application/octet-stream',
        ),
        '.jpg',
      );
      expect(
        MediaFormatUtils.importName('photo.JPG', 'image/png'),
        'photo.JPG',
      );
    });

    test('正常な拡張子を解決できる', () {
      expect(MediaFormatUtils.resolveExtension('test.jpg'), '.jpg');
      expect(MediaFormatUtils.resolveExtension('test.MP4'), '.mp4');
      expect(MediaFormatUtils.isImage('photo.png'), isTrue);
      expect(MediaFormatUtils.isVideo('movie.mp4'), isTrue);
    });

    test('不正なパーセントエンコーディングが含まれるURIでもクラッシュせず安全に拡張子を解決できる', () {
      // 不正なパーセント文字 (例: "%", "%G1", "%2", "%zz")
      expect(
        MediaFormatUtils.resolveExtension(
          'content://media/external/file/100%_invalid.png',
        ),
        '.png',
      );
      expect(
        MediaFormatUtils.resolveExtension(
          'content://media/external/file/%invalid%.mp4',
        ),
        '.mp4',
      );
      expect(
        MediaFormatUtils.resolveExtension('content://media/external/file/%'),
        '',
      );
      expect(
        MediaFormatUtils.resolveExtension(
          'file:///path/to/corrupted%E0%A4%A.jpg',
        ),
        '.jpg',
      );

      expect(
        MediaFormatUtils.isImage(
          'content://media/external/file/100%_invalid.png',
        ),
        isTrue,
      );
      expect(
        MediaFormatUtils.isVideo('content://media/external/file/%invalid%.mp4'),
        isTrue,
      );
    });

    test('二重エンコードや特殊文字を含むURIでも判定が動作する', () {
      expect(
        MediaFormatUtils.isImage('content://media/image%20file%2520.webp'),
        isTrue,
      );
      expect(
        MediaFormatUtils.isPdf('content://media/document%20test.pdf'),
        isTrue,
      );
    });

    test('隠しファイルやシステム生成ファイルが正しく除外判定される', () {
      expect(MediaFormatUtils.isIgnoredFile('.DS_Store'), isTrue);
      expect(MediaFormatUtils.isIgnoredFile('._test.jpg'), isTrue);
      expect(MediaFormatUtils.isIgnoredFile('.thumbnails'), isTrue);
      expect(MediaFormatUtils.isIgnoredFile('crash_reports.json'), isTrue);
      expect(MediaFormatUtils.isIgnoredFile('temp.tmp'), isTrue);
      expect(MediaFormatUtils.isIgnoredFile('backup.bak'), isTrue);
      expect(MediaFormatUtils.isIgnoredFile('Thumbs.db'), isTrue);
      expect(MediaFormatUtils.isIgnoredFile('desktop.ini'), isTrue);
      expect(
        MediaFormatUtils.isIgnoredFile('path/to/crash_reports.json'),
        isTrue,
      );

      // 通常ファイルは除外されない
      expect(MediaFormatUtils.isIgnoredFile('photo.jpg'), isFalse);
      expect(MediaFormatUtils.isIgnoredFile('report.json'), isFalse);
      expect(MediaFormatUtils.isIgnoredFile('document.pdf'), isFalse);
    });

    test('隠しディレクトリやシステムフォルダが正しく除外判定される', () {
      expect(MediaFormatUtils.isIgnoredDirectory('.thumbnails'), isTrue);
      expect(MediaFormatUtils.isIgnoredDirectory('.trash'), isTrue);
      expect(MediaFormatUtils.isIgnoredDirectory('__MACOSX'), isTrue);
      expect(MediaFormatUtils.isIgnoredDirectory('path/to/.tagshelf'), isTrue);

      // 通常フォルダは除外されない
      expect(MediaFormatUtils.isIgnoredDirectory('MyFolder'), isFalse);
      expect(MediaFormatUtils.isIgnoredDirectory('library'), isFalse);
    });
  });
}
