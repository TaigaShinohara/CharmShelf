import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/config/feature_flags.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/core/feedback/haptics_service.dart';
import 'package:private_shelf/features/library/presentation/helpers/library_action_handler.dart';
import 'package:private_shelf/features/library/presentation/providers/library_selection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/icons/library_action_icons.dart';
import 'package:private_shelf/shared/widgets/app_popup_menu_item.dart';

/// 選択モードの一括操作をAppBarに集約する。
class LibrarySelectionMenu extends ConsumerWidget {
  const LibrarySelectionMenu({
    super.key,
    required this.mode,
    this.actionHandler = const LibraryActionHandler(),
  });

  final AppMode mode;
  final LibraryActionHandler actionHandler;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final internal = mode == AppMode.internal;
    final items = internal
        ? ref.watch(libraryViewModelProvider).value ?? []
        : ref.watch(externalLibraryViewModelProvider).value ?? [];
    final external = internal
        ? null
        : ref.read(externalLibraryViewModelProvider.notifier);
    final selectedIds = internal
        ? ref.watch(librarySelectionNotifierProvider).selectedIds
        : external!.selectedIds;
    final count = internal ? selectedIds.length : external!.selectionCount;
    final allSelected =
        items.isNotEmpty &&
        items.every((item) => selectedIds.contains(item.id));
    final canTag = internal
        ? ref.read(libraryViewModelProvider.notifier).canApplyBulkTags
        : external!.canApplyBulkTags;

    final callbacks = <String, VoidCallback>{
      'all': () {
        if (internal) {
          final notifier = ref.read(librarySelectionNotifierProvider.notifier);
          if (allSelected) {
            notifier.deselectAll();
          } else {
            notifier.selectAll(items.map((item) => item.id));
          }
        } else if (allSelected) {
          external!.deselectAll();
        } else {
          external!.selectAllVisibleItems();
        }
      },
      'catalog': () => actionHandler.handleBulkCatalog(
        context,
        ref,
        mode,
        decatalogify: false,
      ),
      'uncatalog': () => actionHandler.handleBulkCatalog(
        context,
        ref,
        mode,
        decatalogify: true,
      ),
      'tag': () => actionHandler.showBulkTagSelectorSheet(context, ref, mode),
      'tier': () => actionHandler.showExternalBulkTierDialog(context, ref),
      'move': () => actionHandler.handleBulkMove(context, ref, mode),
      'copy': () => actionHandler.handleBulkDuplicate(context, ref, mode),
      'save': () => actionHandler.handleBulkDownload(context, ref, mode),
    };

    AppPopupMenuItem<String> entry(
      String value,
      IconData icon,
      String text,
      bool enabled,
    ) => AppPopupMenuItem.text(
      value: value,
      iconData: icon,
      text: text,
      enabled: enabled,
      height: 48,
      showSelectionFeedback: false,
    );

    return PopupMenuButton<String>(
      useRootNavigator: true,
      icon: const Icon(Icons.more_vert),
      tooltip: l10n.libraryMoreActions,
      constraints: BoxConstraints.tightFor(
        width: (MediaQuery.sizeOf(context).width - 24).clamp(0.0, 344.0),
      ),
      onSelected: (value) {
        if (FeatureFlags.enableHaptics && ref.read(hapticsEnabledProvider)) {
          unawaited(HapticsService.lightTap());
        }
        if (!context.mounted) return;
        callbacks[value]?.call();
      },
      itemBuilder: (context) => [
        entry(
          'all',
          allSelected
              ? LibraryActionIcons.deselectAll
              : LibraryActionIcons.selectAll,
          allSelected ? l10n.importDeselectAll : l10n.importSelectAll,
          items.isNotEmpty,
        ),
        const PopupMenuDivider(),
        AppPopupMenuItem.text(
          value: 'catalog',
          icon: const CatalogizeIcon.outlined(),
          text: l10n.libraryBulkCatalogify,
          enabled: actionHandler.canBulkCatalog(ref, mode, decatalogify: false),
          height: 48,
          showSelectionFeedback: false,
        ),
        AppPopupMenuItem.text(
          value: 'uncatalog',
          icon: const CatalogizeIcon.release(),
          text: l10n.libraryBulkDecatalogify,
          enabled: actionHandler.canBulkCatalog(ref, mode, decatalogify: true),
          height: 48,
          showSelectionFeedback: false,
        ),
        AppPopupMenuItem.text(
          value: 'tag',
          icon: const CharmIcon.bulkAdd(),
          text: l10n.libraryBulkTag,
          enabled: canTag,
          height: 48,
          showSelectionFeedback: false,
        ),
        if (!internal)
          entry(
            'tier',
            LibraryActionIcons.rank,
            l10n.librarySelectTier,
            external!.canApplyBulkTier,
          ),
        if (internal) ...[
          const PopupMenuDivider(),
          entry(
            'move',
            LibraryActionIcons.move,
            l10n.libraryBulkMove,
            count > 0,
          ),
          entry(
            'copy',
            LibraryActionIcons.duplicate,
            l10n.libraryBulkCopy,
            count > 0,
          ),
          entry(
            'save',
            LibraryActionIcons.download,
            l10n.commonSave,
            count > 0,
          ),
        ],
      ],
    );
  }
}
