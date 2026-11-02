import 'package:flutter/material.dart';
import 'package:private_shelf/shared/icons/library_action_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/presentation/widgets/library_mode_title.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/app_bar/premium_sliver_app_bar.dart';
import 'package:private_shelf/shared/widgets/app_popup_menu_item.dart';

/// ライブラリ共通の SliverAppBar コンポーネント
class LibraryAppBar extends StatelessWidget {
  final bool isSearching;
  final int? selectionCount;
  final bool hasBackButton;
  final bool isLibraryRoot;
  final MediaFilter filter;
  final String? titleText;
  final TextEditingController searchController;
  final VoidCallback onBackButtonPressed;
  final VoidCallback onStopSearch;
  final ValueChanged<String>? onSearchSubmitted;
  final ValueChanged<SearchTarget> onSearchTargetChanged;
  final ValueChanged<bool>? onSearchScopeChanged;
  final VoidCallback onOpenFilter;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;

  const LibraryAppBar({
    super.key,
    required this.isSearching,
    this.selectionCount,
    required this.hasBackButton,
    required this.isLibraryRoot,
    required this.filter,
    this.titleText,
    required this.searchController,
    required this.onBackButtonPressed,
    required this.onStopSearch,
    this.onSearchSubmitted,
    required this.onSearchTargetChanged,
    this.onSearchScopeChanged,
    required this.onOpenFilter,
    required this.actions,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final showSearch = isSearching && selectionCount == null;
    final searchTarget = filter.effectiveSearchTarget;
    final targetLabel = searchTarget == SearchTarget.catalogsOnly
        ? l10n.librarySearchTargetCatalogs
        : l10n.librarySearchTargetFiles;
    double textHeight(String value, TextStyle? style, double width) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: width.clamp(1, double.infinity));
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final contentWidth = MediaQuery.sizeOf(context).width - 32;
    final showsFolderScope = filter.parentPath != null;
    final isRestricted = searchTarget == SearchTarget.catalogsOnly;
    final scopeStyle = Theme.of(context).textTheme.labelLarge;
    final scopeButtonWidth = (contentWidth - 16) / 2 - 24;
    final scopeHeight = [
      textHeight(l10n.librarySearchScopeCurrent, scopeStyle, scopeButtonWidth),
      textHeight(l10n.librarySearchScopeAll, scopeStyle, scopeButtonWidth),
    ].reduce((a, b) => a > b ? a : b);
    final scopeControlHeight = (scopeHeight + 16).clamp(48.0, double.infinity);
    final targetHeight =
        (textHeight(
                  targetLabel,
                  Theme.of(context).textTheme.labelLarge,
                  contentWidth - 56,
                ) +
                16)
            .clamp(48.0, double.infinity);
    final hasSearchBottom = showsFolderScope || isRestricted || bottom != null;
    final appBarTitleText = isLibraryRoot
        ? (titleText ?? 'CharmShelf')
        : titleText;
    final appBarTitleGradient = isLibraryRoot
        ? LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          )
        : null;
    return PremiumSliverAppBar(
      pinned: true,
      floating: false,
      snap: false,
      stretch: false,
      toolbarHeight: 48.0,
      inlineTitle: true,
      // ライブラリは検索・フォルダ階層を自身で管理するため、外側の
      // Navigatorにルートがあっても暗黙の戻るボタンを表示しない。
      automaticallyImplyLeading: false,
      leading: selectionCount != null
          ? null
          : showSearch
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: l10n.libraryCloseSearch,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              onPressed: onStopSearch,
            )
          : (hasBackButton
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                    onPressed: onBackButtonPressed,
                  )
                : null),
      centerTitle: false,
      title: selectionCount != null
          ? Text(l10n.librarySelectionCount(selectionCount!))
          : showSearch
          ? Container(
              key: const ValueKey('library-search-field'),
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: searchController,
                builder: (context, value, _) {
                  return TextField(
                    controller: searchController,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onSubmitted: onSearchSubmitted,
                    textAlignVertical: TextAlignVertical.center,
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14.5,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.librarySearchHint,
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 14.5,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 48,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      suffixIcon: value.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              tooltip: l10n.commonClear,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 48,
                                height: 48,
                              ),
                              onPressed: () {
                                searchController.clear();
                                onSearchSubmitted?.call('');
                              },
                            )
                          : null,
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                    ),
                  );
                },
              ),
            )
          : Row(
              children: [
                if (isLibraryRoot) ...[
                  SvgPicture.asset(
                    'assets/images/icon/private_shelf_icon.svg',
                    width: 32,
                    height: 32,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: LibraryModeTitle(
                    title: appBarTitleText,
                    showTitle: appBarTitleText != null,
                    titleGradient: appBarTitleGradient,
                  ),
                ),
              ],
            ),
      actions: showSearch
          ? [
              PopupMenuButton<SearchTarget>(
                key: const ValueKey('library-search-options'),
                tooltip: l10n.librarySearchTarget,
                icon: const Icon(Icons.more_horiz),
                onSelected: onSearchTargetChanged,
                itemBuilder: (context) => [
                  _searchTargetMenuItem(
                    target: SearchTarget.filesIncluded,
                    currentTarget: searchTarget,
                    icon: Icons.search,
                    label: l10n.librarySearchFilesIncluded,
                  ),
                  _searchTargetMenuItem(
                    target: SearchTarget.catalogsOnly,
                    currentTarget: searchTarget,
                    iconWidget: const CatalogizeIcon.outlined(size: 20),
                    label: l10n.librarySearchCatalogsOnly,
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(LibraryActionIcons.filter),
                tooltip: l10n.commonFilter,
                onPressed: onOpenFilter,
              ),
            ]
          : actions,
      bottom: showSearch && hasSearchBottom
          ? PreferredSize(
              preferredSize: Size.fromHeight(
                (showsFolderScope ? scopeControlHeight : 0) +
                    (isRestricted ? targetHeight : 0) +
                    (bottom?.preferredSize.height ?? 0),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showsFolderScope || isRestricted)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showsFolderScope)
                            SizedBox(
                              height: scopeControlHeight,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextButton(
                                      key: const ValueKey(
                                        'search-scope-current',
                                      ),
                                      style: TextButton.styleFrom(
                                        minimumSize: const Size(48, 48),
                                        foregroundColor:
                                            filter.searchWithinParent
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                      ),
                                      onPressed: () =>
                                          onSearchScopeChanged?.call(true),
                                      child: Text(
                                        l10n.librarySearchScopeCurrent,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextButton(
                                      key: const ValueKey('search-scope-all'),
                                      style: TextButton.styleFrom(
                                        minimumSize: const Size(48, 48),
                                        foregroundColor:
                                            filter.searchWithinParent
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant
                                            : Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                      ),
                                      onPressed: () =>
                                          onSearchScopeChanged?.call(false),
                                      child: Text(l10n.librarySearchScopeAll),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (isRestricted)
                            SizedBox(
                              height: targetHeight,
                              child: TextButton(
                                key: const ValueKey(
                                  'library-search-remove-restriction',
                                ),
                                onPressed: () => onSearchTargetChanged(
                                  SearchTarget.filesIncluded,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(targetLabel)),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.close, size: 20),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  // build_runner's analyzer does not parse null-aware
                  // collection elements yet.
                  // ignore: use_null_aware_elements
                  if (bottom != null) bottom!,
                ],
              ),
            )
          : bottom,
    );
  }

  PopupMenuItem<SearchTarget> _searchTargetMenuItem({
    required SearchTarget target,
    required SearchTarget currentTarget,
    IconData? icon,
    Widget? iconWidget,
    required String label,
  }) {
    return AppPopupMenuItem<SearchTarget>(
      showSelectionFeedback: false,
      value: target,
      iconData: icon,
      icon: iconWidget,
      title: Text(label),
      trailing: target == currentTarget
          ? const Icon(Icons.check, size: 20)
          : null,
    );
  }
}
