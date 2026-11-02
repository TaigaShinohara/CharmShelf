import 'dart:io';

import 'package:flutter/services.dart';

/// 外部データの取り込みで端末資源を無制限に消費しないための共通上限。
abstract final class ImportSafetyPolicy {
  static const int maxFileCount = 100000;
  static const int maxScannedEntryCount = 200000;
  static const int maxTotalBytes = 100 * 1024 * 1024 * 1024;
  static const int minimumFreeBytesAfterImport = 512 * 1024 * 1024;
  static const int maxMetadataBytes = 50 * 1024 * 1024;
  static const int maxMetadataRecordsPerType = 100000;
  static const int maxRelativePathDepth = 64;

  static const _privacyChannel = MethodChannel(
    'com.tsmusic.privateshelf/privacy',
  );

  /// モバイルでは実際の空き容量を確認し、取り込み後も安全余裕を残す。
  static Future<void> ensureAvailableCapacity(
    String destinationPath,
    int requiredBytes,
  ) async {
    if (requiredBytes < 0 || requiredBytes > maxTotalBytes) {
      throw const FileSystemException('Import size exceeds the safety limit');
    }
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final safeLimit = await availableCopyLimit(destinationPath);
    if (requiredBytes > safeLimit) {
      throw const FileSystemException('Not enough storage space for import');
    }
  }

  /// 現在の空き容量と予約領域を考慮した、単一コピーの最大許容バイト数。
  static Future<int> availableCopyLimit(
    String destinationPath, {
    int hardLimit = maxTotalBytes,
  }) async {
    if (hardLimit < 0 || hardLimit > maxTotalBytes) {
      throw const FileSystemException('Invalid import copy limit');
    }
    if (!Platform.isAndroid && !Platform.isIOS) return hardLimit;

    final availableBytes = await _privacyChannel.invokeMethod<int>(
      'getAvailableStorageBytes',
      {'path': destinationPath},
    );
    if (availableBytes == null) {
      throw const FileSystemException(
        'Available storage could not be verified',
      );
    }
    final capacity = availableBytes - minimumFreeBytesAfterImport;
    if (capacity <= 0) {
      throw const FileSystemException('Not enough storage space for import');
    }
    return capacity < hardLimit ? capacity : hardLimit;
  }
}
