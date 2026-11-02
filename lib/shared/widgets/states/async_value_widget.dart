import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

import '../../../core/error/app_error.dart';
import 'error_state_widget.dart';
import 'loading_widget.dart';

class AsyncValueWidget<T> extends StatelessWidget {
  const AsyncValueWidget({
    super.key,
    required this.value,
    required this.builder,
    this.loading,
    this.errorBuilder,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final Widget? loading;
  final Widget Function(AppError error)? errorBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return value.when(
      data: builder,
      loading: () => loading ?? const LoadingWidget(),
      error: (e, st) {
        final appError = e is AppError
            ? e
            : AppError.unknown(
                l10n.commonErrorOccurred,
                original: e,
                stackTrace: st,
              );
        if (errorBuilder != null) return errorBuilder!(appError);
        return ErrorStateWidget(error: appError);
      },
    );
  }
}
