import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/domain/utils/archive_metadata_utils.dart';

void main() {
  group('ArchiveMetadataUtils テスト', () {
    late Directory tempDir;
    late File validZipFile;
    late File invalidZipFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('archive_test');

      // 最小限の有効なZIPヘッダー(EOCD: 22バイト)を作成
      // End of central directory record (22 bytes)
      // 0..3: Signature 0x06054b50 (PK\x05\x06)
      // 4..5: Disk number = 0
      // 6..7: Disk with start of CD = 0
      // 8..9: Number of CD entries on this disk = 3
      // 10..11: Total number of CD entries = 3
      // 12..15: Size of central directory = 0
      // 16..19: Offset of start of CD = 0
      // 20..21: Comment length = 0
      final eocd = Uint8List(22);
      final bd = ByteData.sublistView(eocd);
      bd.setUint32(0, 0x06054b50, Endian.little);
      bd.setUint16(8, 3, Endian.little);
      bd.setUint16(10, 3, Endian.little);

      validZipFile = File('${tempDir.path}/valid.zip');
      await validZipFile.writeAsBytes(eocd);

      invalidZipFile = File('${tempDir.path}/corrupt.zip');
      await invalidZipFile.writeAsString('corrupted non-zip content');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('有効なZIPファイルのエントリ数を正しく取得できる', () async {
      final meta = await ArchiveMetadataUtils.inspectZipFile(validZipFile);
      expect(meta, isNotNull);
      expect(meta!.entryCount, 3);
    });

    test('破損したZIPファイルは null を返す', () async {
      final meta = await ArchiveMetadataUtils.inspectZipFile(invalidZipFile);
      expect(meta, isNull);
    });

    test('存在しないファイルは null を返す', () async {
      final meta = await ArchiveMetadataUtils.inspectZipFile(
        File('${tempDir.path}/not_exists.zip'),
      );
      expect(meta, isNull);
    });
  });
}
