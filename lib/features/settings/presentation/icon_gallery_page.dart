import 'package:flutter/material.dart';
import 'package:private_shelf/core/theme/app_tokens.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/icons/library_action_icons.dart';
import 'package:private_shelf/shared/widgets/app_bar/premium_app_bar.dart';

/// Settings-only reference page for the library action icon vocabulary.
class IconGalleryPage extends StatelessWidget {
  const IconGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final entries = <({Widget icon, String label})>[
      (icon: const CatalogizeIcon(), label: l10n.settingsCollectionCatalogify),
      (
        icon: const CatalogizeIcon.outlined(),
        label: l10n.settingsCollectionCatalogify,
      ),
      (
        icon: const Icon(LibraryActionIcons.selectAll),
        label: l10n.importSelectAll,
      ),
      (
        icon: const Icon(LibraryActionIcons.deselectAll),
        label: l10n.importDeselectAll,
      ),
      (
        icon: const Icon(LibraryActionIcons.duplicate),
        label: l10n.commonDuplicate,
      ),
      (icon: const Icon(LibraryActionIcons.move), label: l10n.settingsFileMove),
      (icon: const CharmIcon.bulkAdd(), label: l10n.libraryBulkTag),
      (icon: const CharmIcon.add(), label: l10n.tagAddNew),
      (icon: const CharmIcon.search(), label: l10n.tagSearchHint),
      (
        icon: const CatalogizeIcon.release(),
        label: l10n.settingsCollectionDecatalogify,
      ),
      (
        icon: const Icon(LibraryActionIcons.rank),
        label: l10n.settingsCollectionTier,
      ),
      (
        icon: const Icon(LibraryActionIcons.sort),
        label: l10n.commonSortSettings,
      ),
      (icon: const Icon(LibraryActionIcons.filter), label: l10n.commonFilter),
      (
        icon: const Icon(LibraryActionIcons.filterClear),
        label: l10n.libraryClearAllConditions,
      ),
      (icon: const CharmIcon.filter(), label: l10n.libraryFilterByTag),
      (
        icon: const Icon(LibraryActionIcons.download),
        label: l10n.libraryDownload,
      ),
      (
        icon: const Icon(LibraryActionIcons.importData),
        label: l10n.commonImport,
      ),
      (
        icon: const Icon(LibraryActionIcons.exportData),
        label: l10n.settingsStorageExportMeta,
      ),
      (
        icon: const Icon(LibraryActionIcons.favorite),
        label: l10n.settingsCollectionFavorite,
      ),
      (
        icon: const Icon(LibraryActionIcons.archive),
        label: l10n.libraryMenuArchive,
      ),
      (icon: const Icon(LibraryActionIcons.share), label: l10n.commonShare),
      (icon: const Icon(LibraryActionIcons.rename), label: l10n.viewerRename),
      (icon: const Icon(LibraryActionIcons.delete), label: l10n.commonDelete),
      (
        icon: const Icon(LibraryActionIcons.folderCover),
        label: l10n.librarySetAsFolderCover,
      ),
      (icon: const Icon(LibraryActionIcons.help), label: l10n.settingsHelp),
    ];

    return Scaffold(
      appBar: PremiumAppBar(titleText: l10n.settingsIconGalleryTitle),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Card(
            child: ListTile(
              leading: IconTheme.merge(
                data: IconThemeData(size: 28, color: theme.colorScheme.primary),
                child: entry.icon,
              ),
              title: Text(entry.label),
              subtitle: Text(l10n.settingsIconGalleryHint),
            ),
          );
        },
      ),
    );
  }
}
