import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/security/presentation/providers/passcode_provider.dart';
import 'package:private_shelf/features/settings/domain/models/privacy_settings.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';
import 'package:private_shelf/features/settings/presentation/screens/lock_screen.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:secure_application/secure_application.dart';

class _Privacy extends PrivacySettingsNotifier {
  @override
  Future<PrivacySettings> build() async =>
      const PrivacySettings(isAppLockEnabled: true);
}

class _Passcode extends PasscodeNotifier {
  @override
  PasscodeState build(PasscodeMode mode) =>
      PasscodeState(mode: mode, isSecurityStateReady: true);
}

void main() {
  testWidgets('ロック中は背後のファイル名と操作をSemanticsから除外し解除後に戻す', (tester) async {
    const channel = MethodChannel('secure_application');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final semantics = tester.ensureSemantics();
    try {
      SecureApplicationController? controller;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            privacySettingsNotifierProvider.overrideWith(_Privacy.new),
            passcodeNotifierProvider(
              PasscodeMode.unlock,
            ).overrideWith(_Passcode.new),
          ],
          child: MaterialApp(
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SecureApplication(
              child: Builder(
                builder: (context) {
                  controller = SecureApplicationProvider.of(context);
                  return SecureGate(
                    lockedBuilder: (_, _) => const LockScreen(),
                    child: Scaffold(
                      body: TextButton(
                        onPressed: () {},
                        child: const Text('QA secret file'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.semantics.byLabel('QA secret file'), findsOneWidget);
      controller!.lock();
      await tester.pumpAndSettle();
      expect(find.semantics.byLabel('QA secret file'), findsNothing);
      expect(
        find.semantics.byPredicate(
          (node) => node.label
              .replaceAll(RegExp('[\u200B\u2060]'), '')
              .contains('パスコードを入力して解除'),
        ),
        findsOneWidget,
      );
      expect(find.semantics.byLabel('1'), findsAtLeastNWidgets(1));
      controller!.unlock();
      await tester.pumpAndSettle();
      expect(find.semantics.byLabel('QA secret file'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}
