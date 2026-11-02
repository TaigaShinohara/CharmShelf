import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/onboarding/data/fresh_start_recovery_store.dart';

void main() {
  late Directory support;
  late FreshStartRecoveryStore store;
  late File marker;

  setUp(() async {
    final fixtures = Directory('build/test-fixtures/fresh-start-markers');
    await fixtures.create(recursive: true);
    support = await fixtures.createTemp('support-');
    store = FreshStartRecoveryStore(supportDirectory: () async => support);
    marker = File('${support.path}/${FreshStartRecoveryStore.markerFileName}');
  });

  tearDown(() async {
    if (await support.exists()) await support.delete(recursive: true);
  });

  test('保存済みmarkerからchoiceと各phaseを読み戻せる', () async {
    expect(await store.readState(), isNull);
    await store.markPending('fresh');
    expect((await store.readState())!.entryChoice, 'fresh');
    expect((await store.readState())!.phase, FreshStartPhase.clearingStorage);
    for (final phase in FreshStartPhase.values) {
      await store.writePhase('fresh', phase);
      expect((await store.readState())!.phase, phase);
    }
    expect(await File('${marker.path}.tmp').exists(), isFalse);
    await store.markComplete();
    expect(await store.readState(), isNull);
  });

  test('tempだけでは確定済みと判定しない', () async {
    await File('${marker.path}.tmp').writeAsString(
      '{"version":1,"entryChoice":"fresh","phase":"clearingStorage"}',
      flush: true,
    );
    expect(await store.readState(), isNull);
    await store.markPending('first');
    expect((await store.readState())!.entryChoice, 'first');
    expect(await File('${marker.path}.tmp').exists(), isFalse);
  });

  test('既存pendingを巻き戻さず異なるchoiceでは開始しない', () async {
    await store.markPending('first');
    await store.writePhase('first', FreshStartPhase.finishing);
    await store.markPending('first');
    expect((await store.readState())!.phase, FreshStartPhase.finishing);
    await expectLater(store.markPending('fresh'), throwsStateError);
    expect((await store.readState())!.entryChoice, 'first');
  });

  test('未対応version・phase・choice・破損markerでは消去を開始しない', () async {
    for (final content in [
      '{"version":2,"entryChoice":"fresh","phase":"clearingStorage"}',
      '{"version":1,"entryChoice":"fresh","phase":"other"}',
      '{"version":1,"entryChoice":"other","phase":"clearingStorage"}',
      'invalid',
    ]) {
      await marker.writeAsString(content, flush: true);
      await expectLater(store.readState(), throwsFormatException);
      await expectLater(store.markPending('fresh'), throwsFormatException);
      expect(await marker.readAsString(), content);
    }
  });

  test('未承認のchoiceはmarkerを作成しない', () async {
    await expectLater(store.markPending('restore'), throwsArgumentError);
    await expectLater(
      store.writePhase('restore', FreshStartPhase.clearingStorage),
      throwsArgumentError,
    );
    expect(await marker.exists(), isFalse);
  });
}
