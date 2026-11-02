import '../features/library/presentation/providers/legacy_migration_provider.dart';
import '../features/onboarding/presentation/legacy_welcome_screen.dart';
import '../features/onboarding/data/fresh_start_service.dart';
import 'dart:async';
import '../features/samples/presentation/sample_preview_screen.dart';

import 'package:flutter/material.dart';
import '../features/library/presentation/screens/legacy_migration_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/feature_flags.dart';
import '../core/feedback/feedback_providers.dart';
import '../core/providers/shared_preferences_provider.dart';
import '../core/providers/tab_navigation_provider.dart';
import '../core/router/deep_link_handler.dart';
import '../core/services/app_review_service.dart';
import '../core/services/version_check_service.dart';
import '../features/home/presentation/home_page.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/security/presentation/providers/security_guard_provider.dart';
import '../features/tab_navigation/presentation/main_tab_page.dart';
import '../features/settings/presentation/providers/app_mode_provider.dart';
import '../features/library/presentation/providers/data_restore_provider.dart';
import '../features/library/presentation/screens/data_restore_screen.dart';
import '../gen_l10n/app_localizations.dart';
import 'initialization_flow.dart';

/// ディープリンクのナビゲーションを処理します
///
/// タブ画面内のルートはタブインデックスで切り替え、
/// それ以外のルートはGoRouterで直接遷移します。
void _handleDeepLinkNavigation(
  BuildContext context,
  WidgetRef ref,
  String location,
) {
  switch (DeepLinkHandler.tabTargetFor(location)) {
    case DeepLinkTabTarget.library:
      ref.read(currentTabIndexProvider.notifier).goToLibrary();
    case DeepLinkTabTarget.home:
      ref.read(currentTabIndexProvider.notifier).goToHome();
    case DeepLinkTabTarget.preserve:
      // 設定等のグローバル画面では、戻ったときのタブを勝手に変更しない。
      context.push(location);
  }
}

/// 保留中のディープリンクを処理します
Future<void> _processPendingDeepLink(
  BuildContext context,
  WidgetRef ref,
  String location,
) async {
  // 先にクリアして、同じリンクでループしないようにする
  await ref.read(deepLinkHandlerProvider).clearPending(ref);
  if (!context.mounted) return;

  _handleDeepLinkNavigation(context, ref, location);
}

class InitializationFlowScreen extends ConsumerWidget {
  const InitializationFlowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final securityGuard = ref.watch(securityGuardProvider);
    if (securityGuard.hasError) {
      return _StartupFlowError(
        onRetry: () => ref.invalidate(securityGuardProvider),
      );
    }
    if (securityGuard.isLoading) {
      return const _InitializationProgress();
    }

    final flow = ref.watch(initializationFlowAsyncProvider);

    // ディープリンク: 受信監視を起動（初回のみ）
    if (FeatureFlags.enableDeepLink) {
      ref.read(deepLinkHandlerProvider).ensureStarted(ref);
    }

    // 初期化フローの状態変化を画面遷移として扱い、触覚フィードバックを出す
    // AsyncValueを監視し、データが確定（ready）したタイミングで実行
    ref.listen(initializationFlowAsyncProvider, (prev, next) async {
      final prevState = prev?.asData?.value;
      final nextState = next.asData?.value;
      if (nextState == null) return;
      if (prevState == nextState) return;

      unawaited(ref.read(feedbackServiceProvider).lightImpact());

      // ready になったタイミングでの処理
      if (nextState == InitFlowState.ready &&
          !ref.read(legacyScreenOpenProvider)) {
        // 保留中のディープリンクがあれば処理
        final pending = ref.read(pendingDeepLinkLocationProvider);
        if (pending != null && pending.isNotEmpty) {
          await _processPendingDeepLink(context, ref, pending);
        }

        if (!context.mounted) return;

        try {
          // 強制アップデート（最優先）
          if (FeatureFlags.enableForceUpdate) {
            await VersionCheckService().showForceUpdateDialogIfNeeded(context);
          }

          // レビュー促進
          if (FeatureFlags.enableAppReview) {
            final prefs = await ref.read(sharedPreferencesProvider.future);
            if (!context.mounted) return;
            await AppReviewService().maybePromptReview(context, prefs);
          }
        } catch (_) {
          // best effort
        }
      }
    });

    // ディープリンク: ready の時だけ遷移（未完了なら保留）
    ref.listen(pendingDeepLinkLocationProvider, (prev, next) async {
      if (next == null || next.isEmpty) return;
      final state = ref.read(initializationFlowProvider);
      if (state != InitFlowState.ready || ref.read(legacyScreenOpenProvider)) {
        return;
      }

      await _processPendingDeepLink(context, ref, next);
    });

    ref.listen(legacyScreenOpenProvider, (previous, open) async {
      if (!open &&
          ref.read(initializationFlowProvider) == InitFlowState.ready) {
        final pending = ref.read(pendingDeepLinkLocationProvider);
        if (pending != null && pending.isNotEmpty) {
          await _processPendingDeepLink(context, ref, pending);
        }
      }
    });

