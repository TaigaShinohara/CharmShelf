import 'dart:io';
import 'content_ready.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/viewer_page.dart';
import 'package:private_shelf/features/library/presentation/helpers/external_file_action_helper.dart';
import 'package:private_shelf/features/library/presentation/providers/viewer_pages_provider.dart';
import 'package:private_shelf/features/library/presentation/utils/image_cache_helper.dart';
import 'package:private_shelf/features/library/presentation/widgets/viewer_state_panel.dart';
import 'package:private_shelf/features/library/presentation/widgets/viewer/swipe_friendly_interactive_viewer.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

class MediaImageViewer extends ConsumerWidget {
  final File file;
  final MediaItem item;
  final SplitSide? splitSide;
  final bool isInitialHero;
  final VoidCallback onTap;
  final VoidCallback? onContentReady;
  final GestureDragStartCallback? onUnscaledHorizontalDragStart;
  final GestureDragUpdateCallback? onUnscaledHorizontalDragUpdate;
  final GestureDragEndCallback? onUnscaledHorizontalDragEnd;
  final GestureDragCancelCallback? onUnscaledHorizontalDragCancel;

  const MediaImageViewer({
    super.key,
    required this.file,
    required this.item,
    this.splitSide,
    this.isInitialHero = false,
    required this.onTap,
    this.onContentReady,
    this.onUnscaledHorizontalDragStart,
    this.onUnscaledHorizontalDragUpdate,
    this.onUnscaledHorizontalDragEnd,
    this.onUnscaledHorizontalDragCancel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!file.existsSync()) {
      return ViewerStatePanel(
        kind: ViewerFailureKind.missing,
        onOpenExternal: () => ExternalFileActionHelper.openWithExternalApp(
          context: context,
          ref: ref,
          item: item,
          fallbackFile: file,
        ),
        onShare: () => ExternalFileActionHelper.shareFile(
          context: context,
          ref: ref,
          item: item,
          fallbackFile: file,
        ),
      );
    }

    final Widget content;

    if (item.isSvg) {
      content = SwipeFriendlyInteractiveViewer(
        minScale: 1.0,
        maxScale: 6.0,
        onTap: onTap,
        onUnscaledHorizontalDragStart: onUnscaledHorizontalDragStart,
        onUnscaledHorizontalDragUpdate: onUnscaledHorizontalDragUpdate,
        onUnscaledHorizontalDragEnd: onUnscaledHorizontalDragEnd,
        onUnscaledHorizontalDragCancel: onUnscaledHorizontalDragCancel,
        child: SvgPicture.file(
          file,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          placeholderBuilder: (context) =>
              const Center(child: CircularProgressIndicator()),
          imageBuilder: (context, child) {
            reportViewerContentReady(context, onContentReady);
            return child;
          },
          errorBuilder: (context, error, stackTrace) {
            AppLogger.e(
              LogTag.ui,
              '[SvgDecodeTrace] viewer Svg decode failed path=${file.path} itemId=${item.id}',
              error,
              stackTrace,
            );
            return ViewerStatePanel(
              kind: ViewerFailureKind.decodeFailed,
              onOpenExternal: () =>
                  ExternalFileActionHelper.openWithExternalApp(
                    context: context,
                    ref: ref,
                    item: item,
                    fallbackFile: file,
                  ),
              onShare: () => ExternalFileActionHelper.shareFile(
                context: context,
                ref: ref,
                item: item,
                fallbackFile: file,
              ),
            );
          },
        ),
      );
    } else if (splitSide == null) {
      final targetLimit = calculateTargetImageLimit(context);
      final cachedRatio = getCachedImageAspectRatio(file);
      final imageProvider = getImageProviderForFile(
        file: file,
        aspectRatio: cachedRatio,
        targetLimit: targetLimit,
      );

      content = SwipeFriendlyInteractiveViewer(
        minScale: 1.0,
        maxScale: 4.0,
        onTap: onTap,
        onUnscaledHorizontalDragStart: onUnscaledHorizontalDragStart,
        onUnscaledHorizontalDragUpdate: onUnscaledHorizontalDragUpdate,
        onUnscaledHorizontalDragEnd: onUnscaledHorizontalDragEnd,
        onUnscaledHorizontalDragCancel: onUnscaledHorizontalDragCancel,
        child: Image(
          image: imageProvider,
          gaplessPlayback: true,
          filterQuality: FilterQuality.low,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) {
              reportViewerContentReady(context, onContentReady);
              return child;
            }
            return const SizedBox.expand();
          },
          errorBuilder: (context, error, stackTrace) {
            AppLogger.e(
              LogTag.ui,
              '[ImageDecodeTrace] viewer Image decode failed path=${file.path} itemId=${item.id} source=${item.sourceType.name} split=${splitSide?.name ?? 'none'} ext=${p.extension(file.path).toLowerCase()}',
              error,
              stackTrace,
            );
            final isMissing = !file.existsSync();
            return ViewerStatePanel(
              kind: isMissing
                  ? ViewerFailureKind.missing
                  : ViewerFailureKind.decodeFailed,
              onOpenExternal: () =>
                  ExternalFileActionHelper.openWithExternalApp(
                    context: context,
                    ref: ref,
                    item: item,
                    fallbackFile: file,
                  ),
              onShare: () => ExternalFileActionHelper.shareFile(
                context: context,
                ref: ref,
                item: item,
                fallbackFile: file,
              ),
            );
          },
        ),
      );
    } else {
      final targetLimit = calculateTargetImageLimit(context);
      final cachedRatio = getCachedImageAspectRatio(file);
      final imageProvider = getImageProviderForFile(
        file: file,
        aspectRatio: cachedRatio,
        targetLimit: targetLimit,
      );
      final baseRatio = cachedRatio ?? 2.0;
      final pageRatio =
          (baseRatio <= 0.0 || baseRatio.isNaN || baseRatio.isInfinite)
          ? 1.0
          : baseRatio / 2.0;
      final alignment = splitSide == SplitSide.left
          ? Alignment.centerLeft
          : Alignment.centerRight;

      content = Center(
        child: SwipeFriendlyInteractiveViewer(
          minScale: 1.0,
          maxScale: 4.0,
          onTap: onTap,
          onUnscaledHorizontalDragStart: onUnscaledHorizontalDragStart,
          onUnscaledHorizontalDragUpdate: onUnscaledHorizontalDragUpdate,
          onUnscaledHorizontalDragEnd: onUnscaledHorizontalDragEnd,
          onUnscaledHorizontalDragCancel: onUnscaledHorizontalDragCancel,
          child: AspectRatio(
            aspectRatio: pageRatio,
            child: ClipRect(
              child: Image(
                image: imageProvider,
                gaplessPlayback: true,
                filterQuality: FilterQuality.low,
                fit: BoxFit.fitHeight,
                alignment: alignment,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) {
                    reportViewerContentReady(context, onContentReady);
                    return child;
                  }
                  return const SizedBox.expand();
                },
                errorBuilder: (context, error, stackTrace) {
                  AppLogger.e(
                    LogTag.ui,
                    '[ImageDecodeTrace] viewer split Image decode failed path=${file.path} itemId=${item.id} source=${item.sourceType.name} split=${splitSide?.name} ext=${p.extension(file.path).toLowerCase()}',
                    error,
                    stackTrace,
                  );
                  final isMissing = !file.existsSync();
                  return ViewerStatePanel(
                    kind: isMissing
                        ? ViewerFailureKind.missing
                        : ViewerFailureKind.decodeFailed,
                    onOpenExternal: () =>
                        ExternalFileActionHelper.openWithExternalApp(
                          context: context,
                          ref: ref,
                          item: item,
                          fallbackFile: file,
                        ),
                    onShare: () => ExternalFileActionHelper.shareFile(
                      context: context,
                      ref: ref,
                      item: item,
                      fallbackFile: file,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final name = p.basename(file.path);
    final semanticLabel = switch (splitSide) {
      SplitSide.left => l10n.viewerImageSemanticsLabelLeft(name),
      SplitSide.right => l10n.viewerImageSemanticsLabelRight(name),
      null => l10n.viewerImageSemanticsLabel(name),
    };
    final accessibleContent = Semantics(
      container: true,
      image: true,
      button: true,
      label: semanticLabel,
      hint: l10n.viewerImageSemanticsHint,
      onTap: onTap,
      child: content,
    );

    if (isInitialHero && splitSide != SplitSide.right) {
      return Hero(
        tag: 'media_${item.id}_${item.path}',
        child: accessibleContent,
      );
    }

    return accessibleContent;
  }
}
