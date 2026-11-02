import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../../core/providers/path_provider.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../library/domain/models/collection.dart';
import '../../../library/presentation/providers/collection_cover_thumbnail_provider.dart';
import '../../../settings/presentation/providers/privacy_settings_provider.dart';
import 'recent_history_widgets.dart';

class RecentCollectionCard extends ConsumerWidget {
  const RecentCollectionCard({
    super.key,
    required this.collection,
    required this.onTap,
    required this.onActions,
  });
  final MediaCollection collection;
  final VoidCallback onTap;
  final VoidCallback onActions;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alias = collection.alias?.trim() ?? '';
    final hidden =
        ref
            .watch(privacySettingsNotifierProvider)
            .value
            ?.useSecretThumbnailMode ??
        false;
    final fallback = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.shelves, size: AppIconSize.xxl)),
    );
    Widget preview = fallback;
    if (!hidden) {
      final cover = ref
          .watch(collectionCoverThumbnailProvider(collection))
          .value;
      if (cover is FileCoverData) {
        final docs = ref.watch(appDocumentsPathSyncProvider);
        preview = Image.file(
          File(p.join(docs, cover.relativePath)),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          cacheWidth: 512,
          errorBuilder: (_, _, _) => fallback,
        );
      } else if (cover is MemoryCoverData) {
        preview = Image.memory(
          cover.bytes,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          cacheWidth: 512,
          errorBuilder: (_, _, _) => fallback,
        );
      }
    }
    return RecentHistoryCard(
      title: alias.isEmpty ? collection.title : alias,
      subtitle: alias.isEmpty || alias == collection.title
          ? ''
          : collection.title,
      preview: preview,
      onTap: onTap,
      onActions: onActions,
      badges: [
        if (collection.isHidden) const _Badge(icon: Icons.visibility_off),
        if (collection.isFavorite) const _Badge(icon: Icons.favorite),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(2),
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      shape: BoxShape.circle,
    ),
    child: Icon(icon, size: 16),
  );
}
