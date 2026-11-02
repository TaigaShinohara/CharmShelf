import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/services/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('migration failure remains an error and a subsequent read can retry', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (calls.length == 1) {
            throw PlatformException(code: 'LEGACY_MIGRATION_FAILED');
          }
          return 'synthetic-existing-pin-hash';
        });
    final service = SecureStorageService();
    final first = await service.read(key: SecureStorageKeys.pinCode);
    expect(first.isFailure, isTrue);
    final retry = await service.read(key: SecureStorageKeys.pinCode);
    expect(retry.isSuccess, isTrue);
    expect(retry.dataOrNull, 'synthetic-existing-pin-hash');
    expect(calls.map((call) => call.method), ['read', 'read']);
    for (final call in calls) {
      final arguments = call.arguments as Map<Object?, Object?>;
      final options = arguments['options'] as Map<Object?, Object?>;
      expect(options['resetOnError'], 'false');
      expect(options['migrateWithBackup'], 'true');
      expect(options['migrateOnAlgorithmChange'], 'true');
      expect(options['storageNamespace'], '');
      expect(arguments['key'], SecureStorageKeys.pinCode);
    }
  });
}
