import 'dart:async';
import 'dart:io';

import 'viewer/content_ready.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:material_ui/material_ui.dart' as mui;
import 'package:pdfrx/pdfrx.dart' as pdfrx;

import 'package:private_shelf/core/error/user_safe_error_message.dart';
import 'package:private_shelf/core/feedback/haptics_service.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/helpers/external_file_action_helper.dart';
import 'package:private_shelf/features/library/presentation/helpers/pdf_external_link_helper.dart';
import 'package:private_shelf/features/library/presentation/helpers/pdf_password_prompt.dart';
import 'package:private_shelf/features/library/presentation/providers/external_file_preview_provider.dart';
import 'package:private_shelf/features/library/presentation/widgets/viewer_state_panel.dart';
import 'package:private_shelf/features/library/presentation/widgets/viewer/pdf_selection_handle.dart';
import 'package:private_shelf/features/library/presentation/widgets/viewer/pdf_file_swipe_region.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

/// PDFファイルのプレビュー表示ウィジェット
class PdfViewer extends ConsumerStatefulWidget {
  final MediaItem item;
  final VoidCallback? onTap;
  final VoidCallback? onContentReady;
  final GestureDragStartCallback? onUnscaledHorizontalDragStart;
  final GestureDragUpdateCallback? onUnscaledHorizontalDragUpdate;
  final GestureDragEndCallback? onUnscaledHorizontalDragEnd;
  final GestureDragCancelCallback? onUnscaledHorizontalDragCancel;

  const PdfViewer({
    super.key,
    required this.item,
    this.onTap,
    this.onContentReady,
    this.onUnscaledHorizontalDragStart,
    this.onUnscaledHorizontalDragUpdate,
    this.onUnscaledHorizontalDragEnd,
    this.onUnscaledHorizontalDragCancel,
  });

