import 'package:flutter/material.dart';
import 'package:private_shelf/features/library/presentation/models/import_catalog_options.dart';
import 'package:private_shelf/shared/widgets/sheets/app_bottom_sheet.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/icons/library_action_icons.dart';

class ImportCatalogSheet extends StatefulWidget {
  final bool initialIsCatalog;
  final bool isFolderImport;

  const ImportCatalogSheet({
    super.key,
    required this.initialIsCatalog,
    this.isFolderImport = false,
  });

  @override
  State<ImportCatalogSheet> createState() => _ImportCatalogSheetState();
}

class _ImportCatalogSheetState extends State<ImportCatalogSheet> {
  bool _registerAsCatalog = false;
  bool _registerChildAsCatalog = false;

  @override
  void initState() {
    super.initState();
    _registerAsCatalog = widget.initialIsCatalog;
  }

  void _setRegisterAsCatalog(bool value) {
    setState(() => _registerAsCatalog = value);
  }

  void _showFolderInfo() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.folder, color: colorScheme.primary),
            const SizedBox(width: 12),
            Text(l10n.importCatalogChildFolderHandlingTitle),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.unarchive_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.importCatalogChildFolderHandlingNormalDesc,
                    style: textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.account_tree_outlined,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.importCatalogChildFolderHandlingAsContentDesc,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonUnderstand),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final targetLabel = widget.isFolderImport
        ? l10n.commonFolder
        : l10n.commonFile;
    final showChildSelection = widget.isFolderImport && !_registerAsCatalog;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            children: [
              Text(
                widget.isFolderImport
                    ? l10n.importCatalogFolderImportTitle
                    : l10n.importCatalogFileImportTitle,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  // 左: カタログ登録してインポート
                  Expanded(
                    child: Material(
                      color: _registerAsCatalog
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _setRegisterAsCatalog(true),
                        child: SizedBox(
                          height: 72,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CatalogizeIcon(
                                  size: 22,
                                  color: _registerAsCatalog
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    l10n.importCatalogRegisterAsCatalogBtn,
                                    style: textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: _registerAsCatalog
                                          ? colorScheme.onPrimaryContainer
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 右: 通常インポート
                  Expanded(
                    child: Material(
                      color: !_registerAsCatalog
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _setRegisterAsCatalog(false),
                        child: SizedBox(
                          height: 72,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  widget.isFolderImport
                                      ? Icons.folder_outlined
                                      : Icons.insert_drive_file_outlined,
                                  size: 18,
                                  color: !_registerAsCatalog
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    l10n.importCatalogNormalImportBtn,
                                    style: textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: !_registerAsCatalog
                                          ? colorScheme.onPrimaryContainer
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _registerAsCatalog
                    ? l10n.importCatalogRegisterAsCatalogDesc
                    : l10n.importCatalogNormalImportDesc(targetLabel),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showChildSelection)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                    child: Text(
                      l10n.importCatalogChildFolderSettings,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (showChildSelection) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Material(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.45,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            CatalogizeIcon(
                              size: 20,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l10n.importCatalogRegisterChildAsCatalog,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: l10n.tooltipInfo,
                              icon: Icon(
                                Icons.info_outline,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              onPressed: _showFolderInfo,
                            ),
                            Switch(
                              value: _registerChildAsCatalog,
                              onChanged: (value) {
                                setState(() {
                                  _registerChildAsCatalog = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.commonCancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(
                      context,
                      ImportCatalogOptions(
                        isCatalog: _registerAsCatalog,
                        registerChildFolders: showChildSelection
                            ? _registerChildAsCatalog
                            : false,
                      ),
                    );
                  },
                  icon: const Icon(LibraryActionIcons.importData),
                  label: Text(l10n.commonImport),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// インポート時のカタログ登録設定シートを表示するヘルパー
Future<ImportCatalogOptions?> showImportCatalogSheet(
  BuildContext context, {
  required bool initialIsCatalog,
  bool isFolderImport = false,
}) {
  return showAppBottomSheet<ImportCatalogOptions>(
    context,
    child: ImportCatalogSheet(
      initialIsCatalog: initialIsCatalog,
      isFolderImport: isFolderImport,
    ),
  );
}
