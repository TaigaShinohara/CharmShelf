import 'themed_svg_icon.dart';

/// Shared symbol for charm management, assignment and filtering.
class CharmIcon extends ThemedSvgIcon {
  const CharmIcon({super.key, super.size, super.color})
    : super('assets/images/icon/charm.svg');

  const CharmIcon.add({super.key, super.size, super.color})
    : super('assets/images/icon/charm_add.svg');

  const CharmIcon.bulkAdd({super.key, super.size, super.color})
    : super('assets/images/icon/charm_add_bulk.svg');

  const CharmIcon.search({super.key, super.size, super.color})
    : super('assets/images/icon/charm_search.svg');

  const CharmIcon.filter({super.key, super.size, super.color})
    : super('assets/images/icon/charm_filter.svg');
}
