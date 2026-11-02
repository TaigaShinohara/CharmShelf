import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/core/error/user_safe_error_message.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_settings_provider.dart';
import 'package:private_shelf/features/library/presentation/widgets/create_folder_dialog.dart';
import 'package:private_shelf/features/library/presentation/widgets/media_item_card.dart';
import 'package:private_shelf/features/library/presentation/widgets/media_list_tile.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

class MoveDestinationScreen extends ConsumerStatefulWidget {
  final Set<String> movingItemPaths;
  final String? currentParentPath;
  final bool isCopy;

  const MoveDestinationScreen({
    super.key,
    required this.movingItemPaths,
    required this.currentParentPath,
    this.isCopy = false,
  });

  @override
  ConsumerState<MoveDestinationScreen> createState() =>
      _MoveDestinationScreenState();
}

class _MoveDestinationScreenState extends ConsumerState<MoveDestinationScreen> {
  String? _selectedPath;
  bool _hasSelection = false;
  bool _creating = false;

  String _normalize(String? value) =>
      value == null || value.isEmpty ? '' : p.normalize(value);

  bool _isCurrent(String path) =>
      !widget.isCopy &&
      widget.movingItemPaths.isNotEmpty &&
      _normalize(path) == _normalize(widget.currentParentPath);

  bool _isInvalid(String path) {
    final target = _normalize(path);
    return widget.movingItemPaths.any((source) {
      final normalized = _normalize(source);
      return target == normalized || p.isWithin(normalized, target);
    });
  }

  Future<void> _createFolder() async {
    final l10n = AppLocalizations.of(context)!;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const CreateFolderDialog(),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    setState(() => _creating = true);
    try {
      await ref
          .read(libraryViewModelProvider.notifier)
          .createFolder(name.trim());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userSafeErrorMessage(error, l10n))),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final asyncItems = ref.watch(libraryViewModelProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isCopy ? l10n.libraryCopyTo : l10n.libraryMoveTo),
        leading: const BackButton(),
      ),
      body: asyncItems.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text(userSafeErrorMessage(error, l10n))),
        data: (items) {
          final folders =
              items.where((i) => i.type == MediaType.folder).toList()
                ..sort((a, b) => a.path.compareTo(b.path));
          final viewMode = ref.watch(globalViewModeProvider);
          final root = _buildRootTile(context, l10n);
          if (viewMode == ViewMode.grid) {
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 120),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.82,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: folders.length + 1,
              itemBuilder: (context, index) => index == 0
                  ? root
                  : _buildFolderCard(context, folders[index - 1]),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 120),
            itemCount: folders.length + 1,
            itemBuilder: (context, index) => index == 0
                ? root
                : _buildFolderListTile(context, folders[index - 1]),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _creating ? null : _createFolder,
                icon: const Icon(Icons.create_new_folder_outlined),
                label: Text(l10n.libraryCreateFolder),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: !_hasSelection
                    ? null
                    : () => Navigator.pop(context, _selectedPath ?? ''),
                child: Text(
                  widget.isCopy ? l10n.libraryCopyHere : l10n.libraryMoveHere,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderCard(BuildContext context, MediaItem folder) {
    final disabled = _isCurrent(folder.path) || _isInvalid(folder.path);
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: MediaItemCard(
        item: folder,
        isSelectionMode: true,
        isSelected: _selectedPath == folder.path,
        onTap: disabled ? null : () => _select(folder.path),
      ),
    );
  }

  Widget _buildFolderListTile(BuildContext context, MediaItem folder) {
    final disabled = _isCurrent(folder.path) || _isInvalid(folder.path);
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: MediaListTile(
        item: folder,
        isSelectionMode: true,
        isSelected: _selectedPath == folder.path,
        onTap: disabled ? null : () => _select(folder.path),
      ),
    );
  }

  Widget _buildRootTile(BuildContext context, AppLocalizations l10n) {
    final disabled = _isCurrent('');
    final selected = _selectedPath == '';
    return Card(
      margin: const EdgeInsets.all(4),
      color: selected
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: disabled ? null : () => _select(''),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                Icons.home_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.libraryRoot,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (disabled)
                Text(l10n.libraryMoveCurrentLocationBadge)
              else
                const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  void _select(String path) {
    setState(() {
      _selectedPath = path;
      _hasSelection = true;
    });
  }
}
