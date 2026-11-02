import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/security/domain/repositories/security_repository.dart';
import 'package:private_shelf/features/security/presentation/providers/security_repository_provider.dart';
import 'package:private_shelf/features/security/presentation/utils/security_action_guard.dart';
import 'package:private_shelf/features/settings/domain/models/privacy_settings.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';

class MockSecurityRepository extends Mock implements SecurityRepository {}

void main() {
  late MockSecurityRepository mockSecurityRepo;

  setUp(() {
    mockSecurityRepo = MockSecurityRepository();
  });

  testWidgets('アプリロックが無効の場合は認証不要で true を返す', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privacySettingsNotifierProvider.overrideWith(
            () => _FakePrivacySettingsNotifier(
              const PrivacySettings(isAppLockEnabled: false),
            ),
          ),
          securityRepositoryProvider.overrideWithValue(mockSecurityRepo),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              return ElevatedButton(
                onPressed: () async {
                  final ok = await SecurityActionGuard.requireAuth(
                    context,
                    ref,
                  );
                  expect(ok, isTrue);
                },
                child: const Text('Test'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Test'));
    await tester.pumpAndSettle();
    verifyNever(() => mockSecurityRepo.hasPasscode());
  });

  testWidgets('アプリロック有効だがパスコード未設定の場合は true を返す', (tester) async {
    when(
      () => mockSecurityRepo.hasPasscode(),
    ).thenAnswer((_) async => Result.success(false));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privacySettingsNotifierProvider.overrideWith(
            () => _FakePrivacySettingsNotifier(
              const PrivacySettings(isAppLockEnabled: true),
            ),
          ),
          securityRepositoryProvider.overrideWithValue(mockSecurityRepo),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              return ElevatedButton(
                onPressed: () async {
                  final ok = await SecurityActionGuard.requireAuth(
                    context,
                    ref,
                  );
                  expect(ok, isTrue);
                },
                child: const Text('Test'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Test'));
    await tester.pumpAndSettle();
    verify(() => mockSecurityRepo.hasPasscode()).called(1);
  });

  testWidgets('アプリロック有効時にパスコード状態を読めなければ fail-closed で拒否する', (tester) async {
    when(
      () => mockSecurityRepo.hasPasscode(),
    ).thenAnswer((_) async => Result.failure(AppError.auth('read failed')));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privacySettingsNotifierProvider.overrideWith(
            () => _FakePrivacySettingsNotifier(
              const PrivacySettings(isAppLockEnabled: true),
            ),
          ),
          securityRepositoryProvider.overrideWithValue(mockSecurityRepo),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              return ElevatedButton(
                onPressed: () async {
                  final ok = await SecurityActionGuard.requireAuth(
                    context,
                    ref,
                  );
                  expect(ok, isFalse);
                },
                child: const Text('Test'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Test'));
    await tester.pumpAndSettle();
    verify(() => mockSecurityRepo.hasPasscode()).called(1);
  });
}

class _FakePrivacySettingsNotifier extends PrivacySettingsNotifier {
  final PrivacySettings _settings;
  _FakePrivacySettingsNotifier(this._settings);

  @override
  Future<PrivacySettings> build() async => _settings;
}
