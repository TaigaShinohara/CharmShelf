import 'dart:io';

import 'package:path/path.dart' as p;

/// アプリ管理領域からのパス逸脱を防ぐための共通境界。
///
/// 呼び出し側から渡される値は、DBやバックアップ由来であっても信頼しない。
abstract final class StorageSandbox {
  static String resolveRelative(
    String rootPath,
    String relativePath, {
    required Set<String> allowedTopLevelDirectories,
  }) {
    if (relativePath.isEmpty ||
        relativePath.contains('\u0000') ||
        relativePath.contains('\\') ||
        p.isAbsolute(relativePath) ||
        Uri.tryParse(relativePath)?.hasScheme == true) {
      throw const FileSystemException('Invalid relative storage path');
    }

    final normalizedRelative = p.normalize(relativePath);
    final segments = p.split(normalizedRelative);
    if (segments.isEmpty ||
        segments.any((segment) => segment == '..' || segment == '.')) {
      throw const FileSystemException('Storage path escapes its sandbox');
    }
    if (!allowedTopLevelDirectories.contains(segments.first)) {
      throw const FileSystemException('Storage path is outside allowed roots');
    }

    final normalizedRoot = p.normalize(p.absolute(rootPath));
    final resolved = p.normalize(p.join(normalizedRoot, normalizedRelative));
    if (resolved == normalizedRoot || !p.isWithin(normalizedRoot, resolved)) {
      throw const FileSystemException('Storage path escapes its sandbox');
    }
    return resolved;
  }

  /// 既存の親要素にシンボリックリンクが含まれていないことを確認する。
  static Future<void> rejectSymbolicLinkAncestors(
    String rootPath,
    String resolvedPath,
  ) async {
    final normalizedRoot = p.normalize(p.absolute(rootPath));
    var current = normalizedRoot;
    final relative = p.relative(resolvedPath, from: normalizedRoot);
    final segments = p.split(relative);

    // 最終要素は未作成の場合があるため、存在する要素だけを検査する。
    for (final segment in segments) {
      current = p.join(current, segment);
      final type = await FileSystemEntity.type(current, followLinks: false);
      if (type == FileSystemEntityType.link) {
        throw const FileSystemException(
          'Symbolic links are not allowed in managed storage paths',
        );
      }
      if (type == FileSystemEntityType.notFound) break;
    }
  }
}
