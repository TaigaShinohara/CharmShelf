import 'themed_svg_icon.dart';

/// Shared folder-and-charm catalog symbol for managed files and their actions.
class CatalogizeIcon extends ThemedSvgIcon {
  const CatalogizeIcon({super.key, super.size, super.color})
    : super('assets/images/icon/catalogize.svg');

  const CatalogizeIcon.outlined({super.key, super.size, super.color})
    : super('assets/images/icon/catalogize_outline.svg');

  const CatalogizeIcon.release({super.key, super.size, super.color})
    : super('assets/images/icon/catalog_release.svg');
}
