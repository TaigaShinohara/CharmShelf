import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/user_safe_error_message.dart';
import '../../../../core/feedback/snackbar_service.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/logger/log_tag.dart';
import '../../../../gen_l10n/app_localizations.dart';
import '../../../../shared/widgets/sheets/action_bottom_sheet.dart';
import '../../domain/models/tag_facet.dart';
import 'tag_preset_provider.dart';

final tagExportProvider = NotifierProvider<TagExportController, bool>(
  TagExportController.new,
);

enum _ExportScope { all, selectedFacet }

/// Shares the export flow and its busy state across settings and charm management.
class TagExportController extends Notifier<bool> {
  bool _disposed = false;

  @override
  bool build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return false;
  }

  Future<void> export(BuildContext context, {TagFacet? selectedFacet}) async {
    if (state) return;
    state = true;
    final l10n = AppLocalizations.of(context)!;
    final snackBar = ref.read(snackBarServiceProvider);
    try {
      int? facetId;
      if (selectedFacet != null) {
        final scope = await showActionBottomSheet<_ExportScope>(
          context,
          title: l10n.tagExportScopeTitle,
          items: [
            ActionSheetItem(
              icon: Icons.all_inclusive,
              label: l10n.tagExportAll,
              value: _ExportScope.all,
            ),
            ActionSheetItem(
              icon: Icons.category_outlined,
              label: l10n.tagExportSelectedFacet(selectedFacet.name),
              value: _ExportScope.selectedFacet,
            ),
          ],
        );
        if (scope == null || !context.mounted || _disposed) return;
        if (scope == _ExportScope.selectedFacet) facetId = selectedFacet.id;
      }
      final service = await ref.read(tagPresetServiceProvider.future);
      if (!context.mounted || _disposed) return;
      final result = await service.exportPresetsToFile(
        facetId: facetId,
        dialogTitle: l10n.tagExportSaveDialogTitle,
      );
      if (result == null || !context.mounted || _disposed) return;
      snackBar.success(
        context: context,
        message: l10n.tagExportCompleted(result.facetCount, result.tagCount),
      );
    } catch (error, stack) {
      AppLogger.e(LogTag.ui, 'Export charms error', error, stack);
      if (context.mounted && !_disposed) {
        snackBar.error(
          context: context,
          message: userSafeErrorMessage(error, l10n),
        );
      }
    } finally {
      if (!_disposed) state = false;
    }
  }
}
