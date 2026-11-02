import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

import '../../../core/error/app_error.dart';
import '../states/empty_state_widget.dart';
import '../states/error_state_widget.dart';
import '../states/loading_widget.dart';

/// Pull to refresh に対応したリスト
class RefreshableList<T> extends StatelessWidget {
  const RefreshableList({
    super.key,
    required this.value,
    required this.onRefresh,
    required this.itemBuilder,
    this.emptyTitle,
    this.emptySubtitle,
    this.padding,
    this.physics,
  });

  final AsyncValue<List<T>> value;
  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext context, T item) itemBuilder;

  final String? emptyTitle;
  final String? emptySubtitle;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return value.when(
      loading: () => const LoadingWidget(),
      error: (e, st) {
        final appError = e is AppError
            ? e
            : AppError.unknown(
                l10n.commonErrorOccurred,
                original: e,
                stackTrace: st,
              );
        return ErrorStateWidget(error: appError, onRetry: () => onRefresh());
      },
      data: (items) {
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                EmptyStateWidget(
                  title: emptyTitle ?? l10n.commonEmptyTitle,
                  subtitle: emptySubtitle,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.builder(
            padding: padding,
            physics: physics,
            itemCount: items.length,
            itemBuilder: (context, index) => itemBuilder(context, items[index]),
          ),
        );
      },
    );
  }
}
