import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/core/router/app_router.dart';
import 'package:private_shelf/core/utils/date_time_utils.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/viewer_source_context.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/external_thumbnail_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/catalog_resume_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/secret_mode_provider.dart';
import 'package:private_shelf/core/providers/tab_navigation_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

class ResumeBanner extends ConsumerStatefulWidget {
  const ResumeBanner({super.key, required this.collection});
  final MediaCollection collection;

  @override
  ConsumerState<ResumeBanner> createState() => _ResumeBannerState();
}

class _ResumeOpenPopEntry extends PopEntry<Object?> {
  _ResumeOpenPopEntry(this.cancel);
  final VoidCallback cancel;
  @override
  final ValueNotifier<bool> canPopNotifier = ValueNotifier(true);
  @override
  void onPopInvokedWithResult(bool didPop, Object? result) => cancel();
}

class _ResumeBannerState extends ConsumerState<ResumeBanner> {
  Object? _openingToken;
  ModalRoute<dynamic>? _openingRoute;
  CatalogResumeRequest? _boundRequest;
  bool _readFailed = false;
  bool _openFailed = false;

  CatalogResumeRequest? get _request {
    final collection = widget.collection;
    final id = collection.lastViewedItemId;
    if (!collection.isCatalog || id == null) return null;
    return (
      collectionId: collection.id,
      collectionPath: collection.path,
      itemId: id,
    );
  }

  @override
  void initState() {
    super.initState();
    _boundRequest = _request;
  }

