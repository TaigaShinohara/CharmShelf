import 'dart:io';
import 'recent_history_widgets.dart';
import '../../../library/presentation/widgets/file_action_sheet.dart';
import '../../../../shared/widgets/sheets/app_bottom_sheet.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/providers/path_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../gen_l10n/app_localizations.dart';
import '../../../library/domain/models/media_item.dart';
import '../../../library/domain/models/recently_opened_file.dart';
import '../../../library/domain/models/viewer_source_context.dart';
import '../../../library/presentation/providers/external_thumbnail_provider.dart';
import '../../../library/presentation/providers/player_notifier.dart';
import '../../../library/presentation/providers/secret_mode_provider.dart';
import '../../../library/presentation/providers/viewing_history_provider.dart';
import '../../../settings/presentation/providers/app_mode_provider.dart';
import '../../../settings/presentation/providers/privacy_settings_provider.dart';

class LastOpenedFileCard extends ConsumerStatefulWidget {
  const LastOpenedFileCard({super.key, required this.entry});
  final RecentlyOpenedFile entry;

  MediaItem get item => entry.item;

  @override
  ConsumerState<LastOpenedFileCard> createState() => _LastOpenedFileCardState();
}

class _LastOpenedFileCardState extends ConsumerState<LastOpenedFileCard> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    final requestedUid = widget.item.uid;
    setState(() => _opening = true);
    try {
      final repository = await ref.read(
        viewingHistoryRepositoryProvider.future,
      );
      if (!mounted) return;
      final mode = ref.read(appModeProvider);
      final sourceType = mode == AppMode.internal
          ? MediaSourceType.localCopy
          : MediaSourceType.externalReference;
      final hidden = ref.read(secretModeProvider).value ?? false;
      final item = await repository.resolve(
        requestedUid ?? '',
        sourceType: sourceType,
        includeHidden: hidden,
      );
      if (!mounted) return;
      // A lock/mode change while the asynchronous check runs invalidates it.
      if (mode != ref.read(appModeProvider) ||
          hidden != (ref.read(secretModeProvider).value ?? false)) {
        return;
      }
      if (item == null) {
        _unavailable();
        return;
      }
      final player = ref.read(playerNotifierProvider);
      if (player.currentItem?.uid == item.uid && player.currentItem != null) {
        ref.read(playerNotifierProvider.notifier).expand();
      } else {
        await MediaViewerRoute(
          id: item.id,
          $extra: ViewerRouteArgs(
            initialItem: item,
            sourceContext: ViewerSourceContext.folder(
              parentPath: item.parentPath,
            ),
          ),
        ).push<void>(context);
      }
    } catch (_) {
      if (mounted) _unavailable();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _showActions() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final mode = ref.read(appModeProvider);
      final hidden = ref.read(secretModeProvider).value ?? false;
      final repository = await ref.read(
        viewingHistoryRepositoryProvider.future,
      );
      final item = await repository.resolve(
        widget.item.uid ?? '',
        sourceType: mode == AppMode.internal
            ? MediaSourceType.localCopy
            : MediaSourceType.externalReference,
        includeHidden: hidden,
      );
      if (!mounted ||
          mode != ref.read(appModeProvider) ||
          hidden != (ref.read(secretModeProvider).value ?? false)) {
        return;
      }
      if (item == null) {
        _unavailable();
        return;
      }
      await showAppBottomSheet(
        context,
        showCloseButton: true,
        child: FileActionSheet(item: item),
      );
    } catch (_) {
      if (mounted) _unavailable();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _unavailable() {
    ref.invalidate(recentlyOpenedFilesProvider);
    ref.invalidate(recentFilesHistoryProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.homeRecentUnavailable),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filename = p.basename(widget.item.path);
    final name = p.basenameWithoutExtension(filename);
    final extension = p.extension(filename).replaceFirst('.', '').toUpperCase();
    final catalog = widget.entry.catalog;
    final alias = catalog?.alias?.trim() ?? '';
    final isFileCatalog = catalog?.path == widget.item.path;
    final title = isFileCatalog && alias.isNotEmpty ? alias : name;
    final catalogName = catalog == null
        ? ''
        : alias.isNotEmpty
        ? alias
        : catalog.title;
    final duplicateName =
        catalogName == title || catalogName == filename || catalogName == name;
    return RecentHistoryCard(
      title: title,
      subtitle: isFileCatalog || duplicateName ? '' : catalogName,
      metadata: extension,
      preview: _RecentFilePreview(item: widget.item),
      tapKey: const ValueKey('home-open-recent'),
      onTap: _opening ? null : _open,
      onActions: _opening ? null : _showActions,
    );
  }
}

class _RecentFilePreview extends ConsumerWidget {
  const _RecentFilePreview({required this.item});

  final MediaItem item;

  static const _imageExtensions = {
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
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final hidePicture = ref.watch(
      privacySettingsNotifierProvider.select(
        (settings) => settings.value?.useSecretThumbnailMode ?? false,
      ),
    );
    final picture = hidePicture ? null : _picture(context, ref);

    return ColoredBox(
      key: const ValueKey('home-recent-preview'),
      color: scheme.surfaceContainerHighest,
      child: SizedBox.expand(child: picture ?? _fallback(context)),
    );
  }

  Widget? _picture(BuildContext context, WidgetRef ref) {
    final relativePath = item.thumbnailPath?.isNotEmpty == true
        ? item.thumbnailPath
        : item.isImage && item.sourceType != MediaSourceType.externalReference
        ? item.path
        : null;
    if (relativePath != null) {
      return _localPicture(context, ref, relativePath);
    }
    if (item.sourceType == MediaSourceType.externalReference &&
        item.type == MediaType.file &&
        (item.isImage || item.isVideo)) {
      return _externalPicture(context, ref);
    }
    return null;
  }

  Widget _localPicture(
    BuildContext context,
    WidgetRef ref,
    String relativePath,
  ) {
    final docsPath = ref.watch(appDocumentsPathSyncProvider);
    final file = File(p.join(docsPath, relativePath));
    final ext = p.extension(file.path).toLowerCase();
    if (!_imageExtensions.contains(ext) || !file.existsSync()) {
      return _fallback(context);
    }
    return Image.file(
      file,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      cacheWidth: 512,
      errorBuilder: (context, error, stackTrace) => _fallback(context),
    );
  }

  Widget _externalPicture(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(externalThumbnailProvider(item));
    return bytes.when(
      data: (data) {
        if (data == null || data.isEmpty) return _fallback(context);
        return Image.memory(
          data,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          cacheWidth: 512,
          errorBuilder: (context, error, stackTrace) => _fallback(context),
        );
      },
      loading: () => _fallback(context),
      error: (error, stackTrace) => _fallback(context),
    );
  }

  Widget _fallback(BuildContext context) {
    return Icon(
      _iconFor(item),
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      size: AppIconSize.xxl,
    );
  }

  IconData _iconFor(MediaItem item) {
    if (item.type == MediaType.folder) return Icons.folder_outlined;
    if (item.isVideo) return Icons.movie_outlined;
    if (item.isAudio) return Icons.audiotrack_outlined;
    if (item.isImage) return Icons.image_outlined;
    if (item.isDocument) return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }
}
