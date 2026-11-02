import 'dart:async';
import 'dart:io';
import 'viewer/content_ready.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:material_ui/material_ui.dart' as mui;
import 'package:pdfrx/pdfrx.dart' as pdfrx;

import 'package:private_shelf/core/error/user_safe_error_message.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/helpers/external_file_action_helper.dart';
import 'package:private_shelf/features/library/presentation/helpers/pdf_external_link_helper.dart';
import 'package:private_shelf/features/library/presentation/providers/external_file_preview_provider.dart';
import 'package:private_shelf/features/library/presentation/widgets/viewer_state_panel.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

/// PDFファイルのプレビュー表示ウィジェット
class PdfViewer extends ConsumerStatefulWidget {
  final MediaItem item;
  final VoidCallback? onTap;
  final VoidCallback? onContentReady;

  const PdfViewer({
    super.key,
    required this.item,
    this.onTap,
    this.onContentReady,
  });

  @override
  ConsumerState<PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends ConsumerState<PdfViewer> {
  final _pdfViewerController = pdfrx.PdfViewerController();
  int _loadGeneration = 0;
  bool _loadFailed = false;
  String? _errorMessage;

  @override
  void didUpdateWidget(covariant PdfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.path != widget.item.path) {
      _loadFailed = false;
      _errorMessage = null;
      _loadGeneration++;
    }
  }

  void _onLoadFailed(Object error, String path, int generation) {
    // The viewer can finish loading while its parent is building or switching
    // files. Never apply an old document's failure to the current document.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.item.path != path ||
          _loadGeneration != generation) {
        return;
      }
      AppLogger.e(LogTag.app, 'PDF読み込みエラー', error);
      setState(() {
        _loadFailed = true;
        _errorMessage = error.toString();
      });
    });
  }

  void _retry() {
    setState(() {
      _loadFailed = false;
      _errorMessage = null;
      _loadGeneration++;
    });
    if (widget.item.requiresSourceAccess) {
      ref.invalidate(externalFilePreviewProvider(widget.item));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loadFailed) {
      return ViewerStatePanel(
        kind: ViewerFailureKind.decodeFailed,
        message: _errorMessage != null
            ? userSafeErrorMessage(Exception(_errorMessage), l10n)
            : null,
        onRetry: _retry,
        onOpenExternal: () => ExternalFileActionHelper.openWithExternalApp(
          context: context,
          ref: ref,
          item: widget.item,
        ),
        onShare: () => ExternalFileActionHelper.shareFile(
          context: context,
          ref: ref,
          item: widget.item,
        ),
      );
    }

    if (widget.item.requiresSourceAccess) {
      final previewAsync = ref.watch(externalFilePreviewProvider(widget.item));
      return previewAsync.when(
        data: (tempPath) {
          if (tempPath != null) {
            final file = File(tempPath);
            return _buildFileViewer(context, file);
          }
          return ViewerStatePanel(
            kind: ViewerFailureKind.missing,
            onRetry: _retry,
            onOpenExternal: () => ExternalFileActionHelper.openWithExternalApp(
              context: context,
              ref: ref,
              item: widget.item,
            ),
            onShare: () => ExternalFileActionHelper.shareFile(
              context: context,
              ref: ref,
              item: widget.item,
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ViewerStatePanel(
          kind: ViewerFailureKind.unknown,
          message: userSafeErrorMessage(err, l10n),
          onRetry: _retry,
          onOpenExternal: () => ExternalFileActionHelper.openWithExternalApp(
            context: context,
            ref: ref,
            item: widget.item,
          ),
          onShare: () => ExternalFileActionHelper.shareFile(
            context: context,
            ref: ref,
            item: widget.item,
          ),
        ),
      );
    }

    final docsPath = ref.watch(appDocumentsPathSyncProvider);
    final file = File(p.join(docsPath, widget.item.path));
    if (!file.existsSync()) {
      return ViewerStatePanel(
        kind: ViewerFailureKind.missing,
        onRetry: _retry,
        onOpenExternal: () => ExternalFileActionHelper.openWithExternalApp(
          context: context,
          ref: ref,
          item: widget.item,
          fallbackFile: file,
        ),
        onShare: () => ExternalFileActionHelper.shareFile(
          context: context,
          ref: ref,
          item: widget.item,
          fallbackFile: file,
        ),
      );
    }
    return _buildFileViewer(context, file);
  }

  Widget _buildFileViewer(BuildContext context, File file) {
    final theme = Theme.of(context);
    final itemPath = widget.item.path;
    final generation = _loadGeneration;
    // The file renderer owns its document handle. The existing preview provider
    // owns external copies; do not create another PDF copy or delete the source.
    final viewer = pdfrx.PdfViewer(
      pdfrx.PdfDocumentRefFile(
        file.path,
        key: pdfrx.PdfDocumentRefKey(file.path, [generation]),
      ),
      key: ValueKey((file.path, generation)),
      controller: _pdfViewerController,
      params: pdfrx.PdfViewerParams(
        backgroundColor: theme.colorScheme.surface,
        onDocumentLoadFinished: (documentRef, succeeded) {
          if (!succeeded) {
            _onLoadFailed(
              documentRef.resolveListenable().error ??
                  const FormatException('PDF could not be loaded'),
              itemPath,
              generation,
            );
          } else if (mounted &&
              widget.item.path == itemPath &&
              _loadGeneration == generation) {
            // pdfrx waits for the initial page image before reporting success.
            reportViewerContentReady(context, widget.onContentReady);
          }
        },
        errorBannerBuilder: (_, _, _, _) => const SizedBox.shrink(),
        onGeneralTap: (_, _, details) {
          if (details.type == pdfrx.PdfViewerGeneralTapType.tap) {
            widget.onTap?.call();
          }
          return false;
        },
        linkHandlerParams: pdfrx.PdfLinkHandlerParams(
          enableAutoLinkDetection: false,
          onLinkTap: (link) {
            final destination = link.dest;
            if (destination != null && _pdfViewerController.isReady) {
              unawaited(_pdfViewerController.goToDest(destination));
              return;
            }
            final uri = link.url;
            if (uri != null) unawaited(openPdfExternalLink(context, uri));
          },
        ),
      ),
    );
    // pdfrx uses the extracted Material UI types. Supply these locally so its
    // selection menus follow the app's Japanese/English locale and brightness.
    return Localizations.override(
      context: context,
      delegates: const [mui.GlobalMaterialLocalizations.delegate],
      child: mui.Theme(
        data: mui.ThemeData(
          colorScheme: mui.ColorScheme.fromSeed(
            seedColor: theme.colorScheme.primary,
            brightness: theme.brightness,
          ),
        ),
        child: viewer,
      ),
    );
  }
}
