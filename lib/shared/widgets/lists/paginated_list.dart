import 'package:flutter/material.dart';
import '../widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

import '../../../core/error/app_error.dart';
import '../../../core/feedback/feedback_providers.dart';

/// ローカルDB向けの簡易ページネーションリスト（offset/limit型）
class PaginatedList<T> extends ConsumerStatefulWidget {
  const PaginatedList({
    super.key,
    required this.pageLoader,
    required this.itemBuilder,
    this.pageSize = 50,
    this.emptyTitle,
    this.emptySubtitle,
    this.padding,
    this.physics,
  });

  /// (offset, limit) を受け取り、次ページの items を返す
  final Future<List<T>> Function(int offset, int limit) pageLoader;

  final Widget Function(BuildContext context, T item) itemBuilder;

  final int pageSize;
  final String? emptyTitle;
  final String? emptySubtitle;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;

  @override
  ConsumerState<PaginatedList<T>> createState() => _PaginatedListState<T>();
}

class _PaginatedListState<T> extends ConsumerState<PaginatedList<T>> {
  final _controller = ScrollController();

  final List<T> _items = [];
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  AppError? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    if (_isLoadingMore || _isLoadingInitial || !_hasMore) return;
    final max = _controller.position.maxScrollExtent;
    final current = _controller.position.pixels;
    if (max - current < 200) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoadingInitial = true;
      _isLoadingMore = false;
      _hasMore = true;
      _error = null;
      _items.clear();
    });

    try {
      final page = await widget.pageLoader(0, widget.pageSize);
      setState(() {
        _items.addAll(page);
        _hasMore = page.length >= widget.pageSize;
        _isLoadingInitial = false;
      });
    } catch (e, st) {
      setState(() {
        _error = e is AppError
            ? e
            : AppError.unknown('エラーが発生しました', original: e, stackTrace: st);
        _isLoadingInitial = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() {
      _isLoadingMore = true;
      _error = null;
    });

    try {
      final page = await widget.pageLoader(_items.length, widget.pageSize);
      setState(() {
        _items.addAll(page);
        _hasMore = page.length >= widget.pageSize;
        _isLoadingMore = false;
      });
    } catch (e, st) {
      setState(() {
        _error = e is AppError
            ? e
            : AppError.unknown('エラーが発生しました', original: e, stackTrace: st);
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoadingInitial) return const LoadingWidget();

    if (_error != null && _items.isEmpty) {
      return ErrorStateWidget(error: _error!, onRetry: _loadInitial);
    }

    if (_items.isEmpty) {
      return EmptyStateWidget(
        title: widget.emptyTitle ?? l10n.commonEmptyTitle,
        subtitle: widget.emptySubtitle,
      );
    }

    return ListView.builder(
      controller: _controller,
      padding: widget.padding,
      physics: widget.physics,
      itemCount: _items.length + 1,
      itemBuilder: (context, index) {
        if (index < _items.length) {
          return widget.itemBuilder(context, _items[index]);
        }

        if (_error != null) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(enableFeedback: false),
              onPressed: () {
                ref.read(feedbackServiceProvider).lightImpact();
                _loadMore();
              },
              child: AppText(l10n.commonRetry),
            ),
          );
        }

        if (!_hasMore) return const SizedBox(height: 24);

        return const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
