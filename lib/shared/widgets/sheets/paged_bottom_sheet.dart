import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import '../widgets.dart';
import 'sheet_handle.dart';

import '../../../core/feedback/feedback_providers.dart';

/// ページ送り付きの汎用ボトムシート。
///
/// - 例: かんたんな設定ウィザード、機能説明、段階的な選択 UI
class PagedBottomSheet extends ConsumerStatefulWidget {
  const PagedBottomSheet({
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
  ConsumerState<PagedBottomSheet> createState() => _PagedBottomSheetState();
}

class _PagedBottomSheetState extends ConsumerState<PagedBottomSheet> {
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
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.title != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppText(
                    widget.title!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: AppText(l10n.commonNoPages),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () {
                    ref.read(feedbackServiceProvider).lightImpact();
                    Navigator.of(context).pop();
                  },
                  child: AppText(l10n.commonClose),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            if (widget.title != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.title!,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              height: 240,
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                children: widget.pages,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                AppText(
                  '${_index + 1}/${widget.pages.length}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const Spacer(),
                TextButton(
                  onPressed: _index == 0 ? null : _back,
                  child: AppText(widget.backLabel ?? l10n.commonBack),
                ),
                FilledButton(
                  onPressed: _next,
                  child: AppText(
                    _isLast
                        ? (widget.finishLabel ?? l10n.commonClose)
                        : (widget.nextLabel ?? l10n.commonNext),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showPagedBottomSheet(
  BuildContext context, {
  String? title,
  required List<Widget> pages,
  int initialPage = 0,
  VoidCallback? onFinish,
  String? nextLabel,
  String? backLabel,
  String? finishLabel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (context) => PagedBottomSheet(
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