  @override
  ConsumerState<PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends ConsumerState<PdfViewer> {
  final _pdfViewerController = pdfrx.PdfViewerController();
  int _loadGeneration = 0;
  bool _loadFailed = false;
  String? _errorMessage;
  PdfPasswordPrompt? _passwordPrompt;
  String? _passwordFilePath;
  bool _rendered = false;
  pdfrx.PdfLink? _pressedLink;
  Timer? _linkFeedbackTimer;

  bool _canStartFileSwipe() {
    if (!_pdfViewerController.isReady) return true;
    if (_pdfViewerController.textSelectionDelegate.textSelectionPointRange !=
        null) {
      return false;
    }
    if (!_rendered) return true;
    final fit = _pdfViewerController.calcMatrixFitWidthForPage(
      pageNumber: _pdfViewerController.pageNumber ?? 1,
    );
    return fit != null &&
        _pdfViewerController.currentZoom <= fit.getMaxScaleOnAxis() * 1.01;
  }

  void _clearLinkFeedback() {
    _linkFeedbackTimer?.cancel();
    _linkFeedbackTimer = null;
    _pressedLink = null;
  }

  void _flashLink(pdfrx.PdfLink link) {
    _clearLinkFeedback();
    setState(() => _pressedLink = link);
    unawaited(HapticsService.selectionClick());
    _linkFeedbackTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _pressedLink = null);
    });
  }

  Future<void> _handleLinkTap(pdfrx.PdfLink link) async {
    final destination = link.dest;
    if (destination != null && _pdfViewerController.isReady) {
      _flashLink(link);
      final generation = _loadGeneration;
      final prompt = _passwordPrompt;
      var succeeded = false;
      try {
        succeeded = await _pdfViewerController.goToDest(destination);
      } catch (_) {
        // Do not put document destinations or URLs into logs.
      }
      if (!mounted ||
          generation != _loadGeneration ||
          !identical(prompt, _passwordPrompt)) {
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1200),
          content: Text(
            succeeded
                ? l10n.viewerPagePosition(
                    destination.pageNumber,
                    _pdfViewerController.pageCount,
                  )
                : l10n.commonErrorOccurred,
          ),
        ),
      );
      return;
    }
    final uri = link.url;
    if (uri != null && isAllowedPdfExternalLink(uri)) {
      _flashLink(link);
      await openPdfExternalLink(context, uri);
    }
  }

  void _cancelPasswordPrompt() {
    _rendered = false;
    _passwordPrompt?.cancel();
    _passwordPrompt = null;
    _passwordFilePath = null;
  }

  PdfPasswordPrompt _passwordPromptForFile(String path) {
    if (_passwordPrompt == null || _passwordFilePath != path) {
      _cancelPasswordPrompt();
      _passwordFilePath = path;
      _passwordPrompt = PdfPasswordPrompt();
    }
    return _passwordPrompt!;
  }

  @override
  void dispose() {
    _clearLinkFeedback();
    _cancelPasswordPrompt();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PdfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.path != widget.item.path) {
      _clearLinkFeedback();
      _cancelPasswordPrompt();
      _loadFailed = false;
      _errorMessage = null;
      _loadGeneration++;
    }
  }

  void _onLoadFailed(
    Object error,
    String path,
    int generation,
    PdfPasswordPrompt prompt,
  ) {
    // The viewer can finish loading while its parent is building or switching
    // files. Never apply an old document's failure to the current document.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.item.path != path ||
          _loadGeneration != generation ||
          !identical(_passwordPrompt, prompt)) {
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
    _clearLinkFeedback();
    _cancelPasswordPrompt();
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
    // The native PDF owns annotation/selection taps while it is rendered. This
    // fallback restores toolbar access on loading and failure panels as well;
    // their action buttons still win their own tap gestures.
    final content = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.onTap,
      child: _buildContent(context),
    );
    if (widget.onUnscaledHorizontalDragStart == null ||
        widget.onUnscaledHorizontalDragUpdate == null ||
        widget.onUnscaledHorizontalDragEnd == null ||
        widget.onUnscaledHorizontalDragCancel == null) {
      return content;
    }
    return PdfFileSwipeRegion(
      canStart: _canStartFileSwipe,
      onStart: widget.onUnscaledHorizontalDragStart!,
      onUpdate: widget.onUnscaledHorizontalDragUpdate!,
      onEnd: widget.onUnscaledHorizontalDragEnd!,
      onCancel: widget.onUnscaledHorizontalDragCancel!,
      child: content,
    );
  }

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loadFailed) {
      _cancelPasswordPrompt();
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
          _cancelPasswordPrompt();
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
        loading: () {
          _cancelPasswordPrompt();
          return const Center(child: CircularProgressIndicator());
        },
        error: (err, _) {
          _cancelPasswordPrompt();
          return ViewerStatePanel(
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
          );
        },
      );
    }

    final docsPath = ref.watch(appDocumentsPathSyncProvider);
    final file = File(p.join(docsPath, widget.item.path));
    if (!file.existsSync()) {
      _cancelPasswordPrompt();
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
    final passwordPrompt = _passwordPromptForFile(file.path);
    // The file renderer owns its document handle. The existing preview provider
    // owns external copies; do not create another PDF copy or delete the source.
    final viewer = pdfrx.PdfViewer(
      pdfrx.PdfDocumentRefFile(
        file.path,
        // A cached reference must never borrow another viewer's UI callback.
        key: pdfrx.PdfDocumentRefKey(file.path, [generation, passwordPrompt]),
        passwordProvider: () => passwordPrompt.request(context),
      ),
      key: ValueKey((file.path, generation)),
      controller: _pdfViewerController,
      params: pdfrx.PdfViewerParams(
        backgroundColor: theme.colorScheme.surface,
        textSelectionParams: pdfrx.PdfTextSelectionParams(
          buildSelectionHandle: (_, anchor, _) => PdfSelectionHandle(
            isStart: anchor.type == pdfrx.PdfTextSelectionAnchorType.a,
            color: theme.colorScheme.primary,
          ),
          calcSelectionHandleOffset: PdfSelectionHandle.offset,
        ),
        onDocumentLoadFinished: (documentRef, succeeded) {
          if (!succeeded) {
            _onLoadFailed(
              documentRef.resolveListenable().error ??
                  const FormatException('PDF could not be loaded'),
              itemPath,
              generation,
              passwordPrompt,
            );
          } else if (mounted &&
              widget.item.path == itemPath &&
              _loadGeneration == generation &&
              identical(_passwordPrompt, passwordPrompt)) {
            // pdfrx waits for the initial page image before reporting success.
            _rendered = true;
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
          onLinkTap: (link) => unawaited(_handleLinkTap(link)),
          customPainter: (canvas, pageRect, page, links) {
            for (final link in links) {
              final pressed = identical(link, _pressedLink);
              for (final rect in link.rects) {
                final bounds = RRect.fromRectAndRadius(
                  rect.toRectInDocument(page: page, pageRect: pageRect),
                  const Radius.circular(3),
                );
                canvas.drawRRect(
                  bounds,
                  Paint()
                    ..color = pressed
                        ? theme.colorScheme.primary.withValues(alpha: 0.35)
                        : Colors.blue.withValues(alpha: 0.2),
                );
                if (pressed) {
                  canvas.drawRRect(
                    bounds,
                    Paint()
                      ..color = theme.colorScheme.primary
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 2,
                  );
                }
              }
            }
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
