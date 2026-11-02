import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../gen_l10n/app_localizations.dart';
import '../../../../../shared/widgets/settings/settings_tile.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../../library/presentation/providers/tag_export_provider.dart';
import '../../../../library/presentation/widgets/tag_import_sheet.dart';

class CharmImportTile extends StatelessWidget {
  const CharmImportTile({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsTile(
      key: const ValueKey('settings-charm-import'),
      icon: LibraryActionIcons.importData,
      title: l10n.settingsTagPresetImport,
      subtitle: l10n.settingsCharmImportDescription,
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () => showTagImportSheet(context),
    );
  }
}

class CharmExportTile extends ConsumerWidget {
  const CharmExportTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final exporting = ref.watch(tagExportProvider);
    return SettingsTile(
      key: const ValueKey('settings-charm-export'),
      icon: LibraryActionIcons.exportData,
      title: l10n.settingsCharmExport,
      subtitle: l10n.settingsCharmExportDescription,
      trailing: exporting
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right, size: 18),
      onTap: exporting
          ? null
          : () => ref.read(tagExportProvider.notifier).export(context),
    );
  }
}
