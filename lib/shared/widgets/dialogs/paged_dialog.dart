import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import '../widgets.dart';

import '../../../core/feedback/feedback_providers.dart';

/// ページ送り付きの汎用ダイアログ。
///
/// - 例: 利用規約の段階表示、機能説明、初期設定ウィザード
class PagedDialog extends ConsumerStatefulWidget {
  const PagedDialog({
    super.key,
    this.title,
    required this.pages,
    this.initialPage = 0,
    this.onFinish,
    this.nextLabel,
    this.backLabel,
    this.finishLabel,
  });

  final String? title;
  final List<Widget> pages;
  final int initialPage;
  final VoidCallback? onFinish;

  final String? nextLabel;
  final String? backLabel;
  final String? finishLabel;

  @override
  ConsumerState<PagedDialog> createState() => _PagedDialogState();
}

class _PagedDialogState extends ConsumerState<PagedDialog> {
  late final PageController _controller;
  int _index = 0;

  bool get _isLast =>
      widget.pages.isEmpty ? true : _index >= widget.pages.length - 1;

  @override
  void initState() {
    super.initState();
    // pages が空の場合でも落ちないようにガード
    if (widget.pages.isEmpty) {
      _index = 0;
    } else {
      _index = widget.initialPage.clamp(0, widget.pages.length - 1);
    }
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    ref.read(feedbackServiceProvider).lightImpact();
    if (_isLast) {
      widget.onFinish?.call();
      Navigator.of(context).pop();
      return;
    }
    await _controller.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _back() async {
    ref.read(feedbackServiceProvider).lightImpact();
    if (_index <= 0) return;
    await _controller.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (widget.pages.isEmpty) {
      // 空のときはクラッシュ回避し、説明だけ出して閉じられるようにする
      return AlertDialog(
        title: widget.title == null ? null : AppText(widget.title!),
        content: AppText(l10n.commonNoPages),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(enableFeedback: false),
            onPressed: () {
              ref.read(feedbackServiceProvider).lightImpact();
              Navigator.of(context).pop();
            },
            child: AppText(l10n.commonClose),
          ),
        ],
      );
    }

    return AlertDialog(
      title: widget.title == null ? null : AppText(widget.title!),
      content: SizedBox(
        width: double.maxFinite,
        height: 280,
        child: PageView(
          controller: _controller,
          onPageChanged: (i) => setState(() => _index = i),
          children: widget.pages,
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppText(
                  '${_index + 1}/${widget.pages.length}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              const SizedBox(height: 8),
              DialogActionRow(
                leading: _index == 0
                    ? DialogCloseButton(
                        onPressed: () => Navigator.of(context).pop(),
                        semanticLabel: l10n.commonClose,
                      )
                    : TextButton(
                        style: TextButton.styleFrom(
                          enableFeedback: false,
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: _back,
                        child: AppText(widget.backLabel ?? l10n.commonBack),
                      ),
                trailing: FilledButton(
                  style: FilledButton.styleFrom(
                    enableFeedback: false,
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: _next,
                  child: AppText(
                    _isLast
                        ? (widget.finishLabel ?? l10n.commonClose)
                        : (widget.nextLabel ?? l10n.commonNext),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ページ内に続きがあることを常時表示する、ダイアログ向けスクロール領域。
class ScrollableDialogPage extends StatefulWidget {
  const ScrollableDialogPage({
    super.key,
    required this.child,
    this.padding = const EdgeInsetsDirectional.fromSTEB(0, 8, 12, 8),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  State<ScrollableDialogPage> createState() => _ScrollableDialogPageState();
}

class _ScrollableDialogPageState extends State<ScrollableDialogPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      trackVisibility: true,
      interactive: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: widget.padding,
        child: widget.child,
      ),
    );
  }
}

Future<void> showPagedDialog(
  BuildContext context, {
  String? title,
  required List<Widget> pages,
  int initialPage = 0,
  VoidCallback? onFinish,
  bool barrierDismissible = false,
  bool useRootNavigator = false,
  String? nextLabel,
  String? backLabel,
  String? finishLabel,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    useRootNavigator: useRootNavigator,
    builder: (context) => PagedDialog(
      title: title,
      pages: pages,
      initialPage: initialPage,
      onFinish: onFinish,
      nextLabel: nextLabel,
      backLabel: backLabel,
      finishLabel: finishLabel,
    ),
  );
}
