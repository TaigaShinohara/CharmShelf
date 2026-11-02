import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:private_shelf/app/initialization_flow.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/core/preferences/app_preferences.dart';
import 'package:private_shelf/core/providers/tab_navigation_provider.dart';
import 'package:private_shelf/features/onboarding/presentation/onboarding_screen.dart';
import 'package:private_shelf/features/samples/data/sample_preview_service.dart';
import 'package:private_shelf/features/samples/presentation/sample_preview_screen.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';
import 'package:private_shelf/features/settings/presentation/tutorial_list_page.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/app/initialization_flow_screen.dart';
import 'package:private_shelf/features/security/presentation/providers/security_guard_provider.dart';
import 'package:private_shelf/features/splash/presentation/screens/app_splash_screen.dart';

class _PendingSecurityGuard extends SecurityGuard {
  _PendingSecurityGuard(this.result);

  final Future<bool> result;

  @override
  Future<bool> build() => result;
}

class _FailingSecurityGuard extends SecurityGuard {
  @override
  Future<bool> build() async => throw StateError('security settings failed');
}

class _OnboardingFlow extends InitializationFlowNotifier {
  int completions = 0;

  @override
  Future<InitFlowState> build() async => InitFlowState.onboarding;

  @override
  Future<void> completeOnboarding({bool skipped = false}) async {
    completions++;
    // The widget contract is under test; the real ready screen has its own
    // repository integration tests and need not be mounted here.
  }
}

class _InternalMode extends AppModeAsync {
  @override
  Future<AppMode> build() async => AppMode.internal;

  @override
  Future<bool> setMode(AppMode mode) async => true;
}

class _MissingSampleBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => throw StateError('missing sample');
}

Widget _localized(Widget home) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  testWidgets('初期化画面は動画スプラッシュを重複生成しない', (tester) async {
    final pending = Completer<bool>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          securityGuardProvider.overrideWith(
            () => _PendingSecurityGuard(pending.future),
          ),
        ],
        child: const MaterialApp(home: InitializationFlowScreen()),
      ),
    );

    expect(find.byType(AppSplashScreen), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('ロック判定に失敗したらスプラッシュを抜けて再試行できる', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          securityGuardProvider.overrideWith(_FailingSecurityGuard.new),
        ],
        child: const MaterialApp(home: InitializationFlowScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(InitializationFlowScreen), findsOneWidget);
    expect(find.text('Initialization failed'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets(
    'the first add action completes onboarding once and hands off file import',
    (tester) async {
      final flow = _OnboardingFlow();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            securityGuardProvider.overrideWith(
              () => _PendingSecurityGuard(Future.value(false)),
            ),
            initializationFlowAsyncProvider.overrideWith(() => flow),
            appModeAsyncProvider.overrideWith(_InternalMode.new),
            hapticsEnabledProvider.overrideWith((ref) => false),
          ],
          child: _localized(
            const MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: InitializationFlowScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingScreen)),
      );
      container.read(currentTabIndexProvider.notifier).goToHome();
      expect(
        container.read(currentTabIndexProvider),
        AppPreferences.homeTabIndex,
      );
      final next = find.byKey(const ValueKey('onboarding-next'));
      expect(
        find.byKey(const ValueKey('onboarding-page-progress')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('onboarding-need-gather')),
        findsNothing,
      );
      expect(flow.completions, 0);
      expect(container.read(pendingLibraryLaunchActionProvider), isNull);
      expect(tester.widget<FilledButton>(next).onPressed, isNotNull);
      await tester.ensureVisible(next);
      // Two taps before rebuilding exercise the actual completion guard.
      await tester.tap(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(flow.completions, 1);
      expect(
        container.read(currentTabIndexProvider),
        AppPreferences.libraryTabIndex,
      );
      expect(
        container.read(pendingLibraryLaunchActionProvider),
        LibraryLaunchAction.importFile,
      );
    },
  );

  for (final addFiles in [false, true]) {
    testWidgets(
      'sample completes onboarding only after leaving and add intent=$addFiles',
      (tester) async {
        final flow = _OnboardingFlow();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              securityGuardProvider.overrideWith(
                () => _PendingSecurityGuard(Future.value(false)),
              ),
              initializationFlowAsyncProvider.overrideWith(() => flow),
              appModeAsyncProvider.overrideWith(_InternalMode.new),
              hapticsEnabledProvider.overrideWith((ref) => false),
              samplePreviewServiceProvider.overrideWith(
                (ref) => SamplePreviewService(_MissingSampleBundle()),
              ),
            ],
            child: _localized(const InitializationFlowScreen()),
          ),
        );
        await tester.pumpAndSettle();
        final onboarding = tester.widget<OnboardingScreen>(
          find.byType(OnboardingScreen),
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(OnboardingScreen)),
        );
        onboarding.onTrySample!();
        await tester.pumpAndSettle();
        expect(find.byType(SamplePreviewScreen), findsOneWidget);
        expect(flow.completions, 0);
        expect(container.read(pendingLibraryLaunchActionProvider), isNull);
        final sample = tester.widget<SamplePreviewScreen>(
          find.byType(SamplePreviewScreen),
        );
        if (addFiles) {
          sample.onAddFiles!();
        } else {
          Navigator.of(tester.element(find.byType(SamplePreviewScreen))).pop();
        }
        await tester.pumpAndSettle();
        expect(flow.completions, 1);
        expect(find.byType(SamplePreviewScreen), findsNothing);
        expect(
          container.read(pendingLibraryLaunchActionProvider),
          addFiles ? LibraryLaunchAction.importFile : null,
        );
      },
    );
  }

  testWidgets(
    'settings replays the introduction without initialization or add side effects',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hasPasscodeProvider.overrideWith((ref) async => false),
            hapticsEnabledProvider.overrideWith((ref) => false),
          ],
          child: _localized(const TutorialListPage()),
        ),
      );
      await tester.pumpAndSettle();
      final pageContext = tester.element(find.byType(TutorialListPage));
      final l10n = AppLocalizations.of(pageContext)!;
      final container = ProviderScope.containerOf(pageContext);
      await tester.tap(find.text(l10n.tutorialOnboardingTitle));
      await tester.pumpAndSettle();
      final onboarding = tester.widget<OnboardingScreen>(
        find.byType(OnboardingScreen),
      );
      expect(onboarding.preview, isTrue);
      expect(onboarding.onTrySample, isNull);
      onboarding.onComplete();
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(TutorialListPage), findsOneWidget);
      expect(container.read(pendingLibraryLaunchActionProvider), isNull);
    },
  );
}