  void _cancelOpening() {
    _openingToken = null;
    _openingRoute = null;
    if (mounted) {
      setState(() {
        _readFailed = false;
        _openFailed = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ModalRoute notifies dependents when another route covers this screen.
    // Even a quick visit and return cancels the pending activation.
    if (_openingToken != null && _openingRoute?.isCurrent == false) {
      _openingToken = null;
      _openingRoute = null;
      _readFailed = false;
      _openFailed = false;
    }
  }

  @override
  void didUpdateWidget(covariant ResumeBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_boundRequest != _request) {
      _openingToken = null;
      _openingRoute = null;
      _readFailed = false;
      _openFailed = false;
      _boundRequest = _request;
    }
  }

  Future<void> _open(CatalogResumeTarget displayed) async {
    final request = _request;
    if (_openingToken != null || request == null) return;
    final token = Object();
    final mode = ref.read(appModeProvider);
    final includeHidden = ref.read(secretModeProvider).asData?.value ?? false;
    final tab = ref.read(currentTabIndexProvider);
    final route = ModalRoute.of(context);
    final popEntry = _ResumeOpenPopEntry(_cancelOpening);
    route?.registerPopEntry(popEntry);
    setState(() {
      _openingToken = token;
      _openingRoute = route;
      _readFailed = false;
      _openFailed = false;
    });
    bool isCurrent() =>
        mounted &&
        identical(_openingToken, token) &&
        _request == request &&
        mode == ref.read(appModeProvider) &&
        includeHidden ==
            (ref.read(secretModeProvider).asData?.value ?? false) &&
        tab == ref.read(currentTabIndexProvider) &&
        (route == null || route.isCurrent);
    var resolved = false;
    try {
      final repository = await ref.read(mediaRepositoryProvider.future);
      if (!isCurrent()) return;
      final target = await resolveCatalogResumeTarget(
        repository,
        request,
        includeHidden: includeHidden,
      );
      if (!mounted || !isCurrent()) return;
      if (target == null ||
          target.item.id != displayed.item.id ||
          target.item.path != displayed.item.path) {
        ref.invalidate(catalogResumeTargetProvider(request));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.resumeBannerUnavailable,
            ),
          ),
        );
        return;
      }
      resolved = true;
      await MediaViewerRoute(
        id: target.item.id,
        $extra: ViewerRouteArgs(
          initialItem: target.item,
          sourceContext: ViewerSourceContext.folder(
            parentPath: target.item.parentPath,
            appMode: mode,
          ),
        ),
      ).push<void>(context);
    } catch (_) {
      if (isCurrent()) {
        setState(() {
          _readFailed = !resolved;
          _openFailed = resolved;
        });
      }
    } finally {
      route?.unregisterPopEntry(popEntry);
      popEntry.canPopNotifier.dispose();
      if (mounted && identical(_openingToken, token)) {
        setState(() {
          _openingToken = null;
          _openingRoute = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appModeProvider, (before, after) {
      if (before != after) _cancelOpening();
    });
    ref.listen(secretModeProvider, (before, after) {
      if (before != after) _cancelOpening();
    });
    ref.listen(currentTabIndexProvider, (before, after) {
      if (before != after) _cancelOpening();
    });
    final request = _request;
    if (request == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final target = ref.watch(catalogResumeTargetProvider(request));
    void reload() {
      setState(() {
        _readFailed = false;
        _openFailed = false;
      });
      ref.invalidate(catalogResumeTargetProvider(request));
    }

    if (_openingToken != null) return _checking(l10n);
    if (_readFailed) return _error(l10n.resumeBannerReadFailed, reload);
    return target.when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: false,
      data: (data) {
        if (data == null) return const SizedBox.shrink();
        if (_openFailed) {
          return _error(
            l10n.resumeBannerOpenFailed,
            () => _open(data),
            opening: true,
          );
        }
        return _ready(data, l10n);
      },
      loading: () => _checking(l10n),
      error: (_, _) => _error(l10n.resumeBannerReadFailed, reload),
    );
  }

  Widget _frame(Widget child) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('resume-panel'),
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
      ),
      child: Material(color: Colors.transparent, child: child),
    );
  }

  Widget _checking(AppLocalizations l10n) => _frame(
    Semantics(
      liveRegion: true,
      label: l10n.commonLoading,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(
                key: ValueKey('resume-checking'),
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.commonLoading)),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _error(String message, VoidCallback retry, {bool opening = false}) =>
      _frame(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(liveRegion: true, child: Text(message)),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  key: ValueKey(opening ? 'resume-open' : 'resume-reload'),
                  onPressed: retry,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  icon: Icon(opening ? Icons.open_in_new : Icons.refresh),
                  label: Text(
                    opening
                        ? AppLocalizations.of(context)!.commonRetry
                        : AppLocalizations.of(context)!.importResultsReload,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _ready(CatalogResumeTarget target, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final filename = p.basename(target.item.path);
    final viewedAt = target.lastViewedAt;
    final date = viewedAt == null
        ? null
        : l10n.resumeBannerLastViewedAt(
            DateTimeUtils.formatDateTime(context, viewedAt.toLocal()),
          );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.resumeBannerLastOpenedFile,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          key: const ValueKey('resume-name'),
          filename,
          softWrap: true,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
        if (date != null) ...[
          const SizedBox(height: 4),
          Text(
            date,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
    void open() => _open(target);
    final action = FilledButton.tonal(
      key: const ValueKey('resume-open'),
      onPressed: open,
      style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
      child: Text(l10n.resumeBannerAction),
    );
    return _frame(
      Semantics(
        button: true,
        label: [
          l10n.resumeBannerLastOpenedFile,
          filename,
          date,
          l10n.resumeBannerAction,
        ].whereType<String>().join('. '),
        onTap: open,
        child: ExcludeSemantics(
          child: InkWell(
            onTap: open,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stacked =
                      constraints.maxWidth < 400 ||
                      MediaQuery.textScalerOf(context).scale(16) / 16 >= 1.6;
                  final content = Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildThumbnail(context, ref, target.item),
                      const SizedBox(width: 12),
                      Expanded(child: details),
                      if (!stacked) ...[const SizedBox(width: 12), action],
                    ],
                  );
                  if (!stacked) return content;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      content,
                      const SizedBox(height: 12),
                      Align(alignment: Alignment.centerRight, child: action),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context, WidgetRef ref, MediaItem item) {
    final useSecretMode = ref.watch(
      privacySettingsNotifierProvider.select(
        (s) => s.value?.useSecretThumbnailMode ?? false,
      ),
    );
    const size = 50.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: useSecretMode
          ? Icon(
              _getIconData(item),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 22,
            )
          : _buildImageContent(context, ref, item),
    );
  }

  Widget _buildImageContent(
    BuildContext context,
    WidgetRef ref,
    MediaItem item,
  ) {
    if (item.thumbnailPath != null) {
      return _buildImageFile(context, ref, item, item.thumbnailPath!);
    }

    if (item.sourceType == MediaSourceType.externalReference &&
        item.type == MediaType.file) {
      return _buildExternalThumbnail(context, ref, item);
    }

    if (item.isImage) {
      return _buildImageFile(context, ref, item, item.path);
    }

    return Icon(
      _getIconData(item),
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      size: 22,
    );
  }

  Widget _buildImageFile(
    BuildContext context,
    WidgetRef ref,
    MediaItem item,
    String relativePath,
  ) {
    final docsPath = ref.watch(appDocumentsPathSyncProvider);
    final file = File(p.join(docsPath, relativePath));
    final ext = p.extension(file.path).toLowerCase();
    final isImageExt = {
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.bmp',
      '.webp',
      '.heic',
      '.heif',
      '.tif',
      '.tiff',
    }.contains(ext);
    if (!isImageExt || !file.existsSync()) {
      return Icon(
        _getIconData(item),
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 22,
      );
    }
    return Image.file(
      file,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      cacheWidth: 128,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          _getIconData(item),
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 22,
        );
      },
    );
  }

  Widget _buildExternalThumbnail(
    BuildContext context,
    WidgetRef ref,
    MediaItem item,
  ) {
    final asyncBytes = ref.watch(externalThumbnailProvider(item));
    return asyncBytes.when(
      data: (bytes) {
        if (bytes != null && bytes.isNotEmpty) {
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            cacheWidth: 128,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                _getIconData(item),
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 22,
              );
            },
          );
        }
        return Icon(
          _getIconData(item),
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 22,
        );
      },
      loading: () => const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => Icon(
        _getIconData(item),
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 22,
      ),
    );
  }

  IconData _getIconData(MediaItem item) {
    if (item.type == MediaType.folder) return Icons.folder;
    if (item.isImage) return Icons.image;
    if (item.isVideo) return Icons.movie;
    if (item.isAudio) return Icons.audiotrack;
    if (item.isDocument) return Icons.description;
    if (item.isArchive) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }
}
