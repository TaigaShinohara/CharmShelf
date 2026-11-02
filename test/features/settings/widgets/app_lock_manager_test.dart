import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/app/app.dart';
import 'package:private_shelf/features/settings/data/repositories/privacy_repository.dart';
import 'package:private_shelf/features/settings/domain/models/privacy_settings.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';
import 'package:private_shelf/features/settings/presentation/widgets/app_lock_manager.dart';
import 'package:secure_application/secure_application.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureChannel = MethodChannel('secure_application');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, null);
  });

  testWidgets('画面保護OFFでもタイムアウト超過時はアプリロックする', (tester) async {
    const settings = PrivacySettings(
      isAppLockEnabled: true,
      hideContentInMultitasking: false,
      autoLockTimeout: AutoLockTimeout.immediately,
    );
    SharedPreferences.setMockInitialValues({
      'privacy_settings': jsonEncode(settings.toJson()),
    });
    final preferences = await SharedPreferences.getInstance();
    SecureApplicationController? controller;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privacyRepositoryProvider.overrideWithValue(
            PrivacyRepository(preferences),
          ),
        ],
        child: MaterialApp(
          home: SecureApplication(
            autoUnlockNative: false,
            child: PrivacySecurityWrapper(
              child: AppLockManager(
                child: Builder(
                  builder: (context) {
                    controller = SecureApplicationProvider.of(context);
                    return const SizedBox();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller?.value.secured, isFalse);
    expect(controller?.value.locked, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(controller?.value.locked, isTrue);
  });

  Future<SecureApplicationController> mountLock(
    WidgetTester tester, {
    required bool protected,
    AutoLockTimeout timeout = AutoLockTimeout.oneMinute,
  }) async {
    final settings = PrivacySettings(
      isAppLockEnabled: true,
      hideContentInMultitasking: protected,
      autoLockTimeout: timeout,
    );
    SharedPreferences.setMockInitialValues({
      'privacy_settings': jsonEncode(settings.toJson()),
    });
    final preferences = await SharedPreferences.getInstance();
    late SecureApplicationController controller;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privacyRepositoryProvider.overrideWithValue(
            PrivacyRepository(preferences),
          ),
        ],
        child: MaterialApp(
          home: SecureApplication(
            autoUnlockNative: false,
            child: PrivacySecurityWrapper(
              child: AppLockManager(
                child: Builder(
                  builder: (context) {
                    controller = SecureApplicationProvider.of(context)!;
                    return const SizedBox();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  Future<void> roundTrip(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  }

  for (final protected in [false, true]) {
    for (final timeout in [AutoLockTimeout.oneMinute, AutoLockTimeout.never]) {
      testWidgets('既存ロックを短時間復帰で解除しない 保護=$protected 設定=$timeout', (
        tester,
      ) async {
        final controller = await mountLock(
          tester,
          protected: protected,
          timeout: timeout,
        );
        controller.lock();
        await roundTrip(tester);
        expect(controller.value.locked, isTrue);
      });
    }
    testWidgets('解除済みの短時間離席は復帰後も解除済み 保護=$protected', (tester) async {
      final controller = await mountLock(tester, protected: protected);
      controller.unlock();
      await roundTrip(tester);
      expect(controller.value.locked, isFalse);
      // 前の周期の解除状態を使い回さない。
      controller.lock();
      await roundTrip(tester);
      expect(controller.value.locked, isTrue);
    });
    testWidgets('解除済みでも即時設定なら復帰でロック 保護=$protected', (tester) async {
      final controller = await mountLock(
        tester,
        protected: protected,
        timeout: AutoLockTimeout.immediately,
      );
      controller.unlock();
      await roundTrip(tester);
      expect(controller.value.locked, isTrue);
    });
  }
  testWidgets('生体認証などinactiveだけの往復では認証結果を上書きしない', (tester) async {
    final controller = await mountLock(tester, protected: true);
    controller.lock();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    controller.authSuccess(unlock: true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(controller.value.locked, isFalse);
    controller.lock();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(controller.value.locked, isTrue);
  });
}
