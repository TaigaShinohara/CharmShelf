import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../helpers/catalog_navigation_helper.dart';
import '../../../settings/presentation/providers/app_mode_provider.dart';

import 'package:private_shelf/core/router/app_router.dart';
import 'package:private_shelf/core/error/user_safe_error_message.dart';
import 'package:private_shelf/core/providers/isar_provider.dart';
import 'package:private_shelf/core/providers/shared_preferences_provider.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/import_result_revision_provider.dart';
import 'package:private_shelf/features/library/domain/models/import_execution_report.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/viewer_source_context.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/states/empty_state_widget.dart';

/// Resolve again at display and activation time. A stale result never grants
/// access to hidden, archived or deleted data (including parent catalogs).
Future<MediaItem?> resolveImportedItem(
  MediaRepository repository,
  ImportCommittedItem reference,
) async {
  final result = reference.uid == null
      ? await repository.getById(reference.id)
      : await repository.getByUid(reference.uid!);
  if (result.isFailure) throw result.errorOrNull!;
  final item = result.dataOrNull;
  if (item == null || (reference.uid == null && item.path != reference.path)) {
    return null;
  }
  MediaItem? current = item;
  final visited = <String>{};
  while (current != null) {
    if (!visited.add(current.path) ||
        current.isHidden ||
        current.isArchived ||
        current.isTrashed ||
        current.isMissing) {
      return null;
    }
    final collection = await repository.getCollectionByPath(current.path);
    if (collection.isFailure) throw collection.errorOrNull!;
    final catalog = collection.dataOrNull;
    if (catalog != null &&
        (catalog.isHidden || catalog.isArchived || catalog.isTrashed)) {
      return null;
    }
    final parent = current.parentPath;
    if (parent == null || parent.isEmpty) break;
    if (parent == 'library') {
      final rootCollection = await repository.getCollectionByPath(parent);
      if (rootCollection.isFailure) throw rootCollection.errorOrNull!;
      final root = rootCollection.dataOrNull;
      if (root != null &&
          (root.isHidden || root.isArchived || root.isTrashed)) {
        return null;
      }
      break;
    }
    final ancestor = await repository.getByPath(parent, includeTrashed: true);
    if (ancestor.isFailure) throw ancestor.errorOrNull!;
    current = ancestor.dataOrNull;
    if (current == null) return null;
  }
  return item;
}

/// Open the actual retained catalog, including its current contents, after
/// checking that it still exists and remains visible and catalogized.
Future<void> openImportedCatalog(
  BuildContext context,
  WidgetRef ref,
  ImportCommittedItem reference, {
  required VoidCallback onEmpty,
}) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    final repository = await ref.read(mediaRepositoryProvider.future);
    final folder = await resolveImportedItem(repository, reference);
    if (!context.mounted) return;
    final result = folder == null
        ? null
        : await repository.getCollectionByPath(folder.path);
    if (!context.mounted) return;
    if (result?.isFailure == true) throw result!.errorOrNull!;
    final collection = result?.dataOrNull;
    if (folder == null ||
        folder.type != MediaType.folder ||
        folder.sourceType != MediaSourceType.localCopy ||
        collection == null ||
        collection.isCatalog != true ||
        collection.isExternal ||
        collection.isHidden ||
        collection.isArchived ||
        collection.isTrashed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.importResultsUnavailable)));
      return;
    }
    await openFolderCatalogViewer(
      context: context,
      ref: ref,
      folder: folder,
      collection: collection,
      mode: AppMode.internal,
      onEmpty: onEmpty,
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userSafeErrorMessage(error, l10n))),
      );
    }
  }
}

Future<void> openImportedFile(
  BuildContext context,
  WidgetRef ref,
  ImportCommittedItem reference, {
  VoidCallback? onReadyToOpen,
}) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    final repository = await ref.read(mediaRepositoryProvider.future);
    final item = await resolveImportedItem(repository, reference);
    if (!context.mounted) return;
    if (item == null || item.type != MediaType.file) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.importResultsUnavailable)));
      return;
    }
    final args = ViewerRouteArgs(
      initialItem: item,
      sourceContext: const ViewerSourceContext.single(),
    );
    final route = MediaViewerRoute(id: item.id, $extra: args);
    if (onReadyToOpen == null) {
      await route.push<void>(context);
    } else {
      // Capture the router before closing the imperative import route. Import
      // screens can live in either the root or a tab's nested Navigator.
      final router = GoRouter.of(context);
      onReadyToOpen();
      await router.push<void>(
        route.location,
        extra: args,
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userSafeErrorMessage(error, l10n))),
      );
    }
  }
}

