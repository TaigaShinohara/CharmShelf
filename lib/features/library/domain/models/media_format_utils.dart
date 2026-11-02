import 'package:path/path.dart' as p;

/// メディアファイルの形式判定を集約するユーティリティクラス
class MediaFormatUtils {
  MediaFormatUtils._();

  // ---------------------------------------------------------------------------
  // 拡張子セット定義
  // ---------------------------------------------------------------------------

  /// 画像形式の拡張子セット
  static const Set<String> imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.bmp',
    '.heic',
    '.heif',
    '.tiff',
    '.tif',
    '.svg',
    '.ico',
    '.raw',
    '.dng',
  };

  /// ベクター画像形式の拡張子セット
  static const Set<String> vectorImageExtensions = {'.svg'};

  /// RAW・TIFF等の特殊画像形式（Flutter標準デコード非対応）の拡張子セット
  static const Set<String> rawImageExtensions = {
    '.tiff',
    '.tif',
    '.raw',
    '.dng',
  };

  /// アプリ内で直接描画可能なラスター画像形式の拡張子セット
  static const Set<String> rasterImageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.bmp',
    '.heic',
    '.heif',
    '.ico',
  };

  /// 動画形式の拡張子セット
  static const Set<String> videoExtensions = {
    '.mp4',
    '.mov',
    '.avi',
    '.mkv',
    '.webm',
    '.m4v',
    '.3gp',
    '.flv',
    '.wmv',
    '.ts',
    '.m2ts',
  };

  /// 音声形式の拡張子セット
  static const Set<String> audioExtensions = {
    '.mp3',
    '.wav',
    '.m4a',
    '.flac',
    '.aac',
    '.wma',
    '.ogg',
    '.aiff',
    '.alac',
  };

  /// PDF形式の拡張子セット
  static const Set<String> pdfExtensions = {'.pdf'};

  /// Markdown形式の拡張子セット
  static const Set<String> markdownExtensions = {'.md', '.markdown'};

  /// テキスト・ソースコード形式の拡張子セット
  static const Set<String> textExtensions = {
    '.txt',
    '.md',
    '.markdown',
    '.yaml',
    '.yml',
    '.json',
    '.csv',
    '.py',
    '.dart',
    '.js',
    '.ts',
    '.html',
    '.css',
    '.sh',
    '.sql',
    '.ini',
    '.conf',
    '.log',
  };

  /// 一般ドキュメント形式の拡張子セット
  static const Set<String> documentExtensions = {
    '.pdf',
    '.doc',
    '.docx',
    '.xls',
    '.xlsx',
    '.ppt',
    '.pptx',
    '.txt',
    '.rtf',
    '.csv',
    '.pages',
    '.numbers',
    '.key',
  };

  /// アーカイブ形式の拡張子セット
  static const Set<String> archiveExtensions = {
    '.zip',
    '.rar',
    '.7z',
    '.tar',
    '.gz',
  };

  /// アプリで管理・インポート対象とする全拡張子セット
  static final Set<String> allSupportedExtensions = {
    ...imageExtensions,
    ...videoExtensions,
    ...audioExtensions,
    ...documentExtensions,
    ...textExtensions,
    ...archiveExtensions,
  };

  // Explicit MIME aliases only; unknown media MIME types are not importable.
  static const _importMimeExtensions = <String, String>{
    'image/jpeg': '.jpg',
    'image/png': '.png',
    'image/gif': '.gif',
    'image/bmp': '.bmp',
    'image/webp': '.webp',
    'image/heic': '.heic',
    'image/heif': '.heif',
    'image/tiff': '.tiff',
    'image/svg+xml': '.svg',
    'image/x-icon': '.ico',
    'image/vnd.microsoft.icon': '.ico',
    'video/mp4': '.mp4',
    'video/quicktime': '.mov',
    'video/x-msvideo': '.avi',
    'video/x-matroska': '.mkv',
    'video/webm': '.webm',
    'video/3gpp': '.3gp',
    'video/x-flv': '.flv',
    'video/x-ms-wmv': '.wmv',
    'video/mp2t': '.ts',
    'audio/mpeg': '.mp3',
    'audio/wav': '.wav',
    'audio/x-wav': '.wav',
    'audio/vnd.wave': '.wav',
    'audio/mp4': '.m4a',
    'audio/flac': '.flac',
    'audio/x-flac': '.flac',
    'audio/aac': '.aac',
    'audio/ogg': '.ogg',
    'audio/x-ms-wma': '.wma',
    'audio/aiff': '.aiff',
    'audio/x-aiff': '.aiff',
    'application/pdf': '.pdf',
    'text/plain': '.txt',
    'text/csv': '.csv',
    'text/markdown': '.md',
    'text/html': '.html',
    'text/css': '.css',
    'text/javascript': '.js',
    'application/javascript': '.js',
    'application/json': '.json',
    'application/yaml': '.yaml',
    'text/yaml': '.yaml',
    'text/rtf': '.rtf',
    'application/rtf': '.rtf',
    'application/msword': '.doc',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        '.docx',
    'application/vnd.ms-excel': '.xls',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
        '.xlsx',
    'application/vnd.ms-powerpoint': '.ppt',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation':
        '.pptx',
    'application/zip': '.zip',
    'application/x-zip-compressed': '.zip',
    'application/vnd.rar': '.rar',
    'application/x-rar-compressed': '.rar',
    'application/x-7z-compressed': '.7z',
    'application/x-tar': '.tar',
    'application/gzip': '.gz',
    'application/x-gzip': '.gz',
  };

  /// Only extensionless display names can use a known MIME extension.
  /// An explicitly unsupported extension or ignored filename stays rejected.
  static String? supportedMimeExtension(String name, String? mimeType) {
    if (name.trim().isEmpty || isIgnoredFile(name)) return null;
    final extension = p.extension(name).toLowerCase();
    if (extension.isNotEmpty) {
      return allSupportedExtensions.contains(extension) ? extension : null;
    }
    final mime = mimeType?.split(';').first.trim().toLowerCase();
    return _importMimeExtensions[mime];
  }

  /// Supply an extension to the private import copy without renaming the source.
  static String importName(String name, String? mimeType) {
    if (p.extension(name).isNotEmpty) return name;
    final extension = supportedMimeExtension(name, mimeType);
    return extension == null ? name : '$name$extension';
  }

  // ---------------------------------------------------------------------------
  // 判定メソッド
  // ---------------------------------------------------------------------------

  /// パスまたはURIから安全に拡張子を抽出
  static String resolveExtension(String path, {String? originalPath}) {
    final pathExt = p.extension(path).toLowerCase();
    if (pathExt.isNotEmpty) return pathExt;

    if (originalPath != null && originalPath.isNotEmpty) {
      final originalExt = p.extension(originalPath).toLowerCase();
      if (originalExt.isNotEmpty) return originalExt;
    }

    final uri = Uri.tryParse(path);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final decoded = _safeDecodeUriComponent(uri.pathSegments.last);
      final uriExt = p.extension(decoded).toLowerCase();
      if (uriExt.isNotEmpty) return uriExt;
    }

    return '';
  }

  static String _safeDecodeUriComponent(String value) {
    try {
      return Uri.decodeComponent(value);
    } catch (_) {
      return value;
    }
  }

  static bool _hasMime(String? mimeType, String prefix) {
    if (mimeType == null || mimeType.isEmpty) return false;
    return mimeType.toLowerCase().startsWith(prefix.toLowerCase());
  }

  /// 画像判定
  static bool isImage(String path, {String? mimeType, String? originalPath}) {
    if (_hasMime(mimeType, 'image/')) return true;
    if (_hasMime(mimeType, 'video/') || _hasMime(mimeType, 'audio/')) {
      return false;
    }
    final ext = resolveExtension(path, originalPath: originalPath);
    return imageExtensions.contains(ext);
  }

  /// SVGベクター画像判定
  static bool isSvg(String path, {String? mimeType, String? originalPath}) {
    if ((mimeType ?? '').toLowerCase() == 'image/svg+xml') return true;
    final ext = resolveExtension(path, originalPath: originalPath);
    return vectorImageExtensions.contains(ext);
  }

  /// RAW/TIFF特殊画像判定（Flutter標準では直接デコードできない形式）
  static bool isRawOrTiff(
    String path, {
    String? mimeType,
    String? originalPath,
  }) {
    final ext = resolveExtension(path, originalPath: originalPath);
    return rawImageExtensions.contains(ext);
  }

  /// アプリ内で直接描画可能な画像（ラスター画像またはSVG）か判定
  static bool isDirectlyViewableImage(
    String path, {
    String? mimeType,
    String? originalPath,
  }) {
    if (isSvg(path, mimeType: mimeType, originalPath: originalPath)) {
      return true;
    }
    if (isRawOrTiff(path, mimeType: mimeType, originalPath: originalPath)) {
      return false;
    }
    return isImage(path, mimeType: mimeType, originalPath: originalPath);
  }

  /// 動画判定
  static bool isVideo(String path, {String? mimeType, String? originalPath}) {
    if (_hasMime(mimeType, 'video/')) return true;
    final ext = resolveExtension(path, originalPath: originalPath);
    return videoExtensions.contains(ext);
  }

  /// 音声判定
  static bool isAudio(String path, {String? mimeType, String? originalPath}) {
    if (_hasMime(mimeType, 'audio/')) return true;
    final ext = resolveExtension(path, originalPath: originalPath);
    return audioExtensions.contains(ext);
  }

  /// PDF判定
  static bool isPdf(String path, {String? mimeType, String? originalPath}) {
    if ((mimeType ?? '').toLowerCase() == 'application/pdf') return true;
    final ext = resolveExtension(path, originalPath: originalPath);
    return pdfExtensions.contains(ext);
  }

  /// Markdown判定
  static bool isMarkdown(String path, {String? originalPath}) {
    final ext = resolveExtension(path, originalPath: originalPath);
    return markdownExtensions.contains(ext);
  }

  /// テキスト判定 (Markdownを含む)
  static bool isText(String path, {String? mimeType, String? originalPath}) {
    if (_hasMime(mimeType, 'text/')) return true;
    final ext = resolveExtension(path, originalPath: originalPath);
    return textExtensions.contains(ext);
  }

  /// ドキュメント判定
  static bool isDocument(
    String path, {
    String? mimeType,
    String? originalPath,
  }) {
    if (isPdf(path, mimeType: mimeType, originalPath: originalPath)) {
      return true;
    }
    final ext = resolveExtension(path, originalPath: originalPath);
    return documentExtensions.contains(ext);
  }

  /// アーカイブ判定
  static bool isArchive(String path, {String? originalPath}) {
    final ext = resolveExtension(path, originalPath: originalPath);
    return archiveExtensions.contains(ext);
  }

  /// アプリ内で表示可能なメディア（直接描画可能な画像・動画・音声・PDF・テキスト）か判定
  static bool isViewableInApp(
    String path, {
    String? mimeType,
    String? originalPath,
  }) {
    return isDirectlyViewableImage(
          path,
          mimeType: mimeType,
          originalPath: originalPath,
        ) ||
        isVideo(path, mimeType: mimeType, originalPath: originalPath) ||
        isAudio(path, mimeType: mimeType, originalPath: originalPath) ||
        isPdf(path, mimeType: mimeType, originalPath: originalPath) ||
        isText(path, mimeType: mimeType, originalPath: originalPath);
  }

  /// 隠しファイルやシステム生成ファイル（除外対象）か判定
  static bool isIgnoredFile(String pathOrName) {
    final fileName = p.basename(pathOrName);
    return fileName.startsWith('.') ||
        fileName.startsWith('._') ||
        fileName.endsWith('.tmp') ||
        fileName.endsWith('.bak') ||
        fileName == 'crash_reports.json' ||
        fileName == '__MACOSX' ||
        fileName == 'Thumbs.db' ||
        fileName == 'desktop.ini';
  }

  /// 隠しディレクトリやシステムフォルダ（除外対象）か判定
  static bool isIgnoredDirectory(String pathOrName) {
    final dirName = p.basename(pathOrName);
    return dirName.startsWith('.') || dirName == '__MACOSX';
  }
}
