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
import 'package:private_shelf/features/library/domain/models/media_format_utils.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/utils/archive_metadata_utils.dart';
import 'package:private_shelf/features/library/presentation/providers/external_file_preview_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

/// アプリ内表示に対応していないファイル形式向けのプレビュー＆アクション画面
class UnsupportedFileView extends ConsumerStatefulWidget {
  final MediaItem item;

  const UnsupportedFileView({super.key, required this.item});

  @override
  ConsumerState<UnsupportedFileView> createState() =>
      _UnsupportedFileViewState();
}

class _UnsupportedFileViewState extends ConsumerState<UnsupportedFileView> {
  bool _isOpening = false;
  bool _isSharing = false;
  ArchiveMetadata? _archiveMetadata;

  @override
  void initState() {
    super.initState();
    if (widget.item.isArchive) {
      _loadArchiveMetadata();
    }
  }

  Future<void> _loadArchiveMetadata() async {
    final file = await _resolveFile();
    if (file != null && mounted) {
      final meta = await ArchiveMetadataUtils.inspectZipFile(file);
      if (meta != null && mounted) {
        setState(() => _archiveMetadata = meta);
      }
    }
  }

  IconData _getIconForFile(String path) {
    final ext = MediaFormatUtils.resolveExtension(path);
    if (ext == '.pdf') {
      return Icons.picture_as_pdf_rounded;
    } else if ({'.doc', '.docx', '.pages', '.rtf'}.contains(ext)) {
      return Icons.description_rounded;
    } else if ({'.xls', '.xlsx', '.numbers', '.csv'}.contains(ext)) {
      return Icons.table_chart_rounded;
    } else if ({'.ppt', '.pptx', '.key'}.contains(ext)) {
      return Icons.slideshow_rounded;
    } else if (MediaFormatUtils.isArchive(path)) {
      return Icons.folder_zip_rounded;
    } else if (MediaFormatUtils.isAudio(path)) {
      return Icons.audio_file_rounded;
    } else if (MediaFormatUtils.isVideo(path)) {
      return Icons.video_file_rounded;
    } else if (MediaFormatUtils.isImage(path)) {
      return Icons.image_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    var size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }

  Future<File?> _resolveFile() async {
    if (widget.item.requiresSourceAccess) {
      final tempPath = await ref.read(
        externalFilePreviewProvider(widget.item).future,
      );
      if (tempPath != null) {
        final file = File(tempPath);
        if (await file.exists()) return file;
      }
      return null;
    } else {
      final docsPath = ref.read(appDocumentsPathSyncProvider);
      final file = File(p.join(docsPath, widget.item.path));
      if (await file.exists()) return file;
      return null;
    }
  }

  Future<void> _handleOpenWithExternalApp() async {
    if (_isOpening) return;
    setState(() => _isOpening = true);
    final l10n = AppLocalizations.of(context)!;

    try {
      if (widget.item.requiresSourceAccess) {
        final storageService = await ref.read(
          externalStorageServiceProvider.future,
        );
        var uri = Uri.tryParse(widget.item.path);
        if (uri == null || !uri.hasScheme) {
          uri = Uri.file(widget.item.path);
        }
        final success = await storageService.openWithSystem(uri);
        if (!success && mounted) {
          final file = await _resolveFile();
          if (file != null) {
            await OpenFile.open(file.path);
          } else if (mounted) {
            AppSnackBarMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.viewerError(l10n.viewerFileNotFound)),
              ),
            );
          }
        }
      } else {
        final file = await _resolveFile();
        if (file != null) {
          final result = await OpenFile.open(file.path);
          if (result.type != ResultType.done && mounted) {
            AppSnackBarMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.errorFile)));
          }
        } else if (mounted) {
          AppSnackBarMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.viewerError(l10n.viewerFileNotFound))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBarMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userSafeErrorMessage(e, l10n))));
      }
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }

  Future<void> _handleShare() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    final l10n = AppLocalizations.of(context)!;

    try {
      final file = await _resolveFile();
      if (file != null) {
        final shareService = ref.read(shareServiceProvider);
        final box = mounted ? context.findRenderObject() as RenderBox? : null;
        final origin = box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null;
        final result = await shareService.shareFiles([
          XFile(file.path),
        ], sharePositionOrigin: origin);
        if (result.isFailure && mounted) {
          AppSnackBarMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userSafeErrorMessage(result.errorOrNull, l10n)),
            ),
          );
        }
      } else if (mounted) {
        AppSnackBarMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.viewerError(l10n.viewerFileNotFound))),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBarMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userSafeErrorMessage(e, l10n))));
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final fileName = p.basename(
      widget.item.originalPath.isNotEmpty
          ? widget.item.originalPath
          : widget.item.path,
    );
    final ext = MediaFormatUtils.resolveExtension(
      widget.item.path,
      originalPath: widget.item.originalPath,
    ).toUpperCase().replaceAll('.', '');
    final iconData = _getIconForFile(widget.item.path);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData,
                color: colorScheme.onSurface.withValues(alpha: 0.8),
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              fileName,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ext.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ext,
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (widget.item.size != null) ...[
                  Text(
                    _formatBytes(widget.item.size!),
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (_archiveMetadata != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_archiveMetadata!.entryCount} files',
                      style: TextStyle(
                        color: colorScheme.onSecondaryContainer,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.viewerUnsupportedFileType,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: _isOpening ? null : _handleOpenWithExternalApp,
                    icon: _isOpening
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.open_in_new_rounded, size: 20),
                    label: Text(l10n.viewerOpenExternal),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isSharing ? null : _handleShare,
                    icon: _isSharing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.share_rounded, size: 20),
                    label: Text(l10n.viewerShare),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
