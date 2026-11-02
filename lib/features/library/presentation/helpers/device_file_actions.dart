import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logger/app_logger.dart';
import '../../../../core/logger/log_tag.dart';
import '../../../../gen_l10n/app_localizations.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/sheets/action_bottom_sheet.dart';
import 'system_file_picker.dart';
import '../../domain/models/import_preview_source.dart';
import '../../domain/models/selected_document.dart';
import '../providers/import_flow_provider.dart';
import '../screens/import_selection_screen.dart';
import '../screens/media_viewer_screen.dart';

enum DeviceFileAction { open, importFiles, importFolder }

Future<void> showDeviceFileActions(
  BuildContext context,
  WidgetRef ref, {
  String? targetParentPath,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final action = await showActionBottomSheet<DeviceFileAction>(
    context,
    title: l10n.deviceFilesTitle,
    enableSelectionFeedback: false,
    items: [
      ActionSheetItem(
        label: l10n.deviceOpenFile,
        value: DeviceFileAction.open,
        icon: Icons.file_open_outlined,
      ),
      ActionSheetItem(
        label: l10n.deviceImportFiles,
        value: DeviceFileAction.importFiles,
        icon: Icons.file_download_outlined,
      ),
      ActionSheetItem(
        label: l10n.deviceImportFolder,
        value: DeviceFileAction.importFolder,
        icon: Icons.create_new_folder_outlined,
      ),
    ],
  );
  if (action == null || !context.mounted) return;
  await performDeviceFileAction(
    action,
    context,
    ref,
    targetParentPath: targetParentPath,
  );
}

/// The picker owns new grants until an import flow accepts the selection.
Future<void> performDeviceFileAction(
  DeviceFileAction action,
  BuildContext context,
  WidgetRef ref, {
  String? targetParentPath,
}) async {
  final picker = ref.read(systemFilePickerProvider);
  final l10n = AppLocalizations.of(context)!;
  List<SelectedDocument>? documents;
  PickedFolder? folder;
  var adopted = false;
  try {
    switch (action) {
      case DeviceFileAction.open:
        final document = await picker.openFile();
        if (document == null || !context.mounted) return;
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => MediaViewerScreen.preview(
              source: ImportPreviewSource(
                uri: document.uri,
                name: document.name,
                size: document.size,
                mimeType: document.mimeType,
              ),
            ),
          ),
        );
      case DeviceFileAction.importFiles:
        documents = await picker.pickFiles();
        if (documents == null) return;
        if (!context.mounted) {
          await picker.releaseDocuments(documents);
          return;
        }
        adopted = true;
        await ref
            .read(importFlowNotifierProvider.notifier)
            .startDocumentsScan(documents, targetParentPath: targetParentPath);
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ImportSelectionScreen(),
          ),
        );
      case DeviceFileAction.importFolder:
        folder = await picker.pickFolder();
        if (folder == null) return;
        if (!context.mounted) {
          await picker.releaseFolder(folder);
          return;
        }
        adopted = true;
        final scan = ref
            .read(importFlowNotifierProvider.notifier)
            .startScan(
              folder.uri,
              targetParentPath: targetParentPath,
              ownsGrant: folder.ownsGrant,
            );
        final route = Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ImportSelectionScreen(),
          ),
        );
        await scan;
        await route;
    }
  } catch (error, stack) {
    if (!adopted) {
      try {
        if (documents != null) await picker.releaseDocuments(documents);
        if (folder != null) await picker.releaseFolder(folder);
      } catch (cleanupError, cleanupStack) {
        AppLogger.e(
          LogTag.storage,
          '標準ファイル選択のアクセス解放に失敗',
          cleanupError,
          cleanupStack,
        );
      }
    }
    AppLogger.e(LogTag.ui, '標準ファイル選択に失敗', error, stack);
    if (context.mounted) {
      AppSnackBarMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.devicePickerError)));
    }
  }
}
