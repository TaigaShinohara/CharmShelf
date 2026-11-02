import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/app/fresh_start_scope.dart';
import 'package:private_shelf/app/initialization_flow_screen.dart';
import 'package:private_shelf/core/router/app_router.dart';
import 'package:private_shelf/features/security/presentation/providers/passcode_provider.dart';
import 'package:private_shelf/features/security/presentation/providers/security_guard_provider.dart';
import 'package:private_shelf/shared/widgets/feedback/app_snackbar.dart';

class _ControlledSecurityGuard extends SecurityGuard {
  final _initial = Completer<bool>();

  @override
  Future<bool> build() => _initial.future;

  void show(AsyncValue<bool> value) => state = value;
}

class _RouterSnapshot {
  _RouterSnapshot(this.container, this.router, this.context);

  final ProviderContainer container;
  final GoRouter router;
  final BuildContext context;
}

class _RouterHost extends ConsumerWidget {
  const _RouterHost({required this.onBuild, required this.mountRouter});

  final ValueChanged<_RouterSnapshot> onBuild;
  final bool mountRouter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    onBuild(
      _RouterSnapshot(
        ProviderScope.containerOf(context, listen: false),
        router,
        context,
      ),
    );
    if (mountRouter) {
      return MaterialApp.router(
        routerConfig: router,
        builder: (context, child) =>
            AppSnackBarOverlayHost(child: child ?? const SizedBox.shrink()),
      );
    }
    // Exercise the real redirect without mounting PIN/settings/viewer screens.
    return const MaterialApp(home: SizedBox.shrink());
  }
}

GoRouterState _routeState(GoRouter router, String location, {Object? extra}) =>
    router.configuration.buildTopLevelGoRouterState(
      router.configuration.findMatch(Uri.parse(location), extra: extra),
    );

Future<void> _pumpHost(
  WidgetTester tester,
  ValueChanged<_RouterSnapshot> onBuild, {
  bool mountRouter = true,
}) async {
  await tester.pumpWidget(
    FreshStartScope(
      overrides: [
        securityGuardProvider.overrideWith(_ControlledSecurityGuard.new),
      ],
      child: _RouterHost(onBuild: onBuild, mountRouter: mountRouter),
    ),
  );
  // A pending guard leaves the real root on its startup progress screen.
  // pumpAndSettle would wait forever for that screen's progress animation.
  await tester.pump();
}

