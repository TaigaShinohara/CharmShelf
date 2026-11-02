import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/feedback_providers.dart';
import '../../../gen_l10n/app_localizations.dart';
import 'onboarding_page.dart';

/// A self-paced introduction. Examples never gate navigation.
class OnboardingView extends ConsumerStatefulWidget {
  const OnboardingView({
    super.key,
    required this.pages,
    required this.onComplete,
    this.completionLabel,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.allowSwipe = true,
    this.onPageChanged,
  });

  final List<OnboardingPage> pages;
  final VoidCallback onComplete;
  final String? completionLabel;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final bool allowSwipe;
  final ValueChanged<int>? onPageChanged;

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView> {
  final _controller = PageController();
  int _index = 0;
  bool _completed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _move(int index) {
    ref.read(feedbackServiceProvider).lightImpact();
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      _controller.jumpToPage(index);
    } else {
      _controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _finish(VoidCallback action) {
    if (_completed) return;
    setState(() => _completed = true);
    action();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final last = _index == widget.pages.length - 1;
    return PopScope(
      canPop: _index == 0 || _completed,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _index > 0 && !_completed) _move(_index - 1);
      },
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewport) => Column(
              children: [
                if (widget.pages.length > 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        '${_index + 1} / ${widget.pages.length}',
                        key: const ValueKey('onboarding-page-progress'),
                        semanticsLabel: l10n.onboardingPagePosition(
                          _index + 1,
                          widget.pages.length,
                        ),
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                  ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    physics: widget.allowSwipe
                        ? null
                        : const NeverScrollableScrollPhysics(),
                    itemCount: widget.pages.length,
                    onPageChanged: (index) {
                      setState(() => _index = index);
                      widget.onPageChanged?.call(index);
                    },
                    itemBuilder: (context, index) {
                      final page = widget.pages[index];
                      return SingleChildScrollView(
                        key: PageStorageKey('onboarding-page-$index'),
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (page.content == null) ...[
                                  ExcludeSemantics(
                                    child: Icon(
                                      page.icon,
                                      size: 36,
                                      color:
                                          page.accentColor ??
                                          theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                Semantics(
                                  header: true,
                                  child: Text(
                                    page.title,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                if (page.descriptionBeforeContent) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    page.description,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                ],
                                if (page.content != null) ...[
                                  const SizedBox(height: 24),
                                  page.content!,
                                ],
                                if (!page.descriptionBeforeContent) ...[
                                  const SizedBox(height: 20),
                                  Text(
                                    page.description,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                ],
                                if (page.label != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    page.label!,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.labelLarge,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // The footer can scroll on exceptionally short/large-text displays.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: viewport.maxHeight * .45,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          key: const ValueKey('onboarding-next'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed:
                              _completed || !widget.pages[_index].canProceed
                              ? null
                              : () => last
                                    ? _finish(widget.onComplete)
                                    : _move(_index + 1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              last
                                  ? widget.completionLabel ??
                                        l10n.onboardingStart
                                  : l10n.onboardingNext,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        if (last && widget.onSecondaryAction != null)
                          TextButton(
                            key: const ValueKey('onboarding-sample'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: _completed
                                ? null
                                : () => _finish(widget.onSecondaryAction!),
                            child: Text(
                              widget.secondaryActionLabel!,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        if (_index > 0)
                          TextButton(
                            key: const ValueKey('onboarding-previous'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: _completed
                                ? null
                                : () => _move(_index - 1),
                            child: Text(l10n.onboardingPrevious),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
