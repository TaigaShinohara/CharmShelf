import 'dart:io';
import 'dart:typed_data';

import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';

/// アーカイブファイル（ZIP等）の簡易メタデータ情報
class ArchiveMetadata {
  final int entryCount;
  final bool isEncrypted;
  final int totalUncompressedBytes;

  const ArchiveMetadata({
    required this.entryCount,
    required this.isEncrypted,
    required this.totalUncompressedBytes,
  });

  const ArchiveMetadata.empty()
    : entryCount = 0,
      isEncrypted = false,
      totalUncompressedBytes = 0;
}

/// アーカイブファイルのメタデータ解析ユーティリティ
class ArchiveMetadataUtils {
  ArchiveMetadataUtils._();

  /// ZIPファイルの末尾 (End of Central Directory Record) をスキャンしてエントリ数を取得
  static Future<ArchiveMetadata?> inspectZipFile(File file) async {
    try {
      if (!await file.exists()) return null;
      final fileLength = await file.length();
      if (fileLength < 22) return null; // EOCD の最小サイズは22バイト

      // 末尾最大 65KB + 22バイト を読み込む
      final readLength = fileLength > 65557 ? 65557 : fileLength;
      final raf = await file.open(mode: FileMode.read);
      try {
        await raf.setPosition(fileLength - readLength);
        final buffer = Uint8List(readLength);
        await raf.readInto(buffer);

        // EOCD シグネチャ 0x06054b50 (PK\x05\x06) を後ろから検索
        for (var i = buffer.length - 22; i >= 0; i--) {
          if (buffer[i] == 0x50 &&
              buffer[i + 1] == 0x4b &&
              buffer[i + 2] == 0x05 &&
              buffer[i + 3] == 0x06) {
            final byteData = ByteData.sublistView(buffer, i);
            final totalEntries = byteData.getUint16(10, Endian.little);
            return ArchiveMetadata(
              entryCount: totalEntries,
              isEncrypted: false,
              totalUncompressedBytes: 0,
            );
          }
        }
      } finally {
        await raf.close();
      }
      return null;
    } catch (e, st) {
      AppLogger.w(LogTag.storage, 'ZIPメタデータの解析に失敗: ${file.path}', e, st);
      return null;
    }
  }
}
