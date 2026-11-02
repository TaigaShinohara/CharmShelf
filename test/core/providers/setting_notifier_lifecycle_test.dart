import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/providers/shared_preferences_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Preferences extends Mock implements SharedPreferences {}

void main() {
  late _Preferences preferences;
  late Completer<void> writeStarted;
  late Completer<bool> nativeWrite;

  setUp(() {
    preferences = _Preferences();
    writeStarted = Completer<void>();
    nativeWrite = Completer<bool>();
    when(
      () => preferences.getInt('app_mode'),
    ).thenReturn(AppMode.external.index);
    when(
      () => preferences.setInt('app_mode', AppMode.internal.index),
    ).thenAnswer((_) {
      writeStarted.complete();
      return nativeWrite.future;
    });
  });

  ProviderContainer createContainer() => ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      sharedPreferencesProvider.overrideWith((ref) async => preferences),
    ],
  );

  test('unobserved app mode save completes before automatic disposal', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    // Onboarding reads the real notifier and calls setMode without a listener.
    final operation = container
        .read(appModeAsyncProvider.notifier)
        .setMode(AppMode.internal);
    final completed = expectLater(operation, completion(isTrue));
    await writeStarted.future.timeout(const Duration(seconds: 3));
    await container.pump();
    final aliveDuringWrite = container.exists(appModeAsyncProvider);

    nativeWrite.complete(true);
    await completed;
    expect(aliveDuringWrite, isTrue);
    verify(
      () => preferences.setInt('app_mode', AppMode.internal.index),
    ).called(1);
    await container.pump();
    expect(container.exists(appModeAsyncProvider), isFalse);
  });

  test(
    'unobserved failed save returns false and releases its lifetime',
    () async {
      final container = createContainer();
      addTearDown(container.dispose);
      final subscription = container.listen(appModeAsyncProvider, (_, _) {});
      await container.read(appModeAsyncProvider.future);
      subscription.close();

      final operation = container
          .read(appModeAsyncProvider.notifier)
          .setMode(AppMode.internal);
      final completed = expectLater(operation, completion(isFalse));
      await writeStarted.future.timeout(const Duration(seconds: 3));
      await container.pump();
      final aliveDuringWrite = container.exists(appModeAsyncProvider);

      nativeWrite.completeError(
        StateError('synthetic preference write failed'),
      );
      await completed;
      expect(aliveDuringWrite, isTrue);
      await container.pump();
      expect(container.exists(appModeAsyncProvider), isFalse);
    },
  );

  test('failed observed save retains the previous app mode', () async {
    final container = createContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(appModeAsyncProvider, (_, _) {});
    addTearDown(subscription.close);
    expect(await container.read(appModeAsyncProvider.future), AppMode.external);

    final operation = container
        .read(appModeAsyncProvider.notifier)
        .setMode(AppMode.internal);
    final completed = expectLater(operation, completion(isFalse));
    await writeStarted.future.timeout(const Duration(seconds: 3));
    nativeWrite.completeError(StateError('synthetic preference write failed'));
    await completed;

    expect(container.read(appModeAsyncProvider).value, AppMode.external);
  });

  for (final writeFails in [false, true]) {
    test(
      'explicit disposal during ${writeFails ? 'failed' : 'successful'} save '
      'does not update disposed state',
      () async {
        final container = createContainer();
        var disposed = false;
        addTearDown(() {
          if (!disposed) container.dispose();
        });
        container.listen(appModeAsyncProvider, (_, _) {});
        await container.read(appModeAsyncProvider.future);

        final operation = container
            .read(appModeAsyncProvider.notifier)
            .setMode(AppMode.internal);
        final completed = expectLater(operation, completion(!writeFails));
        await writeStarted.future.timeout(const Duration(seconds: 3));
        container.dispose();
        disposed = true;

        if (writeFails) {
          nativeWrite.completeError(
            StateError('synthetic preference write failed'),
          );
        } else {
          nativeWrite.complete(true);
        }
        await completed;
        verify(
          () => preferences.setInt('app_mode', AppMode.internal.index),
        ).called(1);
      },
    );
  }
}
