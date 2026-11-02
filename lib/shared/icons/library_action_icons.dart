import 'package:flutter/material.dart';

export '../widgets/icon/catalogize_icon.dart';
export '../widgets/icon/charm_icon.dart';

/// Library actions use one small, Material-style icon vocabulary.
///
/// Keep the semantic mapping here so action sheets, bulk actions, and filters
/// do not slowly diverge into different symbols for the same operation.
abstract final class LibraryActionIcons {
  // Catalog and charm symbols use CatalogizeIcon and CharmIcon SVG widgets.
  static const selectAll = Icons.select_all;
  static const deselectAll = Icons.deselect;
  static const duplicate = Icons.content_copy_outlined;
  static const move = Icons.drive_file_move_outlined;
  static const rank = Icons.star_outline;
  static const sort = Icons.sort;
  static const filter = Icons.filter_alt_outlined;
  static const filterClear = Icons.filter_alt_off;
  static const download = Icons.download_outlined;
  static const importData = Icons.input;
  static const exportData = Icons.output;

  // Supporting actions shown in the settings reference page.
  static const favorite = Icons.favorite_border;
  static const archive = Icons.archive_outlined;
  static const share = Icons.share_outlined;
  static const rename = Icons.drive_file_rename_outline;
  static const delete = Icons.delete_outline;
  static const folderCover = Icons.folder_shared_outlined;
  static const help = Icons.help_outline;
}
