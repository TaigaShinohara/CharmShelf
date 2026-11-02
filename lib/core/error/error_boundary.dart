import 'package:flutter/material.dart';

import '../../gen_l10n/app_localizations.dart';
import 'app_error.dart';
import 'app_error_extension.dart';
import 'error_handler.dart';

/// エラー境界ウィジェット
///
/// 子ウィジェットツリー内で発生したエラーをキャッチし、
/// フォールバックUIを表示します。
///
/// 使用例:
/// ```dart
/// ErrorBoundary(
///   child: MyWidget(),
///   onError: (error) => print('Error occurred: $error'),
/// )
/// ```
class ErrorBoundary extends StatefulWidget {
  /// 保護する子ウィジェット
  final Widget child;

  /// カスタムエラーUIビルダー
  final Widget Function(
    BuildContext context,
    AppError error,
    VoidCallback retry,
  )?
  errorBuilder;

  /// エラー発生時のコールバック
  final void Function(AppError error)? onError;

  /// デフォルトエラーUIを表示するか
  final bool showDefaultErrorUI;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
    this.onError,
    this.showDefaultErrorUI = true,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  AppError? _error;

  @override
  Widget build(BuildContext context) {
    // エラーが発生している場合
    if (_error != null) {
      // カスタムエラービルダーがある場合
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context, _error!, _retry);
      }

      // デフォルトエラーUIを表示
      if (widget.showDefaultErrorUI) {
        return _DefaultErrorWidget(error: _error!, onRetry: _retry);
      }
    }

    // エラーをキャッチするためにErrorWidgetをカスタマイズ
    return _ErrorCatcher(onError: _handleError, child: widget.child);
  }

  void _handleError(Object error, StackTrace? stackTrace) {
    // AppErrorに変換
    final appError = error is AppError
        ? error
        : AppError.ui(
            error.toString(),
            severity: ErrorSeverity.warning,
            original: error,
            stackTrace: stackTrace,
            context: 'ErrorBoundary',
          );

    setState(() {
      _error = appError;
    });

    // コールバックを呼び出し
    widget.onError?.call(appError);

    // GlobalErrorHandlerに報告
    GlobalErrorHandler.reportWidgetError(
      error,
      stackTrace,
      widgetName: widget.child.runtimeType.toString(),
    );
  }

  void _retry() {
    setState(() {
      _error = null;
    });
  }
}

/// エラーをキャッチするための内部ウィジェット
class _ErrorCatcher extends StatelessWidget {
  final Widget child;
  final void Function(Object error, StackTrace? stackTrace) onError;

  const _ErrorCatcher({required this.child, required this.onError});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// デフォルトエラー表示ウィジェット
class _DefaultErrorWidget extends StatelessWidget {
  final AppError error;
  final VoidCallback onRetry;

  const _DefaultErrorWidget({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              l10n.commonErrorOccurred,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.localizedMessage(l10n),
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