Future<void> _restartScope(
  WidgetTester tester,
  _RouterSnapshot snapshot,
) async {
  snapshot.container.read(freshStartCompletedCallbackProvider)();
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('fresh scope replaces overlay content with the current router', (
    tester,
  ) async {
    late _RouterSnapshot latest;
    await _pumpHost(tester, (value) => latest = value);
    final previous = latest;
    final oldContent = tester.element(find.byType(InitializationFlowScreen));
    final oldOverlay = appSnackBarOverlayKey.currentState;
    expect(GoRouter.of(oldContent), same(previous.router));

    await _restartScope(tester, previous);

    final content = tester.element(find.byType(InitializationFlowScreen));
    expect(latest.router, isNot(same(previous.router)));
    expect(
      ProviderScope.containerOf(content, listen: false),
      same(latest.container),
    );
    expect(GoRouter.of(content), same(latest.router));
    expect(content, isNot(same(oldContent)));
    expect(oldContent.mounted, isFalse);
    expect(appSnackBarOverlayKey.currentState, isNot(same(oldOverlay)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('fresh scope leaves stale redirect locked and converges on PIN', (
    tester,
  ) async {
    late _RouterSnapshot latest;
    await _pumpHost(tester, (value) => latest = value);
    final previous = latest;
    final staleRedirect = previous.router.configuration.topRedirect;
    final viewer = _routeState(previous.router, '/viewer/42');
    final passcode = _routeState(previous.router, '/passcode');

    await _restartScope(tester, previous);

    expect(latest.container, isNot(same(previous.container)));
    expect(latest.router, isNot(same(previous.router)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Page Not Found'), findsNothing);
    expect(tester.takeException(), isNull);

    // Model a callback already captured by the old navigation parser. This
    // checks its teardown contract, not the device's exact callback ordering.
    expect(
      await staleRedirect(latest.context, viewer),
      '/passcode?from=%2Fviewer%2F42',
    );
    expect(await staleRedirect(latest.context, passcode), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fresh scope never reuses the old unlocked redirect state', (
    tester,
  ) async {
    late _RouterSnapshot latest;
    await _pumpHost(tester, (value) => latest = value, mountRouter: false);
    final previous = latest;
    final guard =
        previous.container.read(securityGuardProvider.notifier)
            as _ControlledSecurityGuard;
    guard.unlock();
    await tester.pump();
    final staleRedirect = previous.router.configuration.topRedirect;
    final viewer = _routeState(previous.router, '/viewer/42');
    final passcode = _routeState(previous.router, '/passcode');
    expect(await staleRedirect(previous.context, viewer), isNull);

    await _restartScope(tester, previous);

    expect(latest.container, isNot(same(previous.container)));
    expect(latest.router, isNot(same(previous.router)));
    expect(
      await staleRedirect(latest.context, viewer),
      '/passcode?from=%2Fviewer%2F42',
    );
    expect(await staleRedirect(latest.context, passcode), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'fresh scope disposes old delegate and keeps new delegate usable',
    (tester) async {
      late _RouterSnapshot latest;
      await _pumpHost(tester, (value) => latest = value);
      final previous = latest;

      await _restartScope(tester, previous);

      void listener() {}
      expect(
        () => previous.router.routerDelegate.addListener(listener),
        throwsFlutterError,
      );
      expect(
        () => latest.router.routerDelegate.addListener(listener),
        returnsNormally,
      );
      latest.router.routerDelegate.removeListener(listener);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('active guard changes preserve router and existing lock policy', (
    tester,
  ) async {
    late _RouterSnapshot latest;
    await _pumpHost(tester, (value) => latest = value, mountRouter: false);
    final original = latest.router;
    final guard =
        latest.container.read(securityGuardProvider.notifier)
            as _ControlledSecurityGuard;
    const setup = PasscodeRouteArgs(mode: PasscodeMode.setup);

    Future<void> expectRedirect(
      String location,
      String? expected, {
      Object? extra,
    }) async {
      expect(latest.container.read(routerProvider), same(original));
      final result = await original.configuration.topRedirect(
        latest.context,
        _routeState(original, location, extra: extra),
      );
      expect(result, expected, reason: location);
    }

    await expectRedirect('/', null);
    await expectRedirect('/viewer/42', '/passcode?from=%2Fviewer%2F42');
    await expectRedirect('/passcode', null);
    await expectRedirect('/passcode', '/passcode', extra: setup);

    guard.lock();
    await tester.pump();
    await expectRedirect('/', '/passcode');
    await expectRedirect('/viewer/42', '/passcode?from=%2Fviewer%2F42');
    await expectRedirect('/passcode', null);
    await expectRedirect('/passcode', '/passcode', extra: setup);

    guard.unlock();
    await tester.pump();
    await expectRedirect('/viewer/42', null);
    await expectRedirect('/passcode', '/');
    await expectRedirect('/passcode?from=%2Fviewer%2F42', '/viewer/42');
    await expectRedirect('/passcode', null, extra: setup);

    guard.show(const AsyncLoading<bool>());
    await tester.pump();
    await expectRedirect('/', null);
    await expectRedirect('/viewer/42', '/passcode?from=%2Fviewer%2F42');
    await expectRedirect('/passcode', null);
    await expectRedirect('/passcode', '/passcode', extra: setup);

    guard.show(
      AsyncError<bool>(StateError('synthetic guard failure'), StackTrace.empty),
    );
    await tester.pump();
    await expectRedirect('/', null);
    await expectRedirect('/viewer/42', '/');
    await expectRedirect('/passcode', '/');
    expect(tester.takeException(), isNull);
  });
}