    return flow.when(
      skipLoadingOnRefresh: true,
      loading: () => const _InitializationProgress(),
      error: (e, st) => _StartupFlowError(
        onRetry: () => ref.invalidate(initializationFlowAsyncProvider),
      ),
      data: (state) {
        final mode = ref.watch(appModeProvider);
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: switch (state) {
            InitFlowState.launch => const _InitializationProgress(),
            InitFlowState.recoveryWarning => StartupRecoveryWarning(
              count: ref.watch(missingCommittedTrashCountProvider),
              onContinue: ref
                  .read(initializationFlowAsyncProvider.notifier)
                  .acknowledgeRecoveryWarning,
              onRetry: ref
                  .read(initializationFlowAsyncProvider.notifier)
                  .retryRecovery,
            ),
            InitFlowState.welcome => LegacyWelcomeScreen(
              hasResidualData: () =>
                  ref.read(freshStartServiceProvider).hasResidualData(),
              onChoice: (choice) => ref
                  .read(initializationFlowAsyncProvider.notifier)
                  .chooseLegacyEntry(choice),
            ),
            InitFlowState.restorePrompt =>
              ref.watch(dataRestoreIsAndroidProvider)
                  ? LegacyMigrationScreen(
                      onDeferred: () => ref
                          .read(initializationFlowAsyncProvider.notifier)
                          .deferLegacyTransfer(),
                      onCompleted: () => ref
                          .read(initializationFlowAsyncProvider.notifier)
                          .completeRestorePrompt(),
                    )
                  : DataRestoreScreen(
                      key: const ValueKey('restore_prompt'),
                      summary: ref.watch(dataRestoreNotifierProvider).summary,
                      onRestoreCompleted: () => ref
                          .read(initializationFlowAsyncProvider.notifier)
                          .completeRestorePrompt(restored: true),
                      onSkipped: () => ref
                          .read(initializationFlowAsyncProvider.notifier)
                          .completeRestorePrompt(restored: false),
                    ),
            InitFlowState.onboarding => OnboardingScreen(
              key: const ValueKey('onboarding'),
              afterWelcome: ref.watch(dataRestoreIsAndroidProvider),
              onTrySample: () {
                final navigator = Navigator.of(context);
                unawaited(() async {
                  final addFiles = await navigator.push<bool>(
                    MaterialPageRoute(
                      builder: (sampleContext) => SamplePreviewScreen(
                        onAddFiles: () => Navigator.of(sampleContext).pop(true),
                      ),
                    ),
                  );
                  if (!context.mounted) return;
                  await ref
                      .read(appModeAsyncProvider.notifier)
                      .setMode(AppMode.internal);
                  if (!context.mounted) return;
                  if (addFiles == true) {
                    ref
                        .read(pendingLibraryLaunchActionProvider.notifier)
                        .requestImportFile();
                    ref.read(currentTabIndexProvider.notifier).goToLibrary();
                  }
                  await ref
                      .read(initializationFlowAsyncProvider.notifier)
                      .completeOnboarding();
                }());
              },
              onComplete: () {
                ref.read(currentTabIndexProvider.notifier).goToLibrary();
                ref
                    .read(pendingLibraryLaunchActionProvider.notifier)
                    .requestImportFile();
                unawaited(() async {
                  // 最終CTAは内部ライブラリの追加メニューへ直結するため、
                  // チュートリアル再実行前のモードに左右されないようにする。
                  await ref
                      .read(appModeAsyncProvider.notifier)
                      .setMode(AppMode.internal);
                  await ref
                      .read(initializationFlowAsyncProvider.notifier)
                      .completeOnboarding();
                }());
              },
            ),
            InitFlowState.ready =>
              FeatureFlags.enableTabBar
                  ? const MainTabPage(key: ValueKey('tabs'))
                  : HomePage(key: ValueKey('home-${mode.name}')),
          },
        );
      },
    );
  }
}

class _InitializationProgress extends StatelessWidget {
  const _InitializationProgress();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Semantics(
        liveRegion: true,
        label: '起動準備中。保存データを確認しています。',
        child: const CircularProgressIndicator(),
      ),
    ),
  );
}

class _StartupFlowError extends StatelessWidget {
  const _StartupFlowError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n?.errorUnknown ?? 'Initialization failed',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n?.commonRetry ?? 'Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// アプリロック内で表示する、完了済みごみ箱項目の欠損案内。
class StartupRecoveryWarning extends StatelessWidget {
  const StartupRecoveryWarning({
    super.key,
    required this.count,
    required this.onContinue,
    required this.onRetry,
  });

  final int count;
  final VoidCallback onContinue;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              l10n.startupTrashMissingTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(l10n.startupTrashMissingMessage(count)),
            const SizedBox(height: 24),
            OutlinedButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onContinue,
              child: Text(l10n.startupTrashMissingContinue),
            ),
          ],
        ),
      ),
    );
  }
}
