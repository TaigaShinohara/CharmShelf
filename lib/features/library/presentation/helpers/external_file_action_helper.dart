import 'dart:io';
import 'package:flutter/material.dart';
import 'package:private_shelf/shared/widgets/feedback/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import 'package:private_shelf/core/error/user_safe_error_message.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/core/services/share_service.dart';
import 'package:private_shelf/features/library/data/services/external_storage_service.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/external_file_preview_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

/// 各メディアビューアから安全に外部アプリ起動およびファイル共有を行うための共通ヘルパークラス
class ExternalFileActionHelper {
  ExternalFileActionHelper._();

  /// 対象の `File` 実体を取得
  static Future<File?> resolveFile({
    required WidgetRef ref,
    required MediaItem item,
    File? fallbackFile,
  }) async {
    if (fallbackFile != null && await fallbackFile.exists()) {
      return fallbackFile;
    }

    if (item.sourceType == MediaSourceType.externalReference) {
      final tempPath = await ref.read(externalFilePreviewProvider(item).future);
      if (tempPath != null) {
        final file = File(tempPath);
        if (await file.exists()) return file;
      }
      return null;
    } else {
      final docsPath = ref.read(appDocumentsPathSyncProvider);
      final file = File(p.join(docsPath, item.path));
      if (await file.exists()) return file;
      return null;
    }
  }

  /// 外部アプリ（システム既定または対応アプリ）でファイルを開く
  static Future<void> openWithExternalApp({
    required BuildContext context,
    required WidgetRef ref,
    required MediaItem item,
    File? fallbackFile,
  }) async {
    final l10n = AppLocalizations.of(context)!;

    try {
      if (item.sourceType == MediaSourceType.externalReference) {
        final storageService = await ref.read(
          externalStorageServiceProvider.future,
        );
        var uri = Uri.tryParse(item.path);
        if (uri == null || !uri.hasScheme) {
          uri = Uri.file(item.path);
        }
        final success = await storageService.openWithSystem(uri);
        if (!success && context.mounted) {
          final file = await resolveFile(
            ref: ref,
            item: item,
            fallbackFile: fallbackFile,
          );
          if (file != null) {
            await OpenFile.open(file.path);
          } else if (context.mounted) {
            AppSnackBarMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.viewerError(l10n.viewerFileNotFound)),
              ),
            );
          }
        }
      } else {
        final file = await resolveFile(
          ref: ref,
          item: item,
          fallbackFile: fallbackFile,
        );
        if (file != null) {
          final result = await OpenFile.open(file.path);
          if (result.type != ResultType.done && context.mounted) {
            AppSnackBarMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.errorFile)));
          }
        } else if (context.mounted) {
          AppSnackBarMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.viewerError(l10n.viewerFileNotFound))),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBarMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userSafeErrorMessage(e, l10n))));
      }
    }
  }

  /// ファイル共有ダイアログを表示
  static Future<void> shareFile({
    required BuildContext context,
    required WidgetRef ref,
    required MediaItem item,
    File? fallbackFile,
  }) async {
    final l10n = AppLocalizations.of(context)!;

    try {
      final file = await resolveFile(
        ref: ref,
        item: item,
        fallbackFile: fallbackFile,
      );
      if (file != null) {
        final shareService = ref.read(shareServiceProvider);
        final box = context.mounted
            ? context.findRenderObject() as RenderBox?
            : null;
        final origin = box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null;
        final result = await shareService.shareFiles([
          XFile(file.path),
        ], sharePositionOrigin: origin);
        if (result.isFailure && context.mounted) {
          AppSnackBarMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userSafeErrorMessage(result.errorOrNull, l10n)),
            ),
          );
        }
      } else if (context.mounted) {
        AppSnackBarMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.viewerError(l10n.viewerFileNotFound))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBarMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userSafeErrorMessage(e, l10n))));
      }
    }
  }
}
