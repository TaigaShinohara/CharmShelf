import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../error/app_error.dart';
import '../error/result.dart';
import '../logger/app_logger.dart';
import '../logger/log_tag.dart';

enum AppShareStatus { completed, dismissed, unavailable }

/// シェア機能を提供するサービス
class ShareService {
  ShareService();

  /// テキストをシェア
  ///
  /// [text] シェアするテキスト
  /// [subject] メールの件名などに使用される（オプション）
  /// [sharePositionOrigin] iPad等で共有ポップオーバーを表示するアンカー矩形
  Future<Result<void, AppError>> shareText(
    String text, {
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    try {
      AppLogger.d(
        LogTag.share,
        'Sharing text: ${text.substring(0, text.length.clamp(0, 50))}...',
      );

      final result = await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: subject,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );

      if (result.status == ShareResultStatus.success) {
        AppLogger.i(LogTag.share, 'Text shared successfully');
      } else if (result.status == ShareResultStatus.dismissed) {
        AppLogger.d(LogTag.share, 'Share dismissed by user');
      }

      return Result.success(null);
    } catch (e, st) {
      AppLogger.e(LogTag.share, 'Failed to share text', e, st);
      return Result.failure(
        AppError.unknown('テキストのシェアに失敗しました', original: e, stackTrace: st),
      );
    }
  }

  /// 画像をシェア
  ///
  /// [image] シェアする画像ファイル（XFile）
  /// [text] 画像と一緒にシェアするテキスト（オプション）
  /// [sharePositionOrigin] iPad等で共有ポップオーバーを表示するアンカー矩形
  Future<Result<void, AppError>> shareImage(
    XFile image, {
    String? text,
    Rect? sharePositionOrigin,
  }) async {
    try {
      AppLogger.d(LogTag.share, 'Sharing image: ${image.path}');

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [image],
          text: text,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );

      if (result.status == ShareResultStatus.success) {
        AppLogger.i(LogTag.share, 'Image shared successfully');
      } else if (result.status == ShareResultStatus.dismissed) {
        AppLogger.d(LogTag.share, 'Share dismissed by user');
      }

      return Result.success(null);
    } catch (e, st) {
      AppLogger.e(LogTag.share, 'Failed to share image', e, st);
      return Result.failure(
        AppError.unknown('画像のシェアに失敗しました', original: e, stackTrace: st),
      );
    }
  }

  /// 複数ファイルをシェア
  ///
  /// [files] シェアするファイルのリスト（XFile）
  /// [text] ファイルと一緒にシェアするテキスト（オプション）
  /// [subject] メールの件名などに使用される（オプション）
  /// [sharePositionOrigin] iPad等で共有ポップオーバーを表示するアンカー矩形
  Future<Result<void, AppError>> shareFiles(
    List<XFile> files, {
    String? text,
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    final result = await shareFilesWithStatus(
      files,
      text: text,
      subject: subject,
      sharePositionOrigin: sharePositionOrigin,
    );
    return result.isFailure
        ? Result.failure(result.errorOrNull!)
        : Result.success(null);
  }

  /// ファイル共有の完了・キャンセルを呼び出し側で区別する。
  Future<Result<AppShareStatus, AppError>> shareFilesWithStatus(
    List<XFile> files, {
    String? text,
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    if (files.isEmpty) {
      return Result.failure(AppError.validation('シェアするファイルがありません'));
    }

    try {
      AppLogger.d(LogTag.share, 'Sharing ${files.length} file(s)');

      final result = await SharePlus.instance.share(
        ShareParams(
          files: files,
          text: text,
          subject: subject,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );

      if (result.status == ShareResultStatus.success) {
        AppLogger.i(LogTag.share, 'Files shared successfully');
        return Result.success(AppShareStatus.completed);
      } else if (result.status == ShareResultStatus.dismissed) {
        AppLogger.d(LogTag.share, 'Share dismissed by user');
        return Result.success(AppShareStatus.dismissed);
      }
      return Result.success(AppShareStatus.unavailable);
    } catch (e, st) {
      AppLogger.e(LogTag.share, 'Failed to share files', e, st);
      return Result.failure(
        AppError.unknown('ファイルのシェアに失敗しました', original: e, stackTrace: st),
      );
    }
  }

  /// URIをシェア（iOS/macOS向けに最適化）
  ///
  /// [uri] シェアするURI
  /// [sharePositionOrigin] iPad等で共有ポップオーバーを表示するアンカー矩形
  Future<Result<void, AppError>> shareUri(
    Uri uri, {
    Rect? sharePositionOrigin,
  }) async {
    try {
      AppLogger.d(LogTag.share, 'Sharing URI: $uri');

      final result = await SharePlus.instance.share(
        ShareParams(uri: uri, sharePositionOrigin: sharePositionOrigin),
      );

      if (result.status == ShareResultStatus.success) {
        AppLogger.i(LogTag.share, 'URI shared successfully');
      } else if (result.status == ShareResultStatus.dismissed) {
        AppLogger.d(LogTag.share, 'Share dismissed by user');
      }

      return Result.success(null);
    } catch (e, st) {
      AppLogger.e(LogTag.share, 'Failed to share URI', e, st);
      return Result.failure(
        AppError.unknown('URLのシェアに失敗しました', original: e, stackTrace: st),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// ShareService のProvider
final shareServiceProvider = Provider<ShareService>((ref) {
  return ShareService();
});
