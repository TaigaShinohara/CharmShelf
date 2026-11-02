import 'package:flutter/material.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

import 'package:private_shelf/shared/widgets/icon/catalogize_icon.dart';

enum CollectionDisplayType { catalog, folder, file }

extension CollectionDisplayTypeExt on MediaCollection {
  CollectionDisplayType get displayType {
    if (isCatalog) return CollectionDisplayType.catalog;
    return type == CollectionType.file
        ? CollectionDisplayType.file
        : CollectionDisplayType.folder;
  }

  String displayTypeLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return switch (displayType) {
      CollectionDisplayType.catalog => l10n.libraryDisplayTypeCatalog,
      CollectionDisplayType.folder => l10n.libraryDisplayTypeFolder,
      CollectionDisplayType.file => l10n.libraryDisplayTypeFile,
    };
  }

  Widget displayTypeIcon({Color? color, double? size}) => switch (displayType) {
    CollectionDisplayType.catalog => CatalogizeIcon(color: color, size: size),
    CollectionDisplayType.folder => Icon(
      Icons.folder_outlined,
      color: color,
      size: size,
    ),
    CollectionDisplayType.file => Icon(
      Icons.insert_drive_file_outlined,
      color: color,
      size: size,
    ),
  };
}
