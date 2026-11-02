import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/dialogs/selection_dialog.dart';

/// ライブラリのソート順を選択するダイアログを表示するヘルパー関数
Future<void> showLibrarySortDialog(
  BuildContext context,
  WidgetRef ref, {
  required AppMode mode,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final filter = ref.read(mediaFilterNotifierProvider(mode));

  final options = [
    SelectionOption<SortOrder>(
      value: SortOrder.nameAsc,
      title: l10n.librarySortNameAsc,
    ),
    SelectionOption<SortOrder>(
      value: SortOrder.nameDesc,
      title: l10n.librarySortNameDesc,
    ),
    SelectionOption<SortOrder>(
      value: SortOrder.addedDesc,
      title: l10n.librarySortAddedDateDesc,
    ),
    SelectionOption<SortOrder>(
      value: SortOrder.addedAsc,
      title: l10n.librarySortAddedDateAsc,
    ),
    SelectionOption<SortOrder>(
      value: SortOrder.updatedDesc,
      title: l10n.librarySortUpdatedDateDesc,
    ),
    SelectionOption<SortOrder>(
      value: SortOrder.updatedAsc,
      title: l10n.librarySortUpdatedDateAsc,
    ),
    SelectionOption<SortOrder>(
      value: SortOrder.sizeDesc,
      title: l10n.librarySortSizeDesc,
    ),
    SelectionOption<SortOrder>(
      value: SortOrder.sizeAsc,
      title: l10n.librarySortSizeAsc,
    ),
    SelectionOption<SortOrder>(
      value: SortOrder.favoriteDesc,
      title: l10n.librarySortFavoriteDesc,
    ),
    SelectionOption<SortOrder>(
      value: SortOrder.lastViewedDesc,
      title: l10n.librarySortRecent,
    ),
  ];

  final selected = await showAppSelectionDialog<SortOrder>(
    context,
    title: l10n.commonSortSettings,
    options: options,
    selectedValue: filter.sortOrder,
  );

  if (selected != null && context.mounted) {
    await ref
        .read(mediaFilterNotifierProvider(mode).notifier)
        .updateSortOrder(selected);
  }
}

extension SortOrderLocalizationExtension on SortOrder {
  String localizedLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return switch (this) {
      SortOrder.nameAsc => l10n.librarySortNameAsc,
      SortOrder.nameDesc => l10n.librarySortNameDesc,
      SortOrder.addedDesc => l10n.librarySortAddedDateDesc,
      SortOrder.addedAsc => l10n.librarySortAddedDateAsc,
      SortOrder.updatedDesc => l10n.librarySortUpdatedDateDesc,
      SortOrder.updatedAsc => l10n.librarySortUpdatedDateAsc,
      SortOrder.sizeDesc => l10n.librarySortSizeDesc,
      SortOrder.sizeAsc => l10n.librarySortSizeAsc,
      SortOrder.favoriteDesc => l10n.librarySortFavoriteDesc,
      SortOrder.lastViewedDesc => l10n.librarySortRecent,
      _ => name,
    };
  }
}
