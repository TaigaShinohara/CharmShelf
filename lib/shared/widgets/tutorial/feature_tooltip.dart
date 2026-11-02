import 'package:flutter/material.dart';
import '../widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/feedback_providers.dart';
import '../../../core/providers/shared_preferences_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../gen_l10n/app_localizations.dart';

/// 特定要素に対するツールチップ（初回のみ自動表示）
///
/// - `featureId` ごとに表示済みを SharedPreferences に保存します
/// - 「閉じる」「二度と表示しない」を提供
class FeatureTooltip extends ConsumerStatefulWidget {
  const FeatureTooltip({
    super.key,
    required this.featureId,
    required this.message,
    required this.child,
    this.enabled = true,
    this.showOnce = true,
  });

  final String featureId;
  final String message;
  final Widget child;
  final bool enabled;
  final bool showOnce;

  @override
  ConsumerState<FeatureTooltip> createState() => _FeatureTooltipState();
}

class _FeatureTooltipState extends ConsumerState<FeatureTooltip> {
  final _layerLink = LayerLink();
  OverlayEntry? _entry;
  bool _scheduled = false;

  String get _shownKey => 'feature_tooltip.${widget.featureId}.shown';
  String get _neverKey => 'feature_tooltip.${widget.featureId}.never';

  Future<bool> _shouldShow() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final never = prefs.getBool(_neverKey) ?? false;
    if (never) return false;
    if (!widget.showOnce) return true;
    return !(prefs.getBool(_shownKey) ?? false);
  }

  Future<void> _markShown() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(_shownKey, true);
  }

  Future<void> _setNever() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(_neverKey, true);
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
  }

  void _show() {
    if (_entry != null) return;

    _entry = OverlayEntry(
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hide,
                child: Container(color: Colors.transparent),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              followerAnchor: Alignment.topCenter,
              targetAnchor: Alignment.bottomCenter,
              offset: const Offset(0, 8),
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 12,
                          color: AppColors.shadow.withValues(alpha: 0.26),
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppText(widget.message),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () async {
                                  ref
                                      .read(feedbackServiceProvider)
                                      .lightImpact();
                                  await _setNever();
                                  _hide();
                                },
                                child: AppText(l10n.tooltipNeverShow),
                              ),
                              const Spacer(),
                              FilledButton(
                                onPressed: () {
                                  ref
                                      .read(feedbackServiceProvider)
                                      .lightImpact();
                                  _hide();
                                },
                                child: AppText(l10n.tooltipClose),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    overlay.insert(_entry!);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.enabled) return;
    if (_scheduled) return;
    _scheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ok = await _shouldShow();
      if (!ok) return;
      await _markShown();
      if (!mounted) return;
      _show();
    });
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(link: _layerLink, child: widget.child);
  }
}
