import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/media_items_snapshot.dart';
import 'package:private_shelf/features/library/presentation/widgets/media_list_view.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';

/// Keeps only the current browse list mounted while a search replaces it.
/// Its scroll position is detached from NestedScrollView while it is hidden.
class RetainedLibraryList extends StatefulWidget {
  const RetainedLibraryList({
    super.key,
    required this.items,
    required this.filter,
    required this.fallback,
    required this.onLoadMore,
    this.header,
  });

  final AsyncValue<List<MediaItem>> items;
  final MediaFilter filter;
  final Widget fallback;
  final Widget? header;
  final VoidCallback onLoadMore;

  @override
  State<RetainedLibraryList> createState() => _RetainedLibraryListState();
}

class _RetainedLibraryListState extends State<RetainedLibraryList> {
  final _controller = _RetainedScrollController();
  List<MediaItem>? _browseItems;
  MediaFilter? _scope;
  AsyncValue<List<MediaItem>>? _browseState;
  MediaListView? _browseList;
  List<Object?>? _browseSnapshot;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = widget.filter.copyWith(searchQuery: null, searchTarget: null);
    if (scope != _scope) {
      _scope = scope;
      _browseItems = null;
      _browseState = null;
      _browseSnapshot = null;
      _browseList = null;
    }
    final searching = widget.filter.searchQuery?.isNotEmpty ?? false;
    if (!searching && !widget.items.isLoading && !widget.items.hasError) {
      if (!identical(widget.items, _browseState)) {
        _browseState = widget.items;
        final items = widget.items.value;
        final snapshot = items == null ? null : mediaItemsSnapshot(items);
        if (!const DeepCollectionEquality().equals(snapshot, _browseSnapshot)) {
          _browseSnapshot = snapshot;
          _browseItems = items;
          _browseList = null;
        }
      }
    }
    final showBrowse =
        !searching &&
        !widget.items.hasError &&
        (_browseItems?.isNotEmpty ?? false);

    _controller.connect(PrimaryScrollController.maybeOf(context), showBrowse);
    // Reuse the widget as well as its State while only search visibility changes.
    // New repository data and header changes must still update the visible rows.
    if ((_browseItems?.isNotEmpty ?? false) &&
        (_browseList == null ||
            !identical(_browseList!.header, widget.header))) {
      _browseList = MediaListView(
        items: _browseItems!,
        header: widget.header,
        appMode: AppMode.internal,
        filterOverride: scope,
        controller: _controller,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_browseItems?.isNotEmpty ?? false)
          Offstage(
            key: ValueKey(scope),
            offstage: !showBrowse,
            child: TickerMode(
              enabled: showBrowse,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (showBrowse &&
                      notification.depth == 0 &&
                      notification is ScrollUpdateNotification &&
                      notification.metrics.extentAfter < 600) {
                    widget.onLoadMore();
                  }
                  return false;
                },
                child: _browseList!,
              ),
            ),
          ),
        if (!showBrowse) widget.fallback,
      ],
    );
  }
}

/// Keeps the same position type when temporarily leaving a NestedScrollView.
/// Switching to a plain controller would recreate its specialized position.
class _RetainedScrollController extends ScrollController {
  ScrollController? _parent;
  bool _active = false;

  void connect(ScrollController? parent, bool active) {
    if (identical(parent, _parent) && active == _active) return;
    if (_active) {
      for (final position in positions) {
        _parent?.detach(position);
      }
    }
    _parent = parent;
    _active = active;
    if (_active) {
      for (final position in positions) {
        _parent?.attach(position);
      }
    }
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) =>
      _parent?.createScrollPosition(physics, context, oldPosition) ??
      super.createScrollPosition(physics, context, oldPosition);

  @override
  void attach(ScrollPosition position) {
    super.attach(position);
    if (_active) _parent?.attach(position);
  }

  @override
  void detach(ScrollPosition position) {
    if (_active) _parent?.detach(position);
    super.detach(position);
  }
}