class ImportResultsScreen extends ConsumerWidget {
  const ImportResultsScreen({super.key, required this.items});
  final List<ImportCommittedItem> items;

  void _reloadRepository(WidgetRef ref) {
    // A second activation before the loading frame must not restart the work.
    if (ref.read(mediaRepositoryProvider).isLoading) return;
    // Retrying the dependent provider alone would reuse a failed Isar future.
    // Keep healthy storage/preferences; only retry failed initialization.
    if (ref.exists(isarProvider) && ref.read(isarProvider).hasError) {
      if (ref.exists(sharedPreferencesProvider) &&
          ref.read(sharedPreferencesProvider).hasError) {
        ref.invalidate(sharedPreferencesProvider);
      }
      ref.invalidate(isarProvider);
    }
    ref.invalidate(mediaRepositoryProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final repository = ref.watch(mediaRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.importOpenResults)),
      body: repository.when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        loading: () => Center(
          child: CircularProgressIndicator(
            semanticsLabel: l10n.importResultsChecking,
          ),
        ),
        error: (_, _) => EmptyStateWidget(
          title: l10n.importResultsLoadFailed,
          icon: Icons.error_outline,
          action: _ImportResultsReloadButton(
            onPressed: () => _reloadRepository(ref),
          ),
        ),
        data: (repo) => ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) => _ImportedResultTile(
            key: ValueKey(items[index].id),
            reference: items[index],
            repository: repo,
          ),
        ),
      ),
    );
  }
}

class _ImportedResultTile extends ConsumerStatefulWidget {
  const _ImportedResultTile({
    super.key,
    required this.reference,
    required this.repository,
  });
  final ImportCommittedItem reference;
  final MediaRepository repository;
  @override
  ConsumerState<_ImportedResultTile> createState() =>
      _ImportedResultTileState();
}

class _ImportedResultTileState extends ConsumerState<_ImportedResultTile> {
  late Future<MediaItem?> _item;
  Future<MediaItem?>? _pendingRetry;
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    _item = _readItem();
  }

  Future<MediaItem?> _readItem() {
    final request = resolveImportedItem(widget.repository, widget.reference);
    // Reads may fail before FutureBuilder subscribes or after replacement.
    // Consume early errors while keeping this future's result for the builder.
    request.ignore();
    return request;
  }

  @override
  void didUpdateWidget(covariant _ImportedResultTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reference != widget.reference ||
        oldWidget.repository != widget.repository) {
      _pendingRetry = null;
      _item = _readItem();
    }
  }

  void _reloadItem() {
    setState(() {
      _pendingRetry = null;
      _item = _readItem();
    });
  }

  void _retryItem() {
    if (_pendingRetry != null) return;
    final request = _readItem();
    _pendingRetry = request;
    setState(() {
      _item = request.whenComplete(() {
        if (identical(_pendingRetry, request)) _pendingRetry = null;
      });
      _item.ignore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    ref.listen(importResultRevisionProvider, (_, next) {
      if (next.hasValue && mounted) {
        _reloadItem();
      }
    });
    return FutureBuilder<MediaItem?>(
      future: _item,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return ListTile(
            leading: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                semanticsLabel: l10n.importResultsChecking,
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.importResultsLoadFailed,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                _ImportResultsReloadButton(onPressed: _retryItem),
              ],
            ),
          );
        }
        final item = snapshot.data;
        if (item == null) {
          return ListTile(title: Text(l10n.importResultsUnavailable));
        }
        return ListTile(
          leading: const Icon(Icons.insert_drive_file_outlined),
          title: Text(p.basename(item.path)),
          trailing: const Icon(Icons.chevron_right),
          onTap: _opening
              ? null
              : () async {
                  setState(() => _opening = true);
                  await openImportedFile(context, ref, widget.reference);
                  if (mounted) {
                    setState(() {
                      _opening = false;
                      _pendingRetry = null;
                      _item = _readItem();
                    });
                  }
                },
        );
      },
    );
  }
}

class _ImportResultsReloadButton extends StatelessWidget {
  const _ImportResultsReloadButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      icon: const Icon(Icons.refresh),
      label: Text(AppLocalizations.of(context)!.importResultsReload),
    );
  }
}
