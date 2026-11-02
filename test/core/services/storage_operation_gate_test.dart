import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/services/storage_operation_gate.dart';

void main() {
  tearDown(() => StorageOperationGate.recoveryRequired = false);
  test(
    'an in-flight import prevents maintenance before its first write',
    () async {
      final done = Completer<void>();
      final running = StorageOperationGate.run(() => done.future);
      var changed = false;
      await expectLater(
        StorageOperationGate.maintenance(() async {
          changed = true;
        }),
        throwsA(isA<StorageOperationBusy>()),
      );
      expect(changed, isFalse);
      done.complete();
      await running;
      await StorageOperationGate.maintenance(() async {
        changed = true;
      });
      expect(changed, isTrue);
    },
  );

  test(
    'maintenance blocks outside operations but permits its own nested sync',
    () async {
      final finish = Completer<void>();
      final started = Completer<void>();
      final running = StorageOperationGate.maintenance(() async {
        await StorageOperationGate.run(() async {});
        started.complete();
        await finish.future;
      });
      await started.future;
      await expectLater(
        StorageOperationGate.run(() async {}),
        throwsA(isA<StorageOperationBusy>()),
      );
      await expectLater(
        StorageOperationGate.maintenance(() async {}),
        throwsA(isA<StorageOperationBusy>()),
      );
      finish.complete();
      await running;
      expect(StorageOperationGate.isBusy, isFalse);
    },
  );

  test(
    'pending recovery blocks normal work until recovery completes',
    () async {
      StorageOperationGate.recoveryRequired = true;
      await expectLater(
        StorageOperationGate.run(() async {}),
        throwsA(isA<StorageOperationBusy>()),
      );
      await StorageOperationGate.maintenance(() async {
        await StorageOperationGate.run(() async {});
        StorageOperationGate.recoveryRequired = false;
      });
      await StorageOperationGate.run(() async {});
    },
  );
}
