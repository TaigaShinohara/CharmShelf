import 'dart:math';

/// ファイルサイズおよび拡張子フォーマット用ユーティリティ
class FileSizeUtils {
  FileSizeUtils._();

  /// バイト数を読みやすい文字列（B, KB, MB, GB）に変換する
  static String formatBytes(int? bytes, [int decimals = 1]) {
    if (bytes == null || bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (log(bytes) / log(1024)).floor().clamp(0, suffixes.length - 1);
    final size = bytes / pow(1024, i);
    return '${size.toStringAsFixed(i == 0 ? 0 : decimals)} ${suffixes[i]}';
  }

  /// ファイルパスから拡張子（ドットなし・大文字）を取得する
  static String getExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == path.length - 1) return '';
    return path.substring(dotIndex + 1).toUpperCase();
  }
}
