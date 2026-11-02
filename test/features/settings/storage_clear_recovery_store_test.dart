import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/settings/data/services/storage_clear_recovery_store.dart';

void main() {
  late Directory supportDirectory;
  late StorageClearRecoveryStore store;

  setUp(() async {
    supportDirectory = await Directory.systemTemp.createTemp(
      'storage_clear_recovery_store_test_',
    );
    store = StorageClearRecoveryStore(
      supportDirectory: () async => supportDirectory,
    );
  });

  tearDown(() async {
    if (await supportDirectory.exists()) {
      await supportDirectory.delete(recursive: true);
    }
  });

  test('markPendingは再実行可能でmarkCompleteまで状態を保持する', () async {
    expect(await store.isPending(), isFalse);

    await store.markPending();
    await store.markPending();

    expect(await store.isPending(), isTrue);
    expect(await store.readStage(), StorageClearRecoveryStage.clearingInternal);

    await store.markExternalReleasePending();

    expect(
      await store.readStage(),
      StorageClearRecoveryStage.releasingExternal,
    );

    await store.markComplete();
    await store.markComplete();

    expect(await store.isPending(), isFalse);
  });

  test('旧形式のマーカーは内部消去段階として安全側に復旧する', () async {
    final marker = File('${supportDirectory.path}/.storage_clear_pending_v1');
    await marker.writeAsString('{"version":1}', flush: true);

    expect(await store.readStage(), StorageClearRecoveryStage.clearingInternal);
  });

  test('一時ファイルだけでは消去開始済みと判定しない', () async {
    final temporary = File(
      '${supportDirectory.path}/.storage_clear_pending_v1.tmp',
    );
    await temporary.writeAsString('{"version":1}', flush: true);

    expect(await store.isPending(), isFalse);

    await store.markPending();

    expect(await store.isPending(), isTrue);
    expect(await temporary.exists(), isFalse);
  });
}
