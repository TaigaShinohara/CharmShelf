import 'package:flutter/material.dart';
import '../../shared/widgets/widgets.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../gen_l10n/app_localizations.dart';
import '../error/app_error.dart';
import '../error/result.dart';
import '../logger/app_logger.dart';
import '../logger/log_tag.dart';

/// アプリ評価（レビュー依頼）サービス
///
/// 目的:
/// - 起動回数や利用日数などの条件でレビュー依頼を表示
/// - 「後で」「二度と表示しない」を提供して、しつこくならないようにする
class AppReviewService {
  AppReviewService({InAppReview? inAppReview})
    : _inAppReview = inAppReview ?? InAppReview.instance;

  final InAppReview _inAppReview;

  // prefs keys
  static const _launchCountKey = 'app_review.launch_count';
  static const _firstLaunchAtKey = 'app_review.first_launch_at';
  static const _neverAskAgainKey = 'app_review.never_ask_again';
  static const _lastPromptAtKey = 'app_review.last_prompt_at';

  // template defaults (調整しやすい値)
  static const int defaultMinLaunchCount = 7;
  static const int defaultMinDaysSinceFirstLaunch = 3;
  static const int defaultCooldownDays = 30;

  Future<void> recordAppLaunch(SharedPreferences prefs) async {
    final count = (prefs.getInt(_launchCountKey) ?? 0) + 1;
    await prefs.setInt(_launchCountKey, count);

    final first = prefs.getString(_firstLaunchAtKey);
    if (first == null || first.isEmpty) {
      await prefs.setString(
        _firstLaunchAtKey,
        DateTime.now().toIso8601String(),
      );
    }
  }

  bool getNeverAskAgain(SharedPreferences prefs) {
    return prefs.getBool(_neverAskAgainKey) ?? false;
  }

  Future<void> setNeverAskAgain(SharedPreferences prefs, bool value) async {
    await prefs.setBool(_neverAskAgainKey, value);
  }

  Future<void> markPromptedNow(SharedPreferences prefs) async {
    await prefs.setString(_lastPromptAtKey, DateTime.now().toIso8601String());
  }

  Result<bool, AppError> shouldPrompt(
    SharedPreferences prefs, {
    int minLaunchCount = defaultMinLaunchCount,
    int minDaysSinceFirstLaunch = defaultMinDaysSinceFirstLaunch,
    int cooldownDays = defaultCooldownDays,
  }) {
    try {
      if (getNeverAskAgain(prefs)) return Result.success(false);

      final launchCount = prefs.getInt(_launchCountKey) ?? 0;
      if (launchCount < minLaunchCount) return Result.success(false);

      final firstAt = DateTime.tryParse(
        prefs.getString(_firstLaunchAtKey) ?? '',
      );
      if (firstAt != null) {
        final days = DateTime.now().difference(firstAt).inDays;
        if (days < minDaysSinceFirstLaunch) return Result.success(false);
      }

      final lastPromptAt = DateTime.tryParse(
        prefs.getString(_lastPromptAtKey) ?? '',
      );
      if (lastPromptAt != null) {
        final days = DateTime.now().difference(lastPromptAt).inDays;
        if (days < cooldownDays) return Result.success(false);
      }

      return Result.success(true);
    } catch (e, st) {
      AppLogger.e(LogTag.app, 'shouldPrompt failed', e, st);
      return Result.failure(
        AppError.unknown('レビュー判定に失敗しました', original: e, stackTrace: st),
      );
    }
  }

  Future<void> maybePromptReview(
    BuildContext context,
    SharedPreferences prefs, {
    int minLaunchCount = defaultMinLaunchCount,
    int minDaysSinceFirstLaunch = defaultMinDaysSinceFirstLaunch,
    int cooldownDays = defaultCooldownDays,
  }) async {
    // 条件判定
    final eligible = shouldPrompt(
      prefs,
      minLaunchCount: minLaunchCount,
      minDaysSinceFirstLaunch: minDaysSinceFirstLaunch,
      cooldownDays: cooldownDays,
    );
    if (eligible.isFailure) return;
    if (eligible.dataOrNull != true) return;

    // ここで「表示した」扱いにして、連続表示を防ぐ
    await markPromptedNow(prefs);

    if (!context.mounted) return;
    final action = await _showReviewDialog(context);
    if (action == null) return;

    switch (action) {
      case _ReviewAction.later:
        return;
      case _ReviewAction.never:
        await setNeverAskAgain(prefs, true);
        return;
      case _ReviewAction.review:
        try {
          final available = await _inAppReview.isAvailable();
          if (!available) return;
          await _inAppReview.requestReview();
        } catch (e, st) {
          AppLogger.e(LogTag.app, 'requestReview failed', e, st);
        }
    }
  }

  Future<_ReviewAction?> _showReviewDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return showDialog<_ReviewAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          key: const ValueKey('app-review-dialog'),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ReviewDialogArtwork(colors: colors),
                const SizedBox(height: 18),
                AppText(
                  l10n.reviewTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                AppText(
                  l10n.reviewMessage,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const ValueKey('app-review-later-button'),
                        onPressed: () =>
                            Navigator.of(context).pop(_ReviewAction.later),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: AppText(l10n.reviewLater),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        key: const ValueKey('app-review-rate-button'),
                        onPressed: () =>
                            Navigator.of(context).pop(_ReviewAction.review),
                        icon: const Icon(Icons.star_rounded, size: 19),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        label: AppText(l10n.reviewButton),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  key: const ValueKey('app-review-never-button'),
                  onPressed: () =>
                      Navigator.of(context).pop(_ReviewAction.never),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.onSurfaceVariant,
                    visualDensity: VisualDensity.compact,
                    textStyle: theme.textTheme.labelSmall,
                  ),
                  child: AppText(l10n.reviewNever),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReviewDialogArtwork extends StatelessWidget {
  const _ReviewDialogArtwork({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.rate_review_rounded,
              size: 36,
              color: colors.onPrimaryContainer,
            ),
          ),
          Positioned(
            top: 2,
            right: 4,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: colors.tertiary,
            ),
          ),
          Positioned(
            bottom: 3,
            left: 2,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: colors.secondary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ReviewAction { review, later, never }
